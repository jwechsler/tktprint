# TKTPrint Docker Environment

This Docker setup provides a development and testing environment that closely replicates the production Raspberry Pi environment.

## Quick Start

```bash
# Start web and worker; also the virtual Boca printer when config/printer.yml sends this
# RAILS_ENV to "boca_printer" (tickets render to PDFs)
./start-printer.sh

# View logs (web, worker or boca_printer)
./bin/docker-startup logs [service]

# Access Rails console
./bin/docker-startup console

# Stop services
./bin/docker-startup down
```

## Architecture

The Docker environment consists of:

1. **Web Service** - Rails application server (Puma)
2. **Worker Service** - Delayed Job background processor
3. **Virtual Boca printer** (`boca_printer`, profile `virtual-printer`) - [fgl-pdf](https://github.com/jwechsler/fgl-pdf)
   listening on port 9100 like a real Boca; every ticket and receipt is rendered to
   `tmp/printed_tickets/NNNNNN.pdf`
4. **DB Setup** - One-time database initialization

## Configuration

- `config/authorization.yml` - API authentication credentials (created by `docker/init.sh` if missing)
- `config/printer.yml` - This machine's printer, keyed by `RAILS_ENV` (gitignored; created from
  `config/printer.yml.example` on first run). A development machine sends `development` to
  `boca_printer`; the box office machine points every section at the real Boca.

## Testing Printer Communication

1. Start the services: `./start-printer.sh` (with `development` → `boca_printer` in `config/printer.yml`)
2. Send an order and print it. The curl example is in `doc/README.md` ("Testing Printer Communication").
3. Open the newest PDF in `tmp/printed_tickets/`. `index.jsonl` lists each ticket with any rendering warnings.

See "Virtual Boca printer" in `CLAUDE.md` for the knobs (debug grid, annotations, fonts).

## Production Deployment

For production on Raspberry Pi:

1. Build production image:
   ```bash
   docker build -t tktprint:production .
   ```

2. Create production config files with real printer IP

3. Run with production compose file:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

## Troubleshooting

- **Services not starting**: Check logs with `./bin/docker-startup logs`
- **Database errors**: Run `docker-compose exec web bundle exec rails db:migrate`
- **Permission errors**: Ensure files are owned by user ID 1000 (default appuser)
- **No PDFs**: Check `config/printer.yml` sends your `RAILS_ENV` to `address: "boca_printer"`,
  then rerun `./start-printer.sh` and confirm `boca_printer` is running (`docker compose ps`)
