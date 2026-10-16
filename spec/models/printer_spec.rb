require 'rails_helper'

RSpec.describe Printer do
  let(:printer) { Printer.new('localhost', 9100) }

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
end
