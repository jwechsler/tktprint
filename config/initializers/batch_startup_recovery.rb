# config/initializers/batch_startup_recovery.rb
#
# This initializer ensures that any batches that were interrupted by a service restart
# are automatically resumed when the application starts up. This prevents batches from
# being orphaned in 'ready' or 'processing' status after a restart.

Rails.application.config.after_initialize do
  # Only run in non-test environments
  unless Rails.env.test?
    # Use a delay to ensure database connections are fully established
    Thread.new do
      sleep 5
      
      begin
        Rails.logger.info("Checking for interrupted print batches on startup...")
        
        # Verify database is available without resetting the connection pool
        begin
          ActiveRecord::Base.connection_pool.with_connection do |conn|
            conn.execute("SELECT 1")
          end
        rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
          Rails.logger.warn("Database not available during startup recovery (#{e.message}) - skipping batch recovery")
          next
        end
        
        # Find any batches that need processing (ready or processing status)
        printable_batches = PrintBatch.printable
        
        if printable_batches.any?
          batch_ids = printable_batches.pluck(:batch_id)
          Rails.logger.info("Found #{printable_batches.count} interrupted batch(es) to resume: #{batch_ids.join(', ')}")
          
          # Additional safety check - ensure DelayedJob is configured
          unless Rails.application.config.active_job.queue_adapter == :delayed_job
            Rails.logger.warn("Active Job not configured for delayed_job - cannot schedule batch recovery")
            next
          end
          
          # Schedule batch processing to resume
          PrintBatchProcessorJob.perform_later
          
          Rails.logger.info("Batch processing job scheduled for startup recovery")
        else
          Rails.logger.info("No interrupted batches found - startup recovery complete")
        end
        
      rescue ActiveRecord::ConnectionNotEstablished => e
        Rails.logger.error("Database connection not available during startup recovery: #{e.message}")
      rescue NameError => e
        Rails.logger.error("PrintBatch model not available during startup recovery: #{e.message}")
      rescue => e
        # Log error but don't crash the application
        Rails.logger.error("Error during batch startup recovery: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
  end
end