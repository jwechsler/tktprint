# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

**Environment Setup:**
- Ruby version: 3.2.2
- Rails version: 6.1.7
- Install dependencies: `bundle install`

**Starting the Application (requires TWO processes):**
1. Web server: `bundle exec rails server`
2. Background job worker: `bundle exec bin/delayed_job start`

**Production Mode:**
```bash
export RAILS_ENV=production
export PORT=3000
export WEB_CONCURRENCY=2
export RAILS_MAX_THREADS=5
bundle exec rails server -e production
bundle exec bin/delayed_job start
```

**Background Worker Management:**
- Stop: `bundle exec bin/delayed_job stop`
- Restart: `bundle exec bin/delayed_job restart`
- Status check: `ps aux | grep delayed_job`

**Database Commands:**
- Initial setup: `bundle exec rails db:setup`
- Create and migrate: `bundle exec rails db:create db:migrate`
- Rails console: `bundle exec rails console`

**Testing:**
- Run all specs: `bundle exec rspec`
- Run one spec file: `bundle exec rspec spec/models/order_spec.rb`
- Specs set `$PRINTER` to `localhost` (see `spec/rails_helper.rb`), so nothing is sent to a printer.

**Virtual Boca printer (docker test mode):**
- `./start-printer.sh -m test` starts the `boca_printer` service (profile `test`), built from
  [fgl-pdf](https://github.com/jwechsler/fgl-pdf). It listens on port 9100 like a real Boca;
  `config/printer.yml.test` points the app at it (`address: "boca_printer"`).
- Every ticket and receipt the app prints is rendered to `tmp/printed_tickets/NNNNNN.pdf`
  (sequential), with the raw FGL in `NNNNNN.fgl` and one JSON line per ticket in
  `tmp/printed_tickets/index.jsonl` (time, connection, rendering warnings).
- The logo the app uploads at boot is kept in `tmp/printed_tickets/.printer/logos/`.
- To start over, stop the services and delete `tmp/printed_tickets/`; numbering restarts at 000001.
- Knobs (shell or `.env`; `start-printer.sh` keeps `FGL_PDF_REF` and `BOCA_FONT_DIR` when it
  rewrites `.env`): `FGL_PDF_REF` (git ref of fgl-pdf to build, default `main`),
  `FGL_PDF_ANNOTATE=true` (print rendering warnings on each PDF), `FGL_PDF_DEBUG_GRID=true`
  (50-dot grid overlay), `FGL_PDF_LENGTH_IN` (ticket length, default 5.5),
  `FGL_PDF_FEED_DPI` (dots per inch along the ticket, default 307.1: the Boca 300 DPI Mini's
  self-test reports PRINT LENGTH=1689 on the 2" x 5.5" stock, so the stub name at column 1665
  prints in full), `FGL_PDF_PRINT_WIDTH` (rows the head images, default 576 from the self-test;
  rows past it are tinted gray in the PDF and anything reaching them is warned about),
  `BOCA_PRINTER_PORT` (host port on 127.0.0.1, default 9100).
- Fonts: tktprint's `<RTF3..6>` text is Verdana. Without it the printer uses DejaVu Sans
  (slightly wider). Put Verdana files in `tmp/fonts/` or set `BOCA_FONT_DIR` to a folder
  holding them; Windows, macOS and msttcorefonts file names all work. On macOS, copy them:
  `cp /System/Library/Fonts/Supplemental/Verdana*.ttf tmp/fonts/` (Docker Desktop can't
  mount `/System`). `docker compose logs boca_printer` shows the mapping
  (`TrueType fonts: RTF3=Verdana.ttf ...`). Never commit the font files.
- Send raw FGL by hand: `printf '<RC10,10><F3>HELLO<p>' | nc localhost 9100`.
- `MOCK_PRINTING` and the `PRINT_*` variables in docker-compose.yml are not read by the app.

**Monitoring:**
- Server logs: `tail -f log/development.log` or `log/production.log`
- Job worker logs: `tail -f log/delayed_job.log`

## Architecture Overview

**Core Function:**
TKTPrint is a Rails 6.1 API-only application that receives JSON order data and prints physical theater tickets via TCP socket connection to thermal printers using FGL (Form Generation Language) commands.

**Critical Components:**

1. **Order Processing Flow:**
   - JSON API receives order at `POST /orders` or `PUT /orders/:id`
   - Orders with status "Unprinted" automatically queue print job via `send_to_printer` callback
   - Delayed Job processes print queue with 1-second delay to batch updates
   - Status changes to "Printed" after successful printing

2. **Printer System (`app/models/printer.rb`):**
   - TCP socket communication on port 9100 (standard printer port)
   - FGL module (`app/models/fgl.rb`) generates printer-specific commands
   - Prints both tickets (with barcodes, logos) and receipts
   - **Test Mode:** Set `address: "localhost"` in printer.yml to skip actual printing,
     or `address: "boca_printer"` to print to the virtual printer as PDFs (see above)

3. **Data Model Relationships:**
   ```
   Order (has_many)
   ├── LineItem (belongs_to Order)
   ├── Payment (belongs_to Order)
   └── Ticket (belongs_to Order, optional seat assignment)
   ```

4. **Authentication System:**
   - HTTP Basic Auth required for all endpoints
   - Token endpoint: `GET /token` returns auth token
   - Credentials stored in `config/authorization.yml`

5. **API Endpoints:**
   - `GET /orders` - List all orders (HTML view)
   - `POST /orders` - Create order (auto-prints)
   - `GET /orders/:id` - Show order JSON
   - `PUT /orders/:id` - Update order (auto-prints if "Unprinted")
   - `POST /orders/:id/print` - Force reprint
   - `GET /orders/:id/find_by_remote` - Find by remote_id
   - `GET /tickets?order_id=:id` - List order's tickets
   - `PUT /tickets/:id` - Update ticket (e.g., seat)

**Required Configuration Files:**
1. Create `config/authorization.yml` from `.example`:
   ```yaml
   development:
     username: "dev_user"
     password: "dev_password"
   ```

2. Create `config/printer.yml` from `.example`:
   ```yaml
   development:
     ticket_printer_1:
       address: "localhost"  # Use real IP for production
       port: 9100
   ```

**Key Implementation Details:**
- All text inputs sanitized (HTML tags stripped) via `strip_tags` concern
- Duplicate printing prevented via status tracking and job deduplication
- Printer initialization script at `script/initialize_printer` uploads logo
- SQLite3 database with schema at `db/schema.rb`

**Current Development Context:**
- Branch: `ruby3` (upgrading from older Ruby/Rails versions)
- Main branch: `master`
- Recent work: Rails 6.1 upgrade, removed asset pipeline, converted to API-only