# Resumes print batches that a service restart left in 'ready' or 'processing' status,
# so they aren't orphaned. Started from config/initializers/batch_startup_recovery.rb.
class BatchStartupRecovery
  # Seconds to wait after boot so database connections are fully established
  STARTUP_DELAY = 5

  def self.start_in_background
    Thread.new do
      sleep STARTUP_DELAY
      run
    end
  end

  def self.run
    Rails.logger.info("Checking for interrupted print batches on startup...")
    return unless database_available?

    printable_batches = PrintBatch.printable
    unless printable_batches.any?
      Rails.logger.info("No interrupted batches found - startup recovery complete")
      return
    end

    batch_ids = printable_batches.pluck(:batch_id)
    Rails.logger.info("Found #{batch_ids.size} interrupted batch(es) to resume: #{batch_ids.join(', ')}")

    unless Rails.application.config.active_job.queue_adapter == :delayed_job
      Rails.logger.warn("Active Job not configured for delayed_job - cannot schedule batch recovery")
      return
    end

    PrintBatchProcessorJob.perform_later
    Rails.logger.info("Batch processing job scheduled for startup recovery")
  rescue ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.error("Database connection not available during startup recovery: #{e.message}")
  rescue NameError => e
    Rails.logger.error("PrintBatch model not available during startup recovery: #{e.message}")
  rescue StandardError => e
    # Log the error but never crash the application
    Rails.logger.error("Error during batch startup recovery: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end

  # Checks the database without resetting the connection pool
  def self.database_available?
    ActiveRecord::Base.connection_pool.with_connection { |conn| conn.execute('SELECT 1') }
    true
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.warn("Database not available during startup recovery (#{e.message}) - skipping batch recovery")
    false
  end
  private_class_method :database_available?
end
