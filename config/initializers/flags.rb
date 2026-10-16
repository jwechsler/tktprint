# Load and check the receipt flag registry at boot, so a bad config/flags.yml stops startup
Rails.application.config.after_initialize do
  Flag.all
end
