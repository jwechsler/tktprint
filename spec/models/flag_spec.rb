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
    registry = Rails.root.join('tmp/flags_missing_icon.yml')
    File.write(registry, { 'ghost' => { 'icon' => 'config/flag_icons/ghost.bmp' } }.to_yaml)
    expect { Flag.load_registry(registry) }.to raise_error(ArgumentError, /missing icon files .*ghost\.bmp/)
  ensure
    File.delete(registry) if File.exist?(registry)
  end
end
