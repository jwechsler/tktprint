require 'socket'

module Fgl

  FONTS = (
    FONT1, FONT2, OCRB, OCRA, LARGE_OCRB, SMALL_OCRA, COURIER, SMALL_OCRB, PRESTIGE, SCRIPT, ORATOR, SMALL_COURIER,
    COMIC_SANS, COMIC_SANS_BOLD, VERDANA, VERDANA_BOLD, VERDANA_ITALIC, VERDANA_BOLD_ITALIC =
    1,2,3,4,6,7,8,9,10,11,12,13,
    -1, -2, -3, -4, -5, -6
    )

  # Dots the print head images across the ticket (Boca 300 DPI Mini self-test)
  PRINT_WIDTH = 576

  def self.row_column(row,column)
    at(row,column)
  end

  def self.at(row,column)
    "<RC#{row},#{column}>"
  end

  def self.draw_box(height, width, thickness = 3)
    "<LT#{thickness}><BX#{height},#{width}>"
  end

  def self.rotate_right
    "<RR>"
  end

  def self.rotate_left
     "<RL>"
   end

  def self.font_size(font_spec, point_size = 10)
    if font_spec < 0
      "<RTF#{0-font_spec},#{point_size}>"
    else
      "<F#{font_spec}>"
    end
  end

  def self.scale(horizontal, vertical)
    "<HW#{horizontal},#{vertical}>"
  end

  def self.scale_down(factor)
    "<SD#{factor}>"
  end

  def self.print_buffer
    "<p>"
  end

  def self.horizontal_line(width = 2, length = 600)
    "<LT#{width}><HX#{length}>"
  end

  # A rule across the whole print width at `column`. Rows run across the ticket, so in
  # FGL's terms this is a vertical line (<VX>) of PRINT_WIDTH rows; <LT> sets its thickness.
  def self.horizontal_rule(column, thickness = 2)
    row_column(0, column) << "<LT#{thickness}><VX#{PRINT_WIDTH}>"
  end

  def self.invert_text(text)
    "<EI>" << text << "<DI>"
  end

  def self.printing_length(length)
    "<PL#{length}>"
  end

  def self.centered_text(text, size)
    "<CTR#{size}>~#{text}~"
  end

  def self.non_rotated
    "<NR>"
  end

  def self.rotate_180
    "<RU>"
  end

  # Bytes to send for FGL that may hold customer text. TrueType text prints in code
  # page 1252 (the Boca's default <TTCP3>); characters outside it become '?'. Binary
  # strings (already converted, possibly holding bitmaps) pass through unchanged.
  def self.printer_bytes(fgl)
    return fgl if fgl.encoding == Encoding::BINARY

    fgl.encode(Encoding::Windows_1252, invalid: :replace, undef: :replace, replace: '?').b
  end

  # Text for the resident fonts (OCR-A, OCR-B, F1...), which only print ASCII reliably:
  # accents are dropped (Muñoz -> Munoz)
  def self.resident_text(text)
    ActiveSupport::Inflector.transliterate(text.to_s)
  end

  def self.ticket_count
    "<PC>"
  end

  def self.print_stored_image(row, column, image_number)
    "<SP#{row},#{column}><LD#{image_number}>"
  end

  # Prints a BMP file's bytes at (row, column) without storing it on the printer.
  # Returns a binary string; <G n> counts bytes.
  def self.print_inline_bitmap(row, column, data)
    "<SP#{row},#{column}><bmp><G#{data.bytesize}>".b + data.b
  end

  # id: the logo slot to store into (<IDn>); without it the printer picks the slot
  def self.load_logo_file(ip_address, port, filename, id: nil)
    puts "Opening socket..."
    socket = TCPSocket.open(ip_address, port)
    puts "Loading bmp file..."
    # Binary read: <G n> is a byte count, and a UTF-8 string's length is not
    data = File.binread(filename)

    puts "Sending..."
    command = (id ? "<ID#{id}>" : "") + "<SP10,10>" + 27.chr + "<bmp><G#{data.bytesize}>" + data
    command << 27.chr
    slice = 0
    while slice < command.length
      if slice + 4000 < command.length
        send_data = command[slice, 4000]
      else
        send_data = command[slice..-1]
      end
      slice += 4000
      socket.write(send_data)
      sleep(2)
    end
    socket.close
    puts "logo file uploaded"
  end

end