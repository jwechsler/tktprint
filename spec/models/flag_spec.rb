require 'rails_helper'

RSpec.describe Flag do
  it 'loads every icon named in config/flags.yml' do
    expect(Flag.all.map(&:name)).to contain_exactly('flag', 'star', 'ticket', 'heart', 'checkmark')
  end

  it 'holds each icon as BMP bytes' do
    expect(Flag.find('star').bitmap).to start_with('BM'.b)
  end

  it 'returns nil for a name not in the registry' do
    expect(Flag.find('unicorn')).to be_nil
  end

  it 'refuses a registry whose icon file is missing' do
    Tempfile.create(['flags', '.yml']) do |registry|
      registry.write({ 'ghost' => { 'icon' => 'config/flag_icons/ghost.bmp' } }.to_yaml)
      registry.flush
      expect { Flag.load_registry(registry.path) }.to raise_error(ArgumentError, /missing icon files .*ghost\.bmp/)
    end
  end
end
