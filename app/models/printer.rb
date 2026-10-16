require 'socket'

class Printer
  attr_accessor :tickets

  # Class-level synchronization for logo loading
  # Use inverted logic: flag blocks printing ONLY while logo is loading
  @@logo_loading_in_progress = false

  def self.logo_loaded?
    !@@logo_loading_in_progress
  end

  def self.block_printing_for_logo_load!
    @@logo_loading_in_progress = true
    Rails.logger.info("Blocking print operations while logo loads")
  end

  def self.unblock_printing!
    @@logo_loading_in_progress = false
    Rails.logger.info("Print operations now enabled - logo loading complete")
  end

  def initialize(ip_address = nil, port = nil)
    @address = ip_address || $PRINTER[0]['address']
    @port = port || $PRINTER[0]['port']
    self.tickets = Array.new
    @buffer = ''
  end


  def queue(command)
    @buffer += command
  end

  def flush(socket)
    return if @address == 'localhost'  # Skip flush for localhost (testing)
    slice = 0
    while slice < @buffer.length
      allow_flush = (slice + 256 < @buffer.length)
      if allow_flush
        send_data = @buffer[slice..slice+255]
      else
        send_data = @buffer[slice..-1]
      end
      slice += 256
      socket.write(send_data)
      sleep(0.3)
    end
    @buffer = ''
  end

  def connect
    return if @address == 'localhost'  # Skip connection for localhost (testing)
    @socket = TCPSocket.open(@address, @port)
  end

  def close
    return if @address == 'localhost'  # Skip close for localhost (testing)
    @socket.close unless @socket.closed?
  end

  def status
    return "Test mode (localhost)" if @address == 'localhost'  # Return test status for localhost
    @socket.write("<s1>")
    str = @socket.recv(128)
    status_response = case str[0]
                        when 1..4
                          ''
                        when 5
                          'Test button ACK'
                        when 6
                          "Ticket ACK"
                        when 7
                          status_response = "Wrong File Identifier During Update"
                        when 8
                          "Invalid Checksum"
                        when 9
                          "Valid Checksum"
                        when 10
                          "Out Of Paper Path 1"
                        when 11
                          "Out Of Paper Path 2"
                        when 12..15
                          ''
                        when 16
                          "Out of Tickets"
                        when 17
                          "X-On"
                        when 18
                          "Power On"
                        when 19
                          "X-Off"
                        when 20
                          "Bad Flash Memory"
                        when 21
                          "Ticket NAK"
                        when 22
                          "Ribbon Low"
                        when 23
                          "Ribbon Out"
                        when 24
                          "Ticket Jam"
                        when 25..26
                          ""
                        when 27
                          "Escape"
                        when 28
                          "Downloading Error"
                        when 29
                          "Cutter Jam"
                        else
                          msg = ''
                          str.each { |s| msg << chr(s) }
                          msg
                      end
    status_response
  end


  def print_order(order)
    result = false

    # Guard: Ensure logo is loaded before attempting to print
    unless Printer.logo_loaded?
      Rails.logger.error("Cannot print order #{order.id} - printer logo not yet loaded")
      return false
    end

    # Test mode (localhost): build nothing, open no socket
    return true if @address == 'localhost'

    unless @address.blank?
      TCPSocket.open(@address, @port) do |socket|
        @socket = socket
           order.tickets.each { |ticket| self.print_ticket(ticket) }
        self.print_receipt (order)
        self.flush(socket)
        sleep(1.75)
      end
    end
  end

  def truncated_name(first_name, last_name, s_len=20)
    name = last_name.blank? ? "" : last_name.upcase
    name << ', ' + first_name.upcase unless first_name.blank?
    name[0..(s_len-1)]
  end

  # Characters per stub line: the name line's width (OCR-A at 4x is 28 dots per character)
  STUB_LINE_CHARS = 20

  # Performance code flush left, day and time (no AM/PM) flush right, on the same grid as
  # the name above. The code is never cut; to make room the day and time shorten step by
  # step: SAT 10:30, SA 10:30, SA 1030, SA1030, 1030 (the last is used even if too long).
  def stub_performance_line(order)
    code = order.performance_code.to_s
    time = order.performance_time.strftime('%l:%M').strip
    day = order.performance_date.strftime('%a').upcase
    compact = time.delete(':')
    choices = ["#{day} #{time}", "#{day[0, 2]} #{time}", "#{day[0, 2]} #{compact}", "#{day[0, 2]}#{compact}",
               compact]
    day_time = choices.find { |c| code.length + 1 + c.length <= STUB_LINE_CHARS } || choices.last
    code.ljust(STUB_LINE_CHARS - day_time.length - 1) + ' ' + day_time
  end

  def stub(order, class_code = nil, receipt=false)
    fgl = Fgl::at(10, 1665) + Fgl::rotate_right + Fgl::font_size(Fgl::OCRA) + Fgl::scale(4, 4) + truncated_name(order.first_name, order.last_name)
        fgl << Fgl::at(10, 1615) + stub_performance_line(order)
        fgl << Fgl::at(10, 1570) + Fgl::scale(3, 3) + ('%010d' % order.remote_id)
        fgl << Fgl::at(10, 1536) + Fgl::scale(3, 3) + order.patron_code
        fgl << ' ' + class_code unless class_code.nil?
        if receipt
          warntext = "RECEIPT"
        elsif (order.reprint_count || 0) > 0
          warntext = "REPRINT"
        end
        unless warntext.blank?
          fgl << Fgl::at(10,1490) + Fgl::scale(1,1) + Fgl::font_size(Fgl::VERDANA_BOLD, 14) + Fgl::centered_text(warntext,530)
        end

    fgl
  end

  # @param order [Object]
  def print_receipt(order)
    Rails.logger.debug(order.to_yaml)
    #Receipts are vertically oriented, and we're printing them upside down for consistency
    fgl = self.stub(order,nil,true)

    y = 1400
    line_height = 50

    fgl << Fgl::at(10, y) + Fgl::scale(1, 1) + Fgl::font_size(Fgl::VERDANA_BOLD, 10) + "ORDER ##{order.remote_id}"
    fgl << Fgl::at(10, (y -= line_height)) + truncated_name(order.first_name, order.last_name, 17)
    fgl << Fgl::at(10, (y -= line_height*2)) + Fgl::font_size(Fgl::VERDANA, 10) + "Tickets for"
    fgl << Fgl::at(10, (y -= line_height)) + Fgl::font_size(Fgl::VERDANA_ITALIC, 10) + order.title + Fgl::font_size(Fgl::VERDANA, 10)
    fgl << Fgl::at(10, (y -= line_height)) + order.performance_date.strftime("%D") + ' ' + order.performance_time.strftime("%l:%M %p")
    y -= line_height*2
    fgl << Fgl::font_size(Fgl::VERDANA, 8)
    order.line_items.each do |li|
      fgl << Fgl::at(10, y) + ("%-60s" % li.description.upcase) << Fgl::at(380, y) + '$' + ('%6.2f' % li.amount.to_s)
      y -= line_height
    end

    fgl << Fgl::font_size(Fgl::VERDANA_BOLD, 8)
    order.payments.each do |p|
      # Build payment description from payment_type and transaction_id
      payment_desc = "#{p.payment_type}::#{p.transaction_id}"
      lines = payment_desc.split('::')
      int_y = y
      lines.each { |line|
        # Truncate each line to 30 characters
        truncated_line = line[0..29]
        fgl << Fgl::at(10, int_y) + ("%-60s" % truncated_line)
        int_y -= line_height
      }
      fgl << Fgl::at(380, y) + Fgl::font_size(Fgl::VERDANA_BOLD, 8) + '$' + ('%6.2f' % p.amount.to_s)
      y = int_y
    end
    y = 200 if y > 200
    fgl << Fgl::at(10,y) + Fgl::font_size(Fgl::FONT1) + Fgl::scale(2, 2) + "All sales final."
    fgl << Fgl::at(10,y-30) + "No refunds or exchanges" + Fgl::scale(1, 1)
    fgl << Fgl::horizontal_rule(110, 5) + Fgl::at(10, 100) + Fgl::font_size(Fgl::VERDANA_BOLD, 16) + "RECEIPT ONLY"

    fgl << Fgl::print_buffer
    self.queue(fgl)

    #self.status
  end

  def print_ticket(ticket)
    # setup venue
    venue = ticket.order.venue
    venue = venue[0..11] if ticket.order.venue.length > 13

    fgl = Fgl::horizontal_rule(10, 5) + Fgl::at(550, 20) + Fgl::rotate_left + Fgl::font_size(Fgl::VERDANA_BOLD, 16) + Fgl::centered_text(venue, 530) + Fgl::horizontal_rule(120, 5)
    # Put the show date at the top

    date_str = ticket.order.performance_date.strftime('%A %B %e, %G') + ' ' + ticket.order.performance_time.strftime('%l:%M %p').strip
    #date_str = "1234567890123456789012345678901234567890"
    date_str = date_str[0..36] if date_str.length > 37
    margin = (37-date_str.length) / 2.0
    pixels = 30*margin
    seat_text = ticket.seat.blank? ? "GENERAL ADMISSION - ADMIT ONE" : "RESERVED SEATING: #{ticket.seat}"

    fgl << Fgl::non_rotated +  Fgl::row_column(10, 140+pixels) + Fgl::font_size(Fgl::OCRB) + date_str
    unless ticket.seat.blank?
      fgl << Fgl::row_column(0, 1146) + Fgl::font_size(Fgl::VERDANA_BOLD_ITALIC, 18) + ticket.seat
    end

    # Create the title and credit box
    box_width = 800
    max_verdana_title_chars_per_line = 18
    fgl << Fgl::at(80, 140) + Fgl::draw_box(400, box_width)

    # Fill it with title data

    theater = ticket.order.theater + " presents"

    title_words = ticket.order.title.split
    title = ''
    title2 = ''
    one_title_line = true
    width=0
    title_words.each do |word|
      width += word.length + 1
      if one_title_line && width > max_verdana_title_chars_per_line
        one_title_line = false
        width = word.length + 1
      elsif width > max_verdana_title_chars_per_line
        break
      end
      if one_title_line
        title += word + ' '
      else
        title2 += word + ' '
      end
    end

    title = title[0..-2]
    title2 = title2[0..-2] unless title2.blank?
    total_height = 56 + 86
    total_height += 86 unless title2.blank?
    total_height += 10
    total_height += 56 unless ticket.order.credit_1.blank?
    total_height += 56 unless ticket.order.credit_2.blank?

    current_height = 96 + ((350-total_height)/2)

    fgl << Fgl::at(current_height, 145) + Fgl::font_size(Fgl::VERDANA_ITALIC, 8) + Fgl::centered_text(theater, box_width)
    current_height += 56
    fgl << Fgl::at(current_height, 145) + Fgl::font_size(Fgl::VERDANA_BOLD_ITALIC, 18) + Fgl::centered_text(title, box_width)
    current_height += 86
    unless title2.blank?
      fgl << Fgl::at(current_height, 145) + Fgl::font_size(Fgl::VERDANA_BOLD_ITALIC, 18) + Fgl::centered_text(title2, box_width)
      current_height += 86
    end
    current_height += 10

    unless ticket.order.credit_1.blank?
      fgl << Fgl::at(current_height, 145) + Fgl::font_size(Fgl::VERDANA, 8) + Fgl::centered_text(ticket.order.credit_1, box_width)
      current_height += 56
    end

    unless ticket.order.credit_2.blank?
      fgl << Fgl::at(current_height, 145) + Fgl::font_size(Fgl::VERDANA, 6) + Fgl::centered_text(ticket.order.credit_2, box_width)
      current_height += 46
    end

    # print standard copy
    seat_text = ticket.seat.blank? ? "GENERAL ADMISSION - ADMIT ONE" : "RESERVED SEATING: #{ticket.seat}"
    fgl << Fgl::at(500, 140) + Fgl::font_size(Fgl::VERDANA_BOLD_ITALIC, 9) + Fgl::centered_text(seat_text, box_width)
    fgl << Fgl::at(555, 220) + Fgl::font_size(Fgl::FONT1) + Fgl::scale(2, 2) + "All sales final. No refunds or exchanges" + Fgl::scale(1, 1)
    fgl << Fgl::at(390, 190+box_width) + Fgl::font_size(Fgl::VERDANA, 6) << "1229 W Belmont"
    fgl << Fgl::at(414, 190+box_width) + "www.theaterwit.org"
    fgl << Fgl::at(442, 190+box_width) + "773-975-8150"
    fgl << Fgl::print_stored_image(90, 185 + box_width, 1)
    # print tracking code

    ticket_track = ticket.order.patron_code + DateTime.now.strftime('%g%m%d %H%M%S ') + ('%08d' % ticket.order.id.to_s) + Fgl::ticket_count
    fgl << Fgl::at(520, 980) + Fgl::font_size(Fgl::OCRB) + ticket.order.performance_code + ' ' + ticket.ticket_class
    fgl << Fgl::at(555, 980) + Fgl::font_size(Fgl::OCRA) + ticket.order.remote_id.to_s + ':' + ticket_track

    fgl << self.stub(ticket.order, ticket.ticket_class)
    fgl << Fgl::at(10, 1496) + Fgl::font_size(Fgl::OCRA) + Fgl::scale(2, 2) + ticket_track
    fgl << Fgl::scale(1,1)
    fgl << Fgl::print_buffer
    # puts fgl
    self.queue(fgl)

    #self.status
  end

  def print_test
    self.connect
    @socket.write("<s1>")
    str = ''
    while true
      partial = @socket.recv(1)
      if partial.length == 0
        break
      end
      str << partial
    end
    @socket.close
    str
  end

end
