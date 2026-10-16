require 'rails_helper'
require 'socket'

RSpec.describe Fgl do
  describe '.load_logo_file' do
    let(:logo_path) { Rails.root.join('public/logo.bmp.example').to_s }
    let(:server) { TCPServer.new('127.0.0.1', 0) }

    before { allow(Fgl).to receive(:sleep) }
    after { server.close }

    it 'announces the logo size in bytes, not characters, and sends the file intact' do
      received = Thread.new do
        client = server.accept
        data = client.read
        client.close
        data
      end

      Fgl.load_logo_file('127.0.0.1', server.addr[1], logo_path)

      logo = File.binread(logo_path)
      expected = "<SP10,10>\e<bmp><G#{logo.bytesize}>".b + logo + "\e".b
      expect(received.value.b).to eq(expected)
    end

    it 'stores the logo in the given slot' do
      received = Thread.new do
        client = server.accept
        data = client.read
        client.close
        data
      end

      Fgl.load_logo_file('127.0.0.1', server.addr[1], logo_path, id: 1)

      expect(received.value.b).to start_with("<ID1><SP10,10>\e<bmp><G".b)
    end
  end

  describe '.print_inline_bitmap' do
    it 'prints the bitmap bytes at a position without storing them' do
      data = "BM\x00\xFF".b
      expect(Fgl.print_inline_bitmap(400, 1492, data)).to eq("<SP400,1492><bmp><G4>".b + data)
    end
  end

  describe '.horizontal_rule' do
    it 'draws a bar across the whole print width, no wider' do
      expect(Fgl.horizontal_rule(110, 5)).to eq('<RC0,110><LT5><VX576>')
    end
  end

  describe '.printer_bytes' do
    it 'converts text to code page 1252' do
      expect(Fgl.printer_bytes('Muñoz')).to eq("Mu\xF1oz".b)
    end

    it 'passes binary strings through unchanged' do
      bytes = "<bmp>\xFF\x00".b
      expect(Fgl.printer_bytes(bytes)).to equal(bytes)
    end
  end

  describe '.resident_text' do
    it 'drops accents' do
      expect(Fgl.resident_text('Zoë Muñoz')).to eq('Zoe Munoz')
    end

    it 'treats nil as empty' do
      expect(Fgl.resident_text(nil)).to eq('')
    end
  end
end
