# config/initializers/printer_logo_loader.rb
#
# This initializer loads the printer logo on application startup.
# CRITICAL: Logo must be fully loaded before any print jobs can run,
# as the printer cannot accept simultaneous network packets.
#
# This runs SYNCHRONOUSLY to block application initialization until complete.

Rails.application.config.after_initialize do
  # Skip in test environment
  next if Rails.env.test?

  begin
    Rails.logger.info("=== Printer Logo Loader: Starting ===")

    # Check if printer configuration is available
    unless defined?($PRINTER) && $PRINTER && $PRINTER[0]
      Rails.logger.warn("Printer configuration not available - skipping logo load")
      # No need to unblock - printing is allowed by default
      next
    end

    printer_config = $PRINTER[0]
    address = printer_config['address']
    port = printer_config['port']
    logo_path = printer_config['logo']

    # Validate configuration
    if address.blank? || port.blank?
      Rails.logger.warn("Printer address or port not configured - skipping logo load")
      next
    end

    if logo_path.blank?
      Rails.logger.warn("Logo path not configured in printer.yml - skipping logo load")
      next
    end

    # Resolve logo file path
    logo_file = Rails.root.join(logo_path)

    unless File.exist?(logo_file)
      Rails.logger.warn("Logo file not found at #{logo_file} - skipping logo load")
      next
    end

    # Test mode: skip actual loading
    if address == 'localhost'
      Rails.logger.info("Printer in test mode (localhost) - skipping logo upload")
      next
    end

    # BLOCK PRINTING while we load the logo
    Printer.block_printing_for_logo_load!

    # Load logo into printer
    Rails.logger.info("Loading logo from #{logo_file} to printer at #{address}:#{port}")

    begin
      # Tickets recall the logo as <LD1>, so store it in slot 1 explicitly
      Fgl.load_logo_file(address, port, logo_file.to_s, id: 1)
      Rails.logger.info("=== Printer Logo Loader: SUCCESS ===")
    rescue => e
      Rails.logger.error("Failed to load logo into printer: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      Rails.logger.warn("Allowing printing to proceed despite logo load error")
    ensure
      # ALWAYS unblock printing after logo load completes (success or failure)
      Printer.unblock_printing!
    end

  rescue => e
    Rails.logger.error("Error in printer logo loader: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Ensure printing is unblocked even if there's an error
    Printer.unblock_printing!
  end
end
