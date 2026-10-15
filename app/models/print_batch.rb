class PrintBatch < ActiveRecord::Base
  has_many :orders, foreign_key: :batch_id, primary_key: :batch_id, dependent: :nullify

  validates :batch_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[pending ready processing complete complete_with_error] }

  scope :pending, -> { where(status: 'pending') }
  scope :ready, -> { where(status: 'ready') }
  scope :processing, -> { where(status: 'processing') }
  scope :complete, -> { where(status: ['complete', 'complete_with_error']) }
  scope :stale, -> { where('status = ? AND created_at < ?', 'pending', 24.hours.ago) }

  # Order batches by priority: processing first, then ready
  scope :printable, -> { where(status: ['ready', 'processing']).order(Arel.sql("CASE WHEN status = 'processing' THEN 0 ELSE 1 END, created_at ASC")) }

  def pending?
    status == 'pending'
  end

  def ready?
    status == 'ready'
  end

  def processing?
    status == 'processing'
  end

  def complete?
    status.in?(['complete', 'complete_with_error'])
  end

  def complete_with_error?
    status == 'complete_with_error'
  end

  def stale?
    pending? && created_at < 24.hours.ago
  end

  def mark_ready!
    update!(status: 'ready', ready_at: Time.current)
  end

  def mark_processing!
    update!(status: 'processing', started_at: Time.current)
  end

  def mark_complete!
    if error_count > 0
      update!(status: 'complete_with_error', completed_at: Time.current)
    else
      update!(status: 'complete', completed_at: Time.current)
    end
  end

  def update_counts!
    orders_in_batch = orders.where(batch_id: batch_id)
    self.order_count = orders_in_batch.count
    self.printed_count = orders_in_batch.where(print_status: 'printed').count
    self.error_count = orders_in_batch.where('print_status LIKE ?', 'error:%').count
    save!
  end

  def ordered_orders
    orders.where(batch_id: batch_id).order(:batch_sequence)
  end

  def has_errors?
    error_count > 0
  end

  def progress_percentage
    return 0 if order_count == 0
    ((printed_count + error_count).to_f / order_count * 100).round(1)
  end
end