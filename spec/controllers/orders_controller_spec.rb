require 'rails_helper'

RSpec.describe OrdersController, type: :controller do
  before do
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('test', 'secret')
  end

  let(:order_attrs) do
    { last_name: 'Doe', first_name: 'Jane', performance_code: 'TS001', title: 'Test Show', remote_id: 42,
      performance_date: '2026-10-26', performance_time: '2000-01-01T19:00:00.000+00:00', patron_code: 'P1' }
  end

  describe 'POST #create' do
    it 'records the flags sent with the order' do
      post :create, params: order_attrs.merge(flags: %w[star heart]), format: :json
      expect(Order.last.flag_names).to eq(%w[star heart])
      expect(JSON.parse(response.body)['flags']).to eq(%w[star heart])
    end

    it 'accepts an order without flags' do
      post :create, params: order_attrs, format: :json
      expect(response).to have_http_status(:ok)
      expect(Order.last.flag_names).to eq([])
    end
  end

  describe 'PUT #reprint' do
    let!(:order) { FactoryBot.create(:order, flags: %w[star]) }

    it 'replaces the flags when sent' do
      put :reprint, params: { id: order.id, flags: %w[heart] }, format: :json
      expect(order.reload.flag_names).to eq(%w[heart])
    end

    it 'keeps the flags when none are sent' do
      put :reprint, params: { id: order.id }, format: :json
      expect(order.reload.flag_names).to eq(%w[star])
    end
  end
end
