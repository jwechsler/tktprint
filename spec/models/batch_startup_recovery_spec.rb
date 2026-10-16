require 'rails_helper'

RSpec.describe BatchStartupRecovery do
  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    allow(Rails.application.config.active_job).to receive(:queue_adapter).and_return(:delayed_job)
    allow(PrintBatchProcessorJob).to receive(:perform_later)
  end

  describe '.run' do
    context 'when there are printable batches' do
      let!(:ready_batch) { FactoryBot.create(:print_batch, :ready) }
      let!(:processing_batch) { FactoryBot.create(:print_batch, :processing) }

      it 'schedules batch processing' do
        BatchStartupRecovery.run
        expect(PrintBatchProcessorJob).to have_received(:perform_later).once
      end

      it 'logs the batches it found and the scheduled job' do
        BatchStartupRecovery.run
        expect(Rails.logger).to have_received(:info).with('Checking for interrupted print batches on startup...')
        expect(Rails.logger).to have_received(:info).with(/Found 2 interrupted batch\(es\) to resume/)
        expect(Rails.logger).to have_received(:info).with('Batch processing job scheduled for startup recovery')
      end
    end

    context 'with batches in every state' do
      before do
        FactoryBot.create(:print_batch, :ready)
        FactoryBot.create(:print_batch, :processing)
        FactoryBot.create(:print_batch)
        FactoryBot.create(:print_batch, :complete)
      end

      it 'resumes only ready and processing batches' do
        BatchStartupRecovery.run
        expect(Rails.logger).to have_received(:info).with(/Found 2 interrupted batch\(es\) to resume/)
        expect(PrintBatchProcessorJob).to have_received(:perform_later).once
      end
    end

    context 'when there are no printable batches' do
      it 'schedules nothing and says so' do
        BatchStartupRecovery.run
        expect(PrintBatchProcessorJob).not_to have_received(:perform_later)
        expect(Rails.logger).to have_received(:info).with('No interrupted batches found - startup recovery complete')
      end
    end

    context 'when the database is not available' do
      let!(:ready_batch) { FactoryBot.create(:print_batch, :ready) }

      before do
        allow(ActiveRecord::Base.connection_pool).to receive(:with_connection)
          .and_raise(ActiveRecord::ConnectionNotEstablished.new('no database'))
      end

      it 'skips batch recovery' do
        BatchStartupRecovery.run
        expect(PrintBatchProcessorJob).not_to have_received(:perform_later)
        expect(Rails.logger).to have_received(:warn)
          .with('Database not available during startup recovery (no database) - skipping batch recovery')
      end
    end

    context 'when Active Job is not using delayed_job' do
      let!(:ready_batch) { FactoryBot.create(:print_batch, :ready) }

      before { allow(Rails.application.config.active_job).to receive(:queue_adapter).and_return(:inline) }

      it 'skips batch recovery' do
        BatchStartupRecovery.run
        expect(PrintBatchProcessorJob).not_to have_received(:perform_later)
        expect(Rails.logger).to have_received(:warn)
          .with('Active Job not configured for delayed_job - cannot schedule batch recovery')
      end
    end

    {
      ActiveRecord::ConnectionNotEstablished.new('Database connection failed') =>
        'Database connection not available during startup recovery: Database connection failed',
      NameError.new('uninitialized constant PrintBatch') =>
        'PrintBatch model not available during startup recovery: uninitialized constant PrintBatch',
      StandardError.new('Unexpected error') => 'Error during batch startup recovery: Unexpected error'
    }.each do |error, message|
      it "logs #{error.class} instead of raising" do
        allow(PrintBatch).to receive(:printable).and_raise(error)
        expect { BatchStartupRecovery.run }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(message)
      end
    end
  end

  describe '.start_in_background' do
    it 'runs recovery on a thread after the startup delay' do
      allow(Thread).to receive(:new).and_yield
      allow(BatchStartupRecovery).to receive(:sleep)
      allow(BatchStartupRecovery).to receive(:run)

      BatchStartupRecovery.start_in_background

      expect(BatchStartupRecovery).to have_received(:sleep).with(BatchStartupRecovery::STARTUP_DELAY).ordered
      expect(BatchStartupRecovery).to have_received(:run).ordered
    end
  end

  describe 'the initializer' do
    let(:initializer_path) { Rails.root.join('config/initializers/batch_startup_recovery.rb') }

    before do
      allow(Rails.application.config).to receive(:after_initialize).and_yield
      allow(BatchStartupRecovery).to receive(:start_in_background)
    end

    it 'starts recovery outside the test environment' do
      allow(Rails.env).to receive(:test?).and_return(false)
      load initializer_path
      expect(BatchStartupRecovery).to have_received(:start_in_background)
    end

    it 'does nothing in the test environment' do
      load initializer_path
      expect(BatchStartupRecovery).not_to have_received(:start_in_background)
    end
  end
end
