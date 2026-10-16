require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'associations' do
    it { should belong_to(:print_batch).with_foreign_key(:batch_id).with_primary_key(:batch_id).optional }
    it { should have_many(:line_items).dependent(:destroy) }
    it { should have_many(:payments).dependent(:destroy) }
    it { should have_many(:tickets).dependent(:destroy) }
  end

  describe 'scopes' do
    let!(:batch_id) { 'test_batch_001' }
    let!(:order_in_batch) { FactoryBot.create(:order, batch_id: batch_id, print_status: 'unprinted') }
    let!(:order_not_in_batch) { FactoryBot.create(:order, batch_id: 'other_batch', print_status: 'unprinted') }
    let!(:printed_order) { FactoryBot.create(:order, batch_id: batch_id, print_status: 'printed') }
    let!(:error_order) { FactoryBot.create(:order, batch_id: batch_id, print_status: 'error: printer jam') }

    describe '.in_batch' do
      it 'returns orders in the specified batch' do
        result = Order.in_batch(batch_id)
        expect(result).to contain_exactly(order_in_batch, printed_order, error_order)
      end
    end

    describe '.unprinted' do
      it 'returns orders with unprinted status' do
        result = Order.unprinted
        expect(result).to contain_exactly(order_in_batch, order_not_in_batch)
      end
    end

    describe '.printed' do
      it 'returns orders with printed status' do
        result = Order.printed
        expect(result).to contain_exactly(printed_order)
      end
    end

    describe '.print_errors' do
      it 'returns orders with error status' do
        result = Order.print_errors
        expect(result).to contain_exactly(error_order)
      end
    end
  end

  describe 'print status predicates' do
    let(:order) { FactoryBot.build(:order) }

    describe '#unprinted?' do
      it 'returns true when print_status is unprinted' do
        order.print_status = 'unprinted'
        expect(order.unprinted?).to be true
      end

      it 'returns false when print_status is not unprinted' do
        order.print_status = 'printed'
        expect(order.unprinted?).to be false
      end
    end

    describe '#printed?' do
      it 'returns true when print_status is printed' do
        order.print_status = 'printed'
        expect(order.printed?).to be true
      end

      it 'returns false when print_status is not printed' do
        order.print_status = 'unprinted'
        expect(order.printed?).to be false
      end
    end

    describe '#print_error?' do
      it 'returns true when print_status starts with error:' do
        order.print_status = 'error: printer jam'
        expect(order.print_error?).to be true
      end

      it 'returns false when print_status does not start with error:' do
        order.print_status = 'printed'
        expect(order.print_error?).to be false
      end

      it 'returns false when print_status is nil' do
        order.print_status = nil
        expect(order.print_error?).to be_falsy
      end
    end

    describe '#in_batch?' do
      it 'returns true when batch_id is present' do
        order.batch_id = 'test_batch_001'
        expect(order.in_batch?).to be true
      end

      it 'returns false when batch_id is nil' do
        order.batch_id = nil
        expect(order.in_batch?).to be false
      end

      it 'returns false when batch_id is empty string' do
        order.batch_id = ''
        expect(order.in_batch?).to be false
      end
    end
  end

  describe 'print status management' do
    let(:order) { FactoryBot.create(:order) }

    describe '#mark_printed!' do
      it 'updates print_status to printed' do
        freeze_time = Time.current
        allow(Time).to receive(:current).and_return(freeze_time)

        order.mark_printed!

        expect(order.print_status).to eq('printed')
        expect(order.printed_at).to eq(freeze_time)
      end
    end

    describe '#mark_print_error!' do
      it 'updates print_status with error message' do
        error_message = 'printer jam'
        order.mark_print_error!(error_message)

        expect(order.print_status).to eq('error: printer jam')
        expect(order.print_error).to eq(error_message)
      end
    end
  end

  describe 'printing behavior' do
    let(:order) { FactoryBot.create(:order, :with_tickets) }
    let(:printer) { double('Printer', print_order: true) }

    before do
      allow(Printer).to receive(:new).and_return(printer)
    end

    describe '#print_individual' do
      context 'when order is not in a batch' do
        it 'prints the order individually' do
          expect(printer).to receive(:print_order).with(order)
          expect(order).to receive(:mark_printed!)
          expect(order).to receive(:save!)

          result = order.print_individual
          expect(result).to be true
        end

        it 'updates status to PRINTED' do
          order.print_individual
          expect(order.status).to eq('Printed')
        end

        it 'logs the print attempt' do
          expect(Rails.logger).to receive(:info).with(/individual print called for order #{order.id}/)
          order.print_individual
        end

        context 'when printer fails' do
          before do
            allow(printer).to receive(:print_order).and_return(false)
          end

          it 'marks order with print error' do
            expect(order).to receive(:mark_print_error!).with('Printer failed to print order')
            result = order.print_individual
            expect(result).to be false
          end
        end

        context 'when printer raises exception' do
          before do
            allow(printer).to receive(:print_order).and_raise(StandardError.new('Network error'))
          end

          it 'marks order with print error and logs' do
            expect(Rails.logger).to receive(:error).with(/Print error for order #{order.id}: Network error/)
            expect(order).to receive(:mark_print_error!).with('Network error')
            
            result = order.print_individual
            expect(result).to be false
          end
        end
      end

      context 'when order is in a batch' do
        before do
          order.batch_id = 'test_batch_001'
        end

        it 'returns false and does not print' do
          expect(printer).not_to receive(:print_order)
          result = order.print_individual
          expect(result).to be false
        end
      end
    end

    describe '#print (legacy compatibility)' do
      it 'calls print_individual' do
        expect(order).to receive(:print_individual)
        order.print
      end
    end
  end

  describe 'HTML sanitization' do
    let(:order) { FactoryBot.build(:order) }

    before do
      order.first_name = 'John<script>alert("xss")</script>'
      order.last_name = 'Doe &amp; Company'
      order.title = '<b>Bold Title</b>'
    end

    it 'strips HTML tags and decodes entities before create' do
      order.save!

      expect(order.first_name).to eq('John')
      expect(order.last_name).to eq('Doe & Company')
      expect(order.title).to eq('Bold Title')
    end

    it 'decodes HTML entities on update' do
      order.save!
      order.update!(title: 'Fizz &amp; Ginger: A Jazz Story')
      expect(order.title).to eq('Fizz & Ginger: A Jazz Story')
    end

    it 'preserves bare ampersands' do
      order.title = 'Fizz & Ginger'
      order.save!
      expect(order.title).to eq('Fizz & Ginger')
    end
  end

  describe 'JSON serialization' do
    let(:order) { FactoryBot.create(:order, :with_tickets) }

    it 'includes tickets in JSON representation' do
      json_data = order.as_json
      expect(json_data).to have_key('tickets')
      expect(json_data['tickets']).to be_an(Array)
      expect(json_data['tickets'].size).to eq(order.tickets.count)
    end

    it 'returns flags as an array' do
      order.update!(flags: %w[star heart])
      expect(order.as_json['flags']).to eq(%w[star heart])
    end
  end

  describe 'flags' do
    it 'stores flag names comma-separated, in the order sent' do
      order = FactoryBot.create(:order, flags: %w[heart star])
      expect(order.reload[:flags]).to eq('heart,star')
      expect(order.flag_names).to eq(%w[heart star])
    end

    it 'has no flags when none are sent' do
      order = FactoryBot.create(:order)
      expect(order[:flags]).to be_nil
      expect(order.flag_names).to eq([])
    end

    it 'stores nothing for an empty list' do
      expect(FactoryBot.build(:order, flags: [])[:flags]).to be_nil
    end

    it 'trims, downcases and de-duplicates names and drops anything that is not a plain name' do
      order = FactoryBot.build(:order, flags: [' Star ', 'star', 'heart,ticket', '<b>x</b>', ''])
      expect(order.flag_names).to eq(%w[star])
    end

    it 'accepts a comma-separated string' do
      expect(FactoryBot.build(:order, flags: 'star, heart').flag_names).to eq(%w[star heart])
    end
  end
end