# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

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

**Testing:**
- Specs set `$PRINTER` to `localhost` (see `spec/rails_helper.rb`), so nothing is sent to a printer.

**Printer per machine (`config/printer.yml`):**
- Each machine has its own gitignored `config/printer.yml`, keyed by `RAILS_ENV`, from
  `config/printer.yml.example` (`start-printer.sh` creates it on first run). The app reads the
  `RAILS_ENV` section, else `production`; a flat file (`ticket_printer_1:` at top level) still
  works for every environment.
- Development machine: `development` → `"boca_printer"` (PDFs). Box office machine: every section
  → the real Boca (`192.168.0.209`), so it prints real tickets whatever `RAILS_ENV` it runs.
  To test-print on the real Boca from a development machine, point `development` at its IP.
- `./start-printer.sh` starts web and worker, plus the virtual Boca when the current
  `RAILS_ENV`'s address is `"boca_printer"`. There are no modes or `printer.yml.*` copies.

**Virtual Boca printer:**
- `boca_printer` (built from fgl-pdf) renders tickets to `tmp/printed_tickets/` as PDFs. Knobs, font setup and
  raw-FGL testing are in the `virtual-boca-printer` skill (`.claude/skills/virtual-boca-printer/SKILL.md`).
- Never commit the font files.

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
   - **Where tickets go:** `config/printer.yml` (see "Printer per machine" above).
     `address: "localhost"` skips printing; `"boca_printer"` prints PDFs.

3. **Authentication System:**
   - HTTP Basic Auth required for all endpoints
   - Token endpoint: `GET /token` returns auth token
   - Credentials stored in `config/authorization.yml`

**Required Configuration Files:**
1. Create `config/authorization.yml` from `.example`:
   ```yaml
   development:
     username: "dev_user"
     password: "dev_password"
   ```

2. Create `config/printer.yml` from `config/printer.yml.example` (`start-printer.sh` does this
   on first run) and set this machine's printer address for each environment.

**Receipt flags:**
- Orders take an optional `flags` array of icon names (`POST /orders`, `PUT /orders/:id/reprint`;
  on reprint, omitting `flags` keeps the old ones and `[]` clears them). Stored comma-separated in
  `orders.flags`; `Order#flag_names` returns the array and `as_json` emits it as an array.
- Names come from `config/flags.yml` (`flag`, `star`, `ticket`, `heart`, `checkmark`), each a 48x48
  1-bit BMP in `config/flag_icons/` built by `script/build_flag_icons` (ImageMagick shapes).
  tktprint knows no business meaning; stagemgr decides what each icon stands for.
- `Printer#receipt_fgl` prints up to `MAX_RECEIPT_FLAGS` (3) icons right of the RECEIPT banner,
  sent inline (`<SPr,c><bmp><G n>` + bytes) with that receipt only, so a printer restart can't
  lose them. Unknown and extra names are logged and skipped. Tickets never show flags.
- Receipt FGL is a binary string (`Printer#queue` keeps the buffer binary) because icon bytes
  can't be joined to non-ASCII UTF-8 text.
- The theater logo is stored in slot 1 (`<ID1>`) at boot and recalled as `<LD1>`.

**Key Implementation Details:**
- All text inputs sanitized (HTML tags stripped) via `strip_tags` concern
- Duplicate printing prevented via status tracking and job deduplication
- Printer initialization script at `script/initialize_printer` uploads logo
- SQLite3 database with schema at `db/schema.rb`
