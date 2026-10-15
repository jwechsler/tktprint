require 'rails_helper'

RSpec.describe PrintBatch, type: :model do
  describe 'validations' do
    subject { FactoryBot.create(:print_batch) }
    
    it { should validate_presence_of(:batch_id) }
    it { should validate_uniqueness_of(:batch_id) }
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[pending ready processing complete complete_with_error]) }
  end

  describe 'associations' do
    it { should have_many(:orders).with_foreign_key(:batch_id).with_primary_key(:batch_id).dependent(:nullify) }
  end

  describe 'scopes' do
    let!(:pending_batch) { FactoryBot.create(:print_batch, status: 'pending') }
    let!(:ready_batch) { FactoryBot.create(:print_batch, status: 'ready') }
    let!(:processing_batch) { FactoryBot.create(:print_batch, status: 'processing') }
    let!(:complete_batch) { FactoryBot.create(:print_batch, status: 'complete') }
    let!(:complete_with_error_batch) { FactoryBot.create(:print_batch, status: 'complete_with_error') }

    describe '.pending' do
      it 'returns only pending batches' do
        expect(PrintBatch.pending).to contain_exactly(pending_batch)
      end
    end

    describe '.ready' do
      it 'returns only ready batches' do
        expect(PrintBatch.ready).to contain_exactly(ready_batch)
      end
    end

    describe '.processing' do
      it 'returns only processing batches' do
        expect(PrintBatch.processing).to contain_exactly(processing_batch)
      end
    end

    describe '.complete' do
      it 'returns complete and complete_with_error batches' do
        expect(PrintBatch.complete).to contain_exactly(complete_batch, complete_with_error_batch)
      end
    end

    describe '.stale' do
      let!(:stale_batch) { FactoryBot.create(:print_batch, status: 'pending', created_at: 25.hours.ago) }
      let!(:fresh_batch) { FactoryBot.create(:print_batch, status: 'pending', created_at: 1.hour.ago) }

      it 'returns pending batches older than 24 hours' do
        expect(PrintBatch.stale).to contain_exactly(stale_batch)
      end
    end

    describe '.printable' do
      it 'returns ready and processing batches ordered by priority' do
        result = PrintBatch.printable
        
        expect(result).to eq([processing_batch, ready_batch])
      end
    end
  end

  describe 'status predicates' do
    let(:batch) { FactoryBot.build(:print_batch) }

    describe '#pending?' do
      it 'returns true when status is pending' do
        batch.status = 'pending'
        expect(batch.pending?).to be true
      end

      it 'returns false when status is not pending' do
        batch.status = 'ready'
        expect(batch.pending?).to be false
      end
    end

    describe '#ready?' do
      it 'returns true when status is ready' do
        batch.status = 'ready'
        expect(batch.ready?).to be true
      end

      it 'returns false when status is not ready' do
        batch.status = 'pending'
        expect(batch.ready?).to be false
      end
    end

    describe '#processing?' do
      it 'returns true when status is processing' do
        batch.status = 'processing'
        expect(batch.processing?).to be true
      end

      it 'returns false when status is not processing' do
        batch.status = 'ready'
        expect(batch.processing?).to be false
      end
    end

    describe '#complete?' do
      it 'returns true when status is complete' do
        batch.status = 'complete'
        expect(batch.complete?).to be true
      end

      it 'returns true when status is complete_with_error' do
        batch.status = 'complete_with_error'
        expect(batch.complete?).to be true
      end

      it 'returns false when status is not complete' do
        batch.status = 'processing'
        expect(batch.complete?).to be false
      end
    end

    describe '#complete_with_error?' do
      it 'returns true when status is complete_with_error' do
        batch.status = 'complete_with_error'
        expect(batch.complete_with_error?).to be true
      end

      it 'returns false when status is not complete_with_error' do
        batch.status = 'complete'
        expect(batch.complete_with_error?).to be false
      end
    end

    describe '#stale?' do
      it 'returns true when batch is pending and older than 24 hours' do
        batch.status = 'pending'
        batch.created_at = 25.hours.ago
        expect(batch.stale?).to be true
      end

      it 'returns false when batch is not pending' do
        batch.status = 'ready'
        batch.created_at = 25.hours.ago
        expect(batch.stale?).to be false
      end

      it 'returns false when batch is pending but not old enough' do
        batch.status = 'pending'
        batch.created_at = 1.hour.ago
        expect(batch.stale?).to be false
      end
    end
  end

  describe 'status transitions' do
    let(:batch) { FactoryBot.create(:print_batch, status: 'pending') }

    describe '#mark_ready!' do
      it 'updates status to ready and sets ready_at timestamp' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)

        batch.mark_ready!

        expect(batch.status).to eq('ready')
        expect(batch.ready_at).to eq(freeze_time)
      end
    end

    describe '#mark_processing!' do
      it 'updates status to processing and sets started_at timestamp' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)

        batch.mark_processing!

        expect(batch.status).to eq('processing')
        expect(batch.started_at).to eq(freeze_time)
      end
    end

    describe '#mark_complete!' do
      let(:freeze_time) { Time.current }

      before do
        allow(Time).to receive(:current).and_return(freeze_time)
      end

      context 'when there are no errors' do
        it 'updates status to complete and sets completed_at timestamp' do
          batch.error_count = 0
          batch.mark_complete!

          expect(batch.status).to eq('complete')
          expect(batch.completed_at).to eq(freeze_time)
        end
      end

      context 'when there are errors' do
        it 'updates status to complete_with_error and sets completed_at timestamp' do
          batch.error_count = 2
          batch.mark_complete!

          expect(batch.status).to eq('complete_with_error')
          expect(batch.completed_at).to eq(freeze_time)
        end
      end
    end
  end

  describe '#update_counts!' do
    let(:batch) { FactoryBot.create(:print_batch) }
    let!(:orders) do
      [
        FactoryBot.create(:order, batch_id: batch.batch_id, print_status: 'unprinted'),
        FactoryBot.create(:order, batch_id: batch.batch_id, print_status: 'printed'),
        FactoryBot.create(:order, batch_id: batch.batch_id, print_status: 'printed'),
        FactoryBot.create(:order, batch_id: batch.batch_id, print_status: 'error: printer jam'),
        FactoryBot.create(:order, batch_id: batch.batch_id, print_status: 'error: network timeout')
      ]
    end

    it 'updates order_count with total orders in batch' do
      batch.update_counts!
      expect(batch.order_count).to eq(5)
    end

    it 'updates printed_count with successfully printed orders' do
      batch.update_counts!
      expect(batch.printed_count).to eq(2)
    end

    it 'updates error_count with orders that failed to print' do
      batch.update_counts!
      expect(batch.error_count).to eq(2)
    end

    it 'saves the batch after updating counts' do
      expect(batch).to receive(:save!)
      batch.update_counts!
    end
  end

  describe '#ordered_orders' do
    let(:batch) { FactoryBot.create(:print_batch) }
    let!(:orders) do
      [
        FactoryBot.create(:order, batch_id: batch.batch_id, batch_sequence: 3),
        FactoryBot.create(:order, batch_id: batch.batch_id, batch_sequence: 1),
        FactoryBot.create(:order, batch_id: batch.batch_id, batch_sequence: 2),
        FactoryBot.create(:order, batch_id: 'other_batch', batch_sequence: 1)
      ]
    end

    it 'returns orders in batch_sequence order' do
      result = batch.ordered_orders
      
      expect(result.pluck(:batch_sequence)).to eq([1, 2, 3])
    end

    it 'only returns orders for this batch' do
      result = batch.ordered_orders
      
      expect(result.count).to eq(3)
      expect(result.pluck(:batch_id).uniq).to eq([batch.batch_id])
    end
  end

  describe '#has_errors?' do
    let(:batch) { FactoryBot.create(:print_batch) }

    it 'returns true when error_count is greater than 0' do
      batch.error_count = 1
      expect(batch.has_errors?).to be true
    end

    it 'returns false when error_count is 0' do
      batch.error_count = 0
      expect(batch.has_errors?).to be false
    end
  end

  describe '#progress_percentage' do
    let(:batch) { FactoryBot.create(:print_batch) }

    context 'when order_count is 0' do
      it 'returns 0' do
        batch.order_count = 0
        expect(batch.progress_percentage).to eq(0)
      end
    end

    context 'when order_count is greater than 0' do
      it 'calculates percentage based on printed and error counts' do
        batch.order_count = 10
        batch.printed_count = 6
        batch.error_count = 2
        
        expect(batch.progress_percentage).to eq(80.0)
      end

      it 'rounds to 1 decimal place' do
        batch.order_count = 3
        batch.printed_count = 1
        batch.error_count = 1
        
        expect(batch.progress_percentage).to eq(66.7)
      end
    end
  end
end