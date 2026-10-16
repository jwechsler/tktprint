require 'cgi'

class Order < ActiveRecord::Base

  UNPRINTED, PRINTED =
      'Unprinted', 'Printed'

  # Flag names are stored comma-separated; anything but lowercase words is dropped
  FLAG_NAME_FORMAT = /\A[a-z0-9_]+\z/

#  validates_uniqueness_of :remote_id

  has_many :line_items, :dependent=>:destroy
  has_many :payments, :dependent=>:destroy
  has_many :tickets, :dependent=>:destroy
  belongs_to :print_batch, foreign_key: :batch_id, primary_key: :batch_id, optional: true

  accepts_nested_attributes_for :line_items, :payments, :tickets

  before_save :strip_html
  # Remove automatic printing - now handled by batch processing
  # after_create :print
  # after_update :print, :if=>:unprinted?

  scope :in_batch, ->(batch_id) { where(batch_id: batch_id) }
  scope :unprinted, -> { where(print_status: 'unprinted') }
  scope :printed, -> { where(print_status: 'printed') }
  scope :print_errors, -> { where('print_status LIKE ?', 'error:%') }

  include ActionView::Helpers::SanitizeHelper

  def strip_html # Automatically strips any tags from any string to text typed column and decodes HTML entities
    for column in Order.content_columns
      if column.type == :string || column.type == :text # if the column is text-typed
        if !self[column.name].nil? # strip html from string if it's not empty
          # First strip HTML tags, then decode HTML entities (like &amp; -> &)
          self[column.name] = CGI.unescapeHTML(strip_tags(self[column.name]))
        end
      end
    end
  end

  def as_json(options = {})
    super(options.merge(include: [:tickets])).merge('flags' => flag_names)
  end

  # Flag names in the order stagemgr sent them
  def flag_names
    flags.to_s.split(',')
  end

  # Accepts an array of names (or a comma-separated string); blank means no flags
  def flags=(names)
    list = names.is_a?(String) ? names.split(',') : Array(names)
    cleaned = list.map { |name| name.to_s.strip.downcase }.select { |name| name.match?(FLAG_NAME_FORMAT) }.uniq
    super(cleaned.empty? ? nil : cleaned.join(','))
  end

  def unprinted?
    print_status == 'unprinted'
  end

  def printed?
    print_status == 'printed'
  end

  def print_error?
    print_status&.start_with?('error:')
  end

  def in_batch?
    batch_id.present?
  end

  def mark_printed!
    update!(print_status: 'printed', printed_at: Time.current)
  end

  def mark_print_error!(error_message)
    update!(print_status: "error: #{error_message}", print_error: error_message)
  end

  def print_individual
    # Individual printing for orders not in a batch
    return false if in_batch?
    
    Rails.logger.info("*** individual print called for order #{id}")
    
    printer = Printer.new
    begin
      if printer.print_order(self)
        mark_printed!
        self.status = Order::PRINTED
        save!
        true
      else
        mark_print_error!("Printer failed to print order")
        false
      end
    rescue => e
      Rails.logger.error("Print error for order #{id}: #{e.message}")
      mark_print_error!(e.message)
      false
    end
  end

  # Legacy compatibility
  def print
    print_individual
  end

end
