class OrdersController < ApplicationController
  before_action :authorize

  # GET /orders/1
  # GET /orders/1.xml
  def show
    @order = Order.find(params[:id])
    render json: @order
  end

  # GET /orders
  # GET /orders.xml
  def index
    @orders = Order.all
    render json: @orders
  end


  # GET /orders/new
  # GET /orders/new.xml
  def new
    @order = Order.new
    render json: @order
  end

  # POST /orders
  # POST /orders.xml
  def create
    # Handle nested attributes manually to map fields correctly and decode entities
    order_data = decode_entities(order_params.except(:line_items_attributes, :payments_attributes, :tickets_attributes))
    @order = Order.new(order_data)

    if @order.save
      # Handle line items - these already have the correct fields
      if params[:line_items_attributes]
        params[:line_items_attributes].each do |item_attrs|
          @order.line_items.create!(item_attrs.permit(:description, :amount))
        end
      end

      # Handle payments - map description to transaction_id and parse payment_type  
      if params[:payments_attributes]
        params[:payments_attributes].each do |payment_attrs|
          description = payment_attrs[:description] || ""
          
          # Parse payment description to extract payment type and transaction ID
          # Format: "PaymentType::TransactionID" or just description if no ::
          if description.include?("::")
            payment_type, transaction_id = description.split("::", 2)
          else
            payment_type = "Unknown"
            transaction_id = description
          end
          
          @order.payments.create!(
            amount: payment_attrs[:amount],
            payment_type: payment_type.strip,
            transaction_id: transaction_id.strip
          )
        end
      end

      # Handle tickets - these already have the correct fields
      if params[:tickets_attributes]
        params[:tickets_attributes].each do |ticket_attrs|
          @order.tickets.create!(ticket_attrs.permit(:ticket_class, :seat))
        end
      end

      render json: @order
    else
      render json: @order.errors, status: :unprocessable_entity
    end
  end

  def find_by_remote
    @order = Order.find_by_remote_id(params[:id])
    render json: @order
  end

  def print
    # POST /orders/:id/print
    @order = Order.find(params[:id])
    
    begin
      if @order.in_batch?
        # If order is in a batch, check if we should trigger batch processing
        batch = @order.print_batch
        if batch&.ready? || batch&.processing?
          PrintBatchProcessorJob.perform_later
          render json: { message: "Order is in batch #{@order.batch_id}. Batch processing initiated." }
        else
          render json: { error: "Order is in batch #{@order.batch_id} but batch is not ready (status: #{batch&.status || 'unknown'})" }, 
                 status: :unprocessable_entity
        end
      else
        # Individual order printing
        if @order.print_individual
          render json: { message: "Order printed successfully" }
        else
          render json: { error: "Failed to print order" }, status: :unprocessable_entity
        end
      end
    rescue => e
      Rails.logger.error("Print error for order #{@order.id}: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  # PUT /orders/1
  # PUT /orders/1.xml
  def update
    @order = Order.find(params[:id])
    decoded_params = decode_entities(order_params)
    if @order.update_attributes(decoded_params)
      head :ok
    else
      render json: @order.errors, status: :unprocessable_entity
    end
  end

  # PUT /orders/:id/reprint
  # Marks an existing order for reprinting, updating order data if provided
  def reprint
    @order = Order.find(params[:id])

    # Increment reprint count and reset status to unprinted
    @order.reprint_count = (@order.reprint_count || 0) + 1
    @order.print_status = 'unprinted'

    # Update batch information if provided
    @order.batch_id = params[:batch_id] if params[:batch_id].present?
    @order.batch_sequence = params[:batch_sequence] if params[:batch_sequence].present?

    # Update top-level order attributes if provided
    updatable_attrs = params.permit(:last_name, :first_name, :performance_code, :venue,
      :theater, :title, :credit_1, :credit_2, :patron_code, :performance_date,
      :performance_time, :amount, :remote_id)
    @order.assign_attributes(decode_entities(updatable_attrs.to_h).compact)

    # Replace tickets if provided (e.g. seat changes)
    if params[:tickets_attributes].present?
      @order.tickets.destroy_all
      params[:tickets_attributes].each do |ticket_attrs|
        @order.tickets.build(ticket_attrs.permit(:ticket_class, :seat))
      end
    end

    # Replace line items if provided
    if params[:line_items_attributes].present?
      @order.line_items.destroy_all
      params[:line_items_attributes].each do |item_attrs|
        @order.line_items.build(item_attrs.permit(:description, :amount))
      end
    end

    # Replace payments if provided
    if params[:payments_attributes].present?
      @order.payments.destroy_all
      params[:payments_attributes].each do |payment_attrs|
        description = payment_attrs[:description] || ""
        if description.include?("::")
          payment_type, transaction_id = description.split("::", 2)
        else
          payment_type = "Unknown"
          transaction_id = description
        end
        @order.payments.build(
          amount: payment_attrs[:amount],
          payment_type: payment_type.strip,
          transaction_id: transaction_id.strip
        )
      end
    end

    if @order.save
      render json: @order
    else
      render json: @order.errors, status: :unprocessable_entity
    end
  end

  # DELETE /orders/1
  # DELETE /orders/1.xml
  def destroy
    @order = Order.find(params[:id])
    @order.destroy
    head :ok
  end

  private
  def order_params
    params.permit(:last_name, :first_name, :performance_code, :venue, :theater,
      :title, :credit_1, :credit_2, :patron_code, :performance_date, :performance_time,
      :amount, :remote_id, :status, :reprints, :batch_id, :batch_sequence, :print_status)
  end

  # Recursively decode HTML entities in the object
  def decode_entities(object)
    case object
    when String
      CGI.unescapeHTML(object)
    when Array
      object.map { |element| decode_entities(element) }
    when Hash, ActionController::Parameters
      object.transform_values { |value| decode_entities(value) }
    else
      object
    end
  end

end
