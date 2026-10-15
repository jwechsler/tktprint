class PrintBatchProcessorJob < ApplicationJob
  queue_as :default

  # Ensure only one instance of this job can be queued at a time
  def self.perform_later(*args)
    # Check if there's already a job queued for this class
    existing_job = Delayed::Job.where(
      "handler LIKE ?",
      "%PrintBatchProcessorJob%"
    ).where("locked_at IS NULL").first
    
    if existing_job
      Rails.logger.info("PrintBatchProcessorJob already queued (ID: #{existing_job.id}), skipping duplicate")
      return nil # Return nil to indicate duplicate was skipped
    end
    
    Rails.logger.info("Queueing new PrintBatchProcessorJob")
    super(*args)
  end

  def perform
    # Guard: Ensure printer logo is loaded before processing batches
    unless Printer.logo_loaded?
      Rails.logger.warn("Printer logo not yet loaded - rescheduling batch processing")
      # Reschedule this job to try again in 5 seconds
      PrintBatchProcessorJob.set(wait: 5.seconds).perform_later
      return
    end

    # Find the next batch to process: processing batches first, then ready batches
    batch = PrintBatch.printable.first
    return unless batch

    Rails.logger.info("Processing print batch: #{batch.batch_id}")
    
    # Mark batch as processing if it's ready
    batch.mark_processing! if batch.ready?

    begin
      process_batch(batch)
    rescue => e
      Rails.logger.error("Error processing batch #{batch.batch_id}: #{e.message}")
      batch.update!(error_details: e.message)
    ensure
      # Update counts and complete the batch
      batch.update_counts!
      batch.mark_complete!
      
      # Schedule the next batch if any are waiting
      schedule_next_batch
    end
  end

  private

  def process_batch(batch)
    orders = batch.ordered_orders.unprinted
    printer = Printer.new

    Rails.logger.info("Printing #{orders.count} orders in batch #{batch.batch_id}")

    orders.each do |order|
      begin
        Rails.logger.info("Printing order #{order.remote_id} - #{order.last_name} (sequence #{order.batch_sequence})")
        
        if printer.print_order(order)
          order.mark_printed!
          Rails.logger.info("Successfully printed order #{order.remote_id} - #{order.last_name}")
        else
          order.mark_print_error!("Printer failed to print order")
          Rails.logger.error("Failed to print order #{order.remote_id} - #{order.last_name}")
        end
      rescue => e
        error_msg = "Print error: #{e.message}"
        order.mark_print_error!(error_msg)
        Rails.logger.error("Error printing order #{order.id}: #{error_msg}")
      end
    end
  end

  def schedule_next_batch
    # Check if there are more batches to process
    if PrintBatch.printable.any?
      Rails.logger.info("Scheduling next batch for processing")
      PrintBatchProcessorJob.perform_later
    else
      Rails.logger.info("No more batches to process")
    end
  end
end