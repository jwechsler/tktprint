require 'rails_helper'

RSpec.describe PrintBatchesController, type: :controller do
  let(:valid_auth_header) { ActionController::HttpAuthentication::Basic.encode_credentials('test', 'secret') }
  let(:invalid_auth_header) { ActionController::HttpAuthentication::Basic.encode_credentials('wrong', 'credentials') }

  describe 'authentication' do
    it 'requires HTTP Basic authentication' do
      post :create, params: { batch_id: 'test_batch' }, format: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'accepts valid credentials' do
      request.env['HTTP_AUTHORIZATION'] = valid_auth_header
      post :create, params: { batch_id: 'test_batch' }, format: :json
      expect(response).not_to have_http_status(:unauthorized)
    end

    it 'rejects invalid credentials' do
      request.env['HTTP_AUTHORIZATION'] = invalid_auth_header
      post :create, params: { batch_id: 'test_batch' }, format: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST #create' do
    before do
      request.env['HTTP_AUTHORIZATION'] = valid_auth_header
    end

    context 'with valid parameters' do
      let(:batch_id) { 'test_batch_001' }

      it 'creates a new print batch' do
        expect {
          post :create, params: { batch_id: batch_id }, format: :json
        }.to change(PrintBatch, :count).by(1)
      end

      it 'returns the created batch as JSON' do
        post :create, params: { batch_id: batch_id }, format: :json
        
        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['batch_id']).to eq(batch_id)
        expect(json_response['status']).to eq('pending')
      end

      it 'logs the batch creation' do
        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/Created print batch: #{batch_id}/).once
        post :create, params: { batch_id: batch_id }, format: :json
      end
    end

    context 'with duplicate batch_id' do
      let(:batch_id) { 'duplicate_batch' }

      before do
        FactoryBot.create(:print_batch, batch_id: batch_id)
      end

      it 'returns the existing batch' do
        post :create, params: { batch_id: batch_id }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['batch_id']).to eq(batch_id)
      end

      it 'does not create a new batch' do
        expect {
          post :create, params: { batch_id: batch_id }, format: :json
        }.not_to change(PrintBatch, :count)
      end
    end

    context 'with missing batch_id' do
      it 'returns bad request error' do
        post :create, params: {}, format: :json
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('batch_id is required')
      end
    end

    context 'with blank batch_id' do
      it 'returns bad request error' do
        post :create, params: { batch_id: '' }, format: :json
        
        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('batch_id is required')
      end
    end

    context 'when database error occurs' do
      before do
        allow(PrintBatch).to receive(:create!).and_raise(StandardError.new('Database connection failed'))
      end

      it 'returns unprocessable entity error' do
        post :create, params: { batch_id: 'test_batch' }, format: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error).and_call_original
        expect(Rails.logger).to receive(:error).with(/Error creating print batch/)
        post :create, params: { batch_id: 'test_batch' }, format: :json
      end
    end
  end

  describe 'PUT #close' do
    let(:batch) { FactoryBot.create(:print_batch, status: 'pending') }

    before do
      request.env['HTTP_AUTHORIZATION'] = valid_auth_header
      allow(PrintBatchProcessorJob).to receive(:perform_later)
    end

    context 'with existing pending batch' do
      it 'marks the batch as ready' do
        put :close, params: { batch_id: batch.batch_id }, format: :json
        
        batch.reload
        expect(batch.status).to eq('ready')
        expect(batch.ready_at).to be_present
      end

      it 'updates batch counts' do
        expect_any_instance_of(PrintBatch).to receive(:update_counts!)
        put :close, params: { batch_id: batch.batch_id }, format: :json
      end

      it 'triggers batch processing job' do
        put :close, params: { batch_id: batch.batch_id }, format: :json
        expect(PrintBatchProcessorJob).to have_received(:perform_later)
      end

      it 'returns the updated batch as JSON' do
        put :close, params: { batch_id: batch.batch_id }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['batch_id']).to eq(batch.batch_id)
        expect(json_response['status']).to eq('ready')
      end

      it 'logs the batch closure' do
        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/Closed print batch: #{batch.batch_id}/).once
        put :close, params: { batch_id: batch.batch_id }, format: :json
      end
    end

    context 'with non-pending batch' do
      let(:batch) { FactoryBot.create(:print_batch, :ready) }

      it 'returns unprocessable entity error' do
        put :close, params: { batch_id: batch.batch_id }, format: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('is not in pending status')
      end

      it 'does not trigger processing job' do
        put :close, params: { batch_id: batch.batch_id }, format: :json
        expect(PrintBatchProcessorJob).not_to have_received(:perform_later)
      end
    end

    context 'with non-existent batch' do
      it 'returns not found error' do
        put :close, params: { batch_id: 'non_existent_batch' }, format: :json
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('not found')
      end
    end

    context 'when database error occurs' do
      before do
        allow_any_instance_of(PrintBatch).to receive(:mark_ready!).and_raise(ActiveRecord::RecordInvalid.new(PrintBatch.new))
      end

      it 'returns unprocessable entity error' do
        put :close, params: { batch_id: batch.batch_id }, format: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('error')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Error closing print batch/)
        put :close, params: { batch_id: batch.batch_id }, format: :json
      end
    end
  end

  describe 'GET #show' do
    let(:batch) { FactoryBot.create(:print_batch) }
    let!(:orders) { FactoryBot.create_list(:order, 2, batch_id: batch.batch_id) }

    before do
      request.env['HTTP_AUTHORIZATION'] = valid_auth_header
    end

    context 'with existing batch' do
      it 'returns the batch with orders' do
        get :show, params: { batch_id: batch.batch_id }, format: :json
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['batch_id']).to eq(batch.batch_id)
        expect(json_response['orders']).to be_an(Array)
        expect(json_response['orders'].length).to eq(2)
      end

      it 'updates batch counts before returning' do
        expect_any_instance_of(PrintBatch).to receive(:update_counts!)
        get :show, params: { batch_id: batch.batch_id }, format: :json
      end

      it 'includes only specific order fields' do
        get :show, params: { batch_id: batch.batch_id }, format: :json
        
        json_response = JSON.parse(response.body)
        order_fields = json_response['orders'].first.keys
        expect(order_fields).to contain_exactly('id', 'batch_sequence', 'print_status', 'printed_at', 'print_error')
      end
    end

    context 'with non-existent batch' do
      it 'returns not found error' do
        get :show, params: { batch_id: 'non_existent_batch' }, format: :json
        
        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('not found')
      end
    end
  end

  describe 'GET #index' do
    let!(:batches) { FactoryBot.create_list(:print_batch, 3) }

    before do
      request.env['HTTP_AUTHORIZATION'] = valid_auth_header
    end

    it 'returns all batches ordered by creation date' do
      get :index, format: :json
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.length).to eq(3)
      
      # Check ordering (most recent first)
      batch_ids = json_response.map { |b| b['batch_id'] }
      expect(batch_ids).to eq(batches.reverse.map(&:batch_id))
    end

    it 'limits results to 50 batches' do
      FactoryBot.create_list(:print_batch, 55)
      get :index, format: :json
      
      json_response = JSON.parse(response.body)
      expect(json_response.length).to eq(50)
    end

    it 'updates counts for all returned batches' do
      expect(PrintBatch).to receive(:order).with(created_at: :desc).and_call_original
      allow_any_instance_of(PrintBatch).to receive(:update_counts!).and_call_original
      get :index, format: :json
    end
  end

  describe 'parameter filtering' do
    before do
      request.env['HTTP_AUTHORIZATION'] = valid_auth_header
    end

    it 'permits batch_id parameter' do
      post :create, params: { batch_id: 'test', extra_param: 'should_be_filtered' }, format: :json
      
      # Should not raise parameter error and should process batch_id
      expect(response).to have_http_status(:created)
    end
  end
end