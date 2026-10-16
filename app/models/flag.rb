# A receipt flag: a named icon whose 1-bit BMP is printed inline on the receipt.
# The registry is config/flags.yml; see that file for how names are chosen.
class Flag
  REGISTRY_PATH = Rails.root.join('config/flags.yml')

  attr_reader :name, :icon_path, :bitmap

  def initialize(name, icon_path)
    @name = name
    @icon_path = icon_path
    @bitmap = File.binread(icon_path)
  end

  def self.all
    @all ||= load_registry(REGISTRY_PATH)
  end

  def self.find(name)
    all.find { |flag| flag.name == name }
  end

  def self.load_registry(path)
    entries = YAML.safe_load(File.read(path)) || {}
    icon_paths = entries.to_h { |name, attrs| [name.to_s, Rails.root.join(attrs.fetch('icon')).to_s] }
    missing = icon_paths.values.reject { |icon_path| File.exist?(icon_path) }
    raise ArgumentError, "#{path}: missing icon files #{missing.join(', ')}" if missing.any?

    icon_paths.map { |name, icon_path| new(name, icon_path) }
  end
end
