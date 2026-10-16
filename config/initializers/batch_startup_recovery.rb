# config/initializers/batch_startup_recovery.rb
#
# Resumes any batches that were interrupted by a service restart, so they aren't orphaned
# in 'ready' or 'processing' status. The work is in BatchStartupRecovery (app/models).

Rails.application.config.after_initialize do
  BatchStartupRecovery.start_in_background unless Rails.env.test?
end
