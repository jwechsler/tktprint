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
  end
end
