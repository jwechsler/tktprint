class TicketsController < ApplicationController
  before_action :authorize

  def index
    @tickets = Ticket.where(order_id: params[:order_id])
    respond_to do |format|
      format.json { render :json => @tickets}
    end
  end

  def edit
    @ticket = Ticket.find(params[:id])
    respond_to do |format|
      format.json { render :json => @ticket}
    end
  end

  # PUT /orders/1
  # PUT /orders/1.xml
  def update
    @ticket = Ticket.find(params[:id])
    @ticket.update_attributes(ticket_params)
    respond_to do |format|
      if @ticket.save
        format.json { head :ok }
      else
        format.json { render :json => @ticket.errors, :status => :unprocessable_entity }
      end
    end
  end

  private
  def ticket_params
    params.permit(:seat)
  end
end
