require 'rails_helper'

RSpec.describe 'Batch Startup Recovery' do
  let(:initializer_path) { Rails.root.join('config', 'initializers', 'batch_startup_recovery.rb') }
  
  before do
    # Mock Rails.env.test? to return false so the initializer will run
    allow(Rails.env).to receive(:test?).and_return(false)
    
    # Mock Rails.logger to capture log messages
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    
    # Mock ActiveRecord connection
    allow(ActiveRecord::Base).to receive(:connected?).and_return(true)
    
    # Mock DelayedJob configuration
    allow(Rails.application.config.active_job).to receive(:queue_adapter).and_return(:delayed_job)
    
    # Mock PrintBatchProcessorJob
    allow(PrintBatchProcessorJob).to receive(:perform_later)
  end
  
  describe 'startup recovery logic' do
    context 'when there are printable batches' do
      let!(:ready_batch) { FactoryBot.create(:print_batch, :ready) }
      let!(:processing_batch) { FactoryBot.create(:print_batch, :processing) }
      
      it 'schedules batch processing job' do
        # Simulate running the initializer
        expect(PrintBatchProcessorJob).to receive(:perform_later)
        
        # Load and execute the initializer in a new thread context
        Thread.new do
          load initializer_path
          sleep 0.1 # Allow the thread to execute
        end.join
        
        # Wait for async execution
        sleep 2.1
      end
      
      it 'logs the found batches' do
        expect(Rails.logger).to receive(:info).with("Checking for interrupted print batches on startup...")
        expect(Rails.logger).to receive(:info).with(/Found 2 interrupted batch\(es\) to resume/)
        expect(Rails.logger).to receive(:info).with("Batch processing job scheduled for startup recovery")
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
    
    context 'when there are no printable batches' do
      before do
        # Ensure no batches exist
        PrintBatch.destroy_all
      end
      
      it 'does not schedule batch processing job' do
        expect(PrintBatchProcessorJob).not_to receive(:perform_later)
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
      
      it 'logs no batches found' do
        expect(Rails.logger).to receive(:info).with("Checking for interrupted print batches on startup...")
        expect(Rails.logger).to receive(:info).with("No interrupted batches found - startup recovery complete")
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
    
    context 'when database is not connected' do
      before do
        allow(ActiveRecord::Base).to receive(:connected?).and_return(false)
      end
      
      it 'skips batch recovery' do
        expect(PrintBatchProcessorJob).not_to receive(:perform_later)
        expect(Rails.logger).to receive(:warn).with("Database not connected during startup recovery - skipping batch recovery")
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
    
    context 'when DelayedJob is not configured' do
      let!(:ready_batch) { FactoryBot.create(:print_batch, :ready) }
      
      before do
        allow(Rails.application.config.active_job).to receive(:queue_adapter).and_return(:inline)
      end
      
      it 'skips batch recovery' do
        expect(PrintBatchProcessorJob).not_to receive(:perform_later)
        expect(Rails.logger).to receive(:warn).with("Active Job not configured for delayed_job - cannot schedule batch recovery")
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
    
    context 'when ActiveRecord connection error occurs' do
      before do
        allow(PrintBatch).to receive(:printable).and_raise(ActiveRecord::ConnectionNotEstablished.new("Database connection failed"))
      end
      
      it 'handles the error gracefully' do
        expect(Rails.logger).to receive(:error).with("Database connection not available during startup recovery: Database connection failed")
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
    
    context 'when PrintBatch model is not available' do
      before do
        allow(PrintBatch).to receive(:printable).and_raise(NameError.new("uninitialized constant PrintBatch"))
      end
      
      it 'handles the error gracefully' do
        expect(Rails.logger).to receive(:error).with("PrintBatch model not available during startup recovery: uninitialized constant PrintBatch")
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
    
    context 'when unexpected error occurs' do
      before do
        allow(PrintBatch).to receive(:printable).and_raise(StandardError.new("Unexpected error"))
      end
      
      it 'handles the error gracefully' do
        expect(Rails.logger).to receive(:error).with("Error during batch startup recovery: Unexpected error")
        expect(Rails.logger).to receive(:error).with(anything) # backtrace
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
    
    context 'in test environment' do
      before do
        allow(Rails.env).to receive(:test?).and_return(true)
      end
      
      it 'does not run startup recovery' do
        expect(PrintBatchProcessorJob).not_to receive(:perform_later)
        expect(Rails.logger).not_to receive(:info)
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
  end
  
  describe 'integration with actual application startup' do
    it 'can be loaded without errors' do
      expect { load initializer_path }.not_to raise_error
    end
  end
  
  describe 'recovery scenarios' do
    context 'service restart with ready batch' do
      let!(:batch) { FactoryBot.create(:print_batch, :ready) }
      
      it 'resumes processing after restart' do
        # Simulate service restart scenario
        expect(PrintBatchProcessorJob).to receive(:perform_later)
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
    
    context 'service restart with processing batch' do
      let!(:batch) { FactoryBot.create(:print_batch, :processing) }
      
      it 'resumes processing after restart' do
        # Simulate service restart scenario
        expect(PrintBatchProcessorJob).to receive(:perform_later)
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
    
    context 'service restart with mixed batch states' do
      let!(:ready_batch) { FactoryBot.create(:print_batch, :ready) }
      let!(:processing_batch) { FactoryBot.create(:print_batch, :processing) }
      let!(:pending_batch) { FactoryBot.create(:print_batch) }
      let!(:complete_batch) { FactoryBot.create(:print_batch, :complete) }
      
      it 'only processes ready and processing batches' do
        expect(PrintBatchProcessorJob).to receive(:perform_later)
        expect(Rails.logger).to receive(:info).with(/Found 2 interrupted batch\(es\) to resume/)
        
        Thread.new do
          load initializer_path
          sleep 0.1
        end.join
        
        sleep 2.1
      end
    end
  end
end