class PrintBatchesController < ApplicationController
  before_action :authorize

  # POST /print_batches
  def create
    batch_id = params[:batch_id]
    
    if batch_id.blank?
      render json: { error: 'batch_id is required' }, status: :bad_request
      return
    end

    begin
      print_batch = PrintBatch.create!(
        batch_id: batch_id,
        status: 'pending'
      )
      
      Rails.logger.info("Created print batch: #{batch_id}")
      render json: print_batch, status: :created
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # Batch already exists (either database constraint or validation error)
      existing_batch = PrintBatch.find_by(batch_id: batch_id)
      render json: existing_batch, status: :ok
    rescue => e
      Rails.logger.error("Error creating print batch #{batch_id}: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  # PUT /print_batches/:batch_id/close
  def close
    batch_id = params[:batch_id]
    
    begin
      print_batch = PrintBatch.find_by!(batch_id: batch_id)
      
      if print_batch.pending?
        print_batch.update_counts!
        print_batch.mark_ready!
        Rails.logger.info("Closed print batch: #{batch_id} (#{print_batch.order_count} orders)")
        
        # Trigger batch processing
        PrintBatchProcessorJob.perform_later
        
        render json: print_batch
      else
        render json: { error: "Batch #{batch_id} is not in pending status (current: #{print_batch.status})" }, 
               status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Print batch #{batch_id} not found" }, status: :not_found
    rescue => e
      Rails.logger.error("Error closing print batch #{batch_id}: #{e.message}")
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  # GET /print_batches/:batch_id
  def show
    batch_id = params[:batch_id]
    
    begin
      print_batch = PrintBatch.find_by!(batch_id: batch_id)
      print_batch.update_counts! # Refresh counts
      render json: print_batch.as_json(include: { orders: { only: [:id, :batch_sequence, :print_status, :printed_at, :print_error] } })
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Print batch #{batch_id} not found" }, status: :not_found
    end
  end

  # GET /print_batches
  def index
    batches = PrintBatch.order(created_at: :desc).limit(50)
    batches.each(&:update_counts!) # Refresh counts for all batches
    render json: batches
  end

  private

  def print_batch_params
    params.permit(:batch_id)
  end
end