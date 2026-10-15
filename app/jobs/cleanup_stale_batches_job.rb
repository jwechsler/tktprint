class CleanupStaleBatchesJob < ApplicationJob
  queue_as :default

  def perform
    stale_batches = PrintBatch.stale
    
    if stale_batches.exists?
      Rails.logger.info("Found #{stale_batches.count} stale print batches to clean up")
      
      stale_batches.find_each do |batch|
        Rails.logger.info("Removing stale batch: #{batch.batch_id} (created #{batch.created_at})")
        
        # Clear batch_id from associated orders so they can be processed individually
        batch.orders.update_all(batch_id: nil, batch_sequence: nil)
        
        # Delete the stale batch
        batch.destroy!
      end
    end
  end
end