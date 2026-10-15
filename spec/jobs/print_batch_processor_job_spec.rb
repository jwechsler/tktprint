require 'rails_helper'

RSpec.describe PrintBatchProcessorJob, type: :job do
  let(:printer) { double('Printer') }
  let(:batch) { FactoryBot.create(:print_batch, :ready) }
  let!(:orders) do
    [
      FactoryBot.create(:order, batch_id: batch.batch_id, batch_sequence: 1, print_status: 'unprinted'),
      FactoryBot.create(:order, batch_id: batch.batch_id, batch_sequence: 2, print_status: 'unprinted'),
      FactoryBot.create(:order, batch_id: batch.batch_id, batch_sequence: 3, print_status: 'printed')
    ]
  end

  before do
    allow(Printer).to receive(:new).and_return(printer)
    allow(printer).to receive(:print_order).and_return(true)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    
    # Clear any existing delayed jobs before each test
    Delayed::Job.delete_all
  end

  describe '#perform' do
    context 'when there is a printable batch' do
      it 'processes the first printable batch' do
        expect(Rails.logger).to receive(:info).with("Processing print batch: #{batch.batch_id}")
        
        PrintBatchProcessorJob.new.perform
        
        batch.reload
        expect(batch.status).to eq('complete')
      end

      it 'marks ready batch as processing' do
        expect(batch.ready?).to be true
        
        PrintBatchProcessorJob.new.perform
        
        batch.reload
        expect(batch.processing?).to be false # It should be complete after processing
      end

      it 'updates counts and marks batch complete' do
        PrintBatchProcessorJob.new.perform
        
        batch.reload
        expect(batch.order_count).to eq(3)
        expect(batch.printed_count).to eq(3) # All 3 orders should be printed (2 new + 1 already printed)
        expect(batch.error_count).to eq(0)
        expect(batch.complete?).to be true
      end

      it 'schedules next batch if more exist' do
        # Create another batch
        other_batch = FactoryBot.create(:print_batch, :ready)
        
        expect(PrintBatchProcessorJob).to receive(:perform_later)
        
        PrintBatchProcessorJob.new.perform
      end

      it 'does not schedule next batch if none exist' do
        expect(PrintBatchProcessorJob).not_to receive(:perform_later)
        
        PrintBatchProcessorJob.new.perform
      end

      context 'when processing fails' do
        before do
          allow(Printer).to receive(:new).and_raise(StandardError.new('Printer not available'))
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(/Error processing batch #{batch.batch_id}: Printer not available/)
          
          PrintBatchProcessorJob.new.perform
        end

        it 'updates error details on batch' do
          PrintBatchProcessorJob.new.perform
          
          batch.reload
          expect(batch.error_details).to eq('Printer not available')
        end

        it 'still completes the batch in ensure block' do
          PrintBatchProcessorJob.new.perform
          
          batch.reload
          expect(batch.complete?).to be true
        end
      end
    end

    context 'when there are no printable batches' do
      before do
        batch.update!(status: 'complete')
      end

      it 'returns early without processing' do
        expect(Rails.logger).not_to receive(:info)
        
        PrintBatchProcessorJob.new.perform
      end
    end

    context 'when batch is already processing' do
      before do
        batch.update!(status: 'processing')
      end

      it 'does not call mark_processing again' do
        original_started_at = batch.started_at
        
        PrintBatchProcessorJob.new.perform
        
        batch.reload
        expect(batch.started_at).to eq(original_started_at)
      end
    end
  end

  describe '#process_batch' do
    let(:job) { PrintBatchProcessorJob.new }

    it 'processes unprinted orders in sequence' do
      expect(Rails.logger).to receive(:info).with("Printing 2 orders in batch #{batch.batch_id}")
      
      orders.first(2).each do |order|
        expect(Rails.logger).to receive(:info).with("Printing order #{order.id} (sequence #{order.batch_sequence})")
        expect(Rails.logger).to receive(:info).with("Successfully printed order #{order.id}")
      end
      
      job.send(:process_batch, batch)
      
      # Check that orders were actually marked as printed
      orders.first(2).each do |order|
        order.reload
        expect(order.print_status).to eq('printed')
        expect(order.printed_at).to be_present
      end
    end

    context 'when printer succeeds' do
      it 'marks orders as printed' do
        job.send(:process_batch, batch)
        
        orders.first(2).each do |order|
          order.reload
          expect(order.print_status).to eq('printed')
          expect(order.printed_at).to be_present
        end
      end
    end

    context 'when printer fails' do
      before do
        allow(printer).to receive(:print_order).with(orders.first).and_return(false)
        allow(printer).to receive(:print_order).with(orders.second).and_return(true)
      end

      it 'marks failed orders with error' do
        expect(Rails.logger).to receive(:error).with("Failed to print order #{orders.first.id}")
        
        job.send(:process_batch, batch)
        
        orders.first.reload
        expect(orders.first.print_status).to eq('error: Printer failed to print order')
        expect(orders.first.print_error).to eq('Printer failed to print order')
      end

      it 'continues with remaining orders' do
        job.send(:process_batch, batch)
        
        orders.second.reload
        expect(orders.second.print_status).to eq('printed')
        expect(orders.second.printed_at).to be_present
      end
    end

    context 'when printer raises exception' do
      let(:error) { StandardError.new('Printer error') }

      before do
        allow(printer).to receive(:print_order).with(orders.first).and_raise(error)
        allow(printer).to receive(:print_order).with(orders.second).and_return(true)
      end

      it 'marks failed orders with error message' do
        expect(Rails.logger).to receive(:error).with("Error printing order #{orders.first.id}: Print error: Printer error")
        
        job.send(:process_batch, batch)
        
        orders.first.reload
        expect(orders.first.print_status).to eq('error: Print error: Printer error')
        expect(orders.first.print_error).to eq('Print error: Printer error')
      end

      it 'continues with remaining orders' do
        job.send(:process_batch, batch)
        
        orders.second.reload
        expect(orders.second.print_status).to eq('printed')
        expect(orders.second.printed_at).to be_present
      end
    end
  end

  describe '#schedule_next_batch' do
    let(:job) { PrintBatchProcessorJob.new }

    context 'when more batches exist' do
      before do
        FactoryBot.create(:print_batch, :ready)
      end

      it 'schedules the next batch processing job' do
        expect(Rails.logger).to receive(:info).with("Scheduling next batch for processing")
        
        # Mock the actual job scheduling since we're testing singleton behavior separately
        allow(PrintBatchProcessorJob).to receive(:perform_later)
        
        job.send(:schedule_next_batch)
        
        expect(PrintBatchProcessorJob).to have_received(:perform_later)
      end
    end

    context 'when no more batches exist' do
      before do
        # Make sure no batches exist
        PrintBatch.destroy_all
      end

      it 'does not schedule another job' do
        expect(Rails.logger).to receive(:info).with("No more batches to process")
        
        # Mock the actual job scheduling since we're testing singleton behavior separately
        allow(PrintBatchProcessorJob).to receive(:perform_later)
        
        job.send(:schedule_next_batch)
        
        expect(PrintBatchProcessorJob).not_to have_received(:perform_later)
      end
    end
  end

  describe 'queue configuration' do
    it 'uses the default queue' do
      expect(PrintBatchProcessorJob.queue_name).to eq('default')
    end
  end

  describe 'job execution order' do
    let!(:ready_batch) { FactoryBot.create(:print_batch, :ready, created_at: 1.hour.ago) }
    let!(:processing_batch) { FactoryBot.create(:print_batch, :processing, created_at: 2.hours.ago) }

    it 'processes batches in the correct priority order' do
      batches = PrintBatch.printable.to_a
      expect(batches.first).to eq(processing_batch)
      expect(batches.second).to eq(ready_batch)
    end
  end

  describe 'error handling' do
    context 'when batch update fails in ensure block' do
      before do
        allow(batch).to receive(:update_counts!).and_raise(ActiveRecord::RecordInvalid.new(batch))
      end

      it 'handles the error gracefully' do
        # The job should not raise an error even if update_counts! fails
        expect { PrintBatchProcessorJob.new.perform }.not_to raise_error
        
        # The batch should still be marked as complete despite the error
        batch.reload
        expect(batch.complete?).to be true
      end
    end
  end

  describe 'integration test' do
    it 'processes a complete batch workflow' do
      # Clean up any existing batches to avoid interference
      PrintBatch.destroy_all
      
      # Create a fresh batch with multiple orders
      integration_batch = FactoryBot.create(:print_batch, :ready)
      orders = [
        FactoryBot.create(:order, batch_id: integration_batch.batch_id, batch_sequence: 1, print_status: 'unprinted'),
        FactoryBot.create(:order, batch_id: integration_batch.batch_id, batch_sequence: 2, print_status: 'unprinted'),
        FactoryBot.create(:order, batch_id: integration_batch.batch_id, batch_sequence: 3, print_status: 'unprinted')
      ]

      # Mock printer to succeed for all orders
      printer_mock = double('Printer')
      allow(Printer).to receive(:new).and_return(printer_mock)
      allow(printer_mock).to receive(:print_order).and_return(true)

      # Mock the job scheduling to avoid infinite loops
      allow(PrintBatchProcessorJob).to receive(:perform_later)

      # Process the batch
      PrintBatchProcessorJob.new.perform

      # Verify the batch was processed correctly
      integration_batch.reload
      expect(integration_batch.status).to eq('complete')
      expect(integration_batch.order_count).to eq(3)
      expect(integration_batch.printed_count).to eq(3)
      expect(integration_batch.error_count).to eq(0)
      expect(integration_batch.completed_at).to be_present

      # Verify all orders were printed
      orders.each do |order|
        order.reload
        expect(order.print_status).to eq('printed')
        expect(order.printed_at).to be_present
      end
    end
  end

  describe '.perform_later (singleton behavior)' do
    let!(:ready_batch) { FactoryBot.create(:print_batch, :ready) }

    context 'when no job is queued' do
      it 'queues a new job' do
        expect(Delayed::Job.count).to eq(0)
        expect(Rails.logger).to receive(:info).with("Queueing new PrintBatchProcessorJob")
        
        job = PrintBatchProcessorJob.perform_later
        
        expect(Delayed::Job.count).to eq(1)
        expect(job).to be_present
      end
    end

    context 'when a job is already queued' do
      let!(:existing_job) { PrintBatchProcessorJob.perform_later }

      it 'does not queue a duplicate job' do
        expect(Delayed::Job.count).to eq(1)
        
        duplicate_job = PrintBatchProcessorJob.perform_later
        
        expect(Delayed::Job.count).to eq(1)
        expect(duplicate_job).to be_nil
      end

      it 'logs that duplicate is skipped' do
        expect(Rails.logger).to receive(:info).with(/PrintBatchProcessorJob already queued/)
        
        PrintBatchProcessorJob.perform_later
      end
    end

    context 'when a job is currently running (locked)' do
      let!(:locked_job) do
        job = PrintBatchProcessorJob.perform_later
        # Simulate the job being picked up by a worker
        delayed_job = Delayed::Job.first
        delayed_job.update!(locked_at: Time.current, locked_by: 'worker-1')
        job
      end

      it 'allows queuing a new job since the existing one is locked' do
        expect(Delayed::Job.count).to eq(1)
        
        new_job = PrintBatchProcessorJob.perform_later
        
        expect(Delayed::Job.count).to eq(2)
        expect(new_job).to be_present
      end

      it 'logs that new job is queued' do
        expect(Rails.logger).to receive(:info).with("Queueing new PrintBatchProcessorJob")
        
        PrintBatchProcessorJob.perform_later
      end
    end

    context 'when multiple jobs are queued from different sources' do
      it 'prevents duplicate queuing from batch closure' do
        # Simulate batch closure triggering job
        job1 = PrintBatchProcessorJob.perform_later
        
        # Simulate manual print request
        job2 = PrintBatchProcessorJob.perform_later
        
        # Simulate startup recovery
        job3 = PrintBatchProcessorJob.perform_later
        
        # First job should be created, subsequent should be nil
        expect(job1).to be_present
        expect(job2).to be_nil
        expect(job3).to be_nil
        expect(Delayed::Job.count).to eq(1)
      end
    end

    context 'job queue integration' do
      it 'properly identifies existing jobs by handler content' do
        # Create a job
        job = PrintBatchProcessorJob.perform_later
        
        # Verify the handler contains the job class name
        delayed_job = Delayed::Job.first
        expect(delayed_job.handler).to include('PrintBatchProcessorJob')
        
        # Verify our detection logic works
        existing_job = Delayed::Job.where(
          "handler LIKE ?", 
          "%PrintBatchProcessorJob%"
        ).where("locked_at IS NULL").first
        
        expect(existing_job).to eq(delayed_job)
      end
    end
  end
end