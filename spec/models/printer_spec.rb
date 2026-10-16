require 'rails_helper'

RSpec.describe Printer do
  let(:printer) { Printer.new('localhost', 9100) }

  def cp1252(text)
    text.encode('Windows-1252').b
  end

  def order_with(code:, date:, time:)
    FactoryBot.build(:order, performance_code: code, performance_date: Date.parse(date),
                             performance_time: Time.zone.parse("2000-01-01 #{time}"))
  end

  describe '#stub' do
    it 'puts the day of week next to the time, flush right, without AM/PM' do
      order = order_with(code: 'EXPLORE1026', date: '2026-10-26', time: '19:00')
      expect(printer.stub(order)).to include('<RC10,1615>EXPLORE1026 MON 7:00<RC10,1570>')
    end

    it 'keeps the three-letter day when a two-digit hour still fits' do
      order = order_with(code: 'TS001', date: '2026-11-14', time: '10:30')
      expect(printer.stub(order)).to include('<RC10,1615>TS001      SAT 10:30<RC10,1570>')
    end

    it 'keeps the whole performance code and shortens the day to two letters when needed' do
      order = order_with(code: 'EXPLORE1026', date: '2026-11-14', time: '10:30')
      expect(printer.stub(order)).to include('<RC10,1615>EXPLORE1026 SA 10:30<RC10,1570>')
    end

    {
      'EXPLORE10260' => 'EXPLORE10260 SA 1030',      # drop the colon
      'EXPLORE102601' => 'EXPLORE102601 SA1030',     # then the space
      'EXPLORE1026012' => 'EXPLORE1026012  1030',    # then the day
      'EXPLORE1026012345' => 'EXPLORE1026012345 1030' # never cut the code
    }.each do |code, line|
      it "fits #{code.length}-character code #{code} as #{line.inspect}" do
        order = order_with(code: code, date: '2026-11-14', time: '10:30')
        expect(printer.stub(order)).to include("<RC10,1615>#{line}<RC10,1570>")
      end
    end
  end

  describe '#receipt_fgl' do
    def receipt_order(flags: nil, last_name: 'Doe')
      order = FactoryBot.build(:order, last_name: last_name, flags: flags)
      order.line_items.build(description: 'GENERAL', amount: 35)
      order.payments.build(payment_type: 'Visa', transaction_id: '1234', amount: 35)
      order
    end

    def icon(name)
      Flag.find(name).bitmap
    end

    it 'sends no icon bytes for an order without flags' do
      expect(printer.receipt_fgl(receipt_order)).not_to include('<bmp>')
    end

    it 'prints each flag inline, right-aligned in the RECEIPT band, in the order sent' do
      fgl = printer.receipt_fgl(receipt_order(flags: %w[star heart]))
      star = Fgl.print_inline_bitmap(474, 1492, icon('star'))
      heart = Fgl.print_inline_bitmap(526, 1492, icon('heart'))
      expect(fgl).to include(star + heart)
    end

    it 'sends only the bitmaps of the flags it prints' do
      fgl = printer.receipt_fgl(receipt_order(flags: %w[ticket]))
      expect(fgl.scan('<bmp>'.b).size).to eq(1)
      expect(fgl.bytesize).to eq(printer.receipt_fgl(receipt_order).bytesize +
                                 Fgl.print_inline_bitmap(526, 1492, icon('ticket')).bytesize)
    end

    it 'skips names not in the registry' do
      fgl = printer.receipt_fgl(receipt_order(flags: %w[unicorn star]))
      expect(fgl.scan('<bmp>'.b).size).to eq(1)
      expect(fgl).to include(Fgl.print_inline_bitmap(526, 1492, icon('star')))
    end

    it "prints at most #{Printer::MAX_RECEIPT_FLAGS} flags and drops the rest" do
      fgl = printer.receipt_fgl(receipt_order(flags: %w[flag star ticket heart checkmark]))
      expect(fgl.scan('<bmp>'.b).size).to eq(Printer::MAX_RECEIPT_FLAGS)
      expect(fgl).not_to include(icon('heart'))
    end

    it 'keeps accented names, in code page 1252, alongside the icons' do
      fgl = printer.receipt_fgl(receipt_order(flags: %w[star], last_name: 'Muñoz'))
      expect(fgl).to include(cp1252('MUÑOZ'))
    end

    it 'ends with the print command' do
      expect(printer.receipt_fgl(receipt_order(flags: %w[star]))).to end_with('<p>')
    end
  end

  describe 'tickets' do
    it 'never carries flag icons on the stub' do
      order = FactoryBot.build(:order, flags: %w[star])
      expect(printer.stub(order, 'GA')).not_to include('<bmp>')
    end
  end

  describe 'accented text' do
    let(:order) do
      FactoryBot.build(:order, first_name: 'José', last_name: 'Muñoz', title: 'Café Müller',
                               credit_1: 'Written by Françoise Sagan', credit_2: 'Directed by Zoë Ruíz',
                               venue: 'Théâtre', theater: 'Théâtre Wit', performance_code: 'CAFÉ1026',
                               patron_code: 'ÆØ1')
    end

    it 'prints the stub, in resident OCR fonts, without accents' do
      stub = printer.stub(order, 'GÉN')
      expect(stub).to include('MUNOZ, JOSE', 'CAFE1026', 'AEO1 GEN')
      expect(stub).to be_ascii_only
    end

    it 'shortens the stub name after dropping accents' do
      order.last_name = 'Großmannßtraßenberg'
      expect(printer.stub(order)).to include('GROSSMANNSSTRASSENBE<')
    end

    it 'prints receipt text in code page 1252' do
      order.line_items.build(description: 'Crème brûlée', amount: 5)
      order.payments.build(payment_type: 'Gift card', transaction_id: 'Noël', amount: 5)
      fgl = printer.receipt_fgl(order)
      expect(fgl).to include(cp1252('MUÑOZ, JOSÉ'), cp1252('Café Müller'), cp1252('CRÈME BRÛLÉE'), cp1252('Noël'))
      expect(fgl).not_to include('Ã'.b)
    end

    it 'prints ticket text in code page 1252 and its OCR lines without accents' do
      ticket = Ticket.new(order: order, seat: 'Señor 1', ticket_class: 'GÉN')
      order.id = 7
      printer.print_ticket(ticket)
      sent = printer.instance_variable_get(:@buffer)
      expect(sent).to include(cp1252('Café Müller'), cp1252('Françoise Sagan'), cp1252('Zoë Ruíz'),
                              cp1252('Théâtre Wit presents'), cp1252('Señor 1'), 'CAFE1026 GEN', 'AEO1')
      expect(sent).not_to include('Ã'.b)
    end

    it 'prints characters outside code page 1252 as ?' do
      order.title = 'Tokyo 東京'
      expect(printer.receipt_fgl(order)).to include('Tokyo ??'.b)
    end
  end
end
