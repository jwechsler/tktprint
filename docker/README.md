# TKTPrint Docker Environment

This Docker setup provides a development and testing environment that closely replicates the production Raspberry Pi environment.

## Quick Start

```bash
# Start web, worker and the virtual Boca printer (tickets render to PDFs)
./start-printer.sh -m test

# Start web and worker against the real printer (config/printer.yml.live)
./start-printer.sh -m live

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
3. **Virtual Boca printer** (`boca_printer`, test mode only) - [fgl-pdf](https://github.com/jwechsler/fgl-pdf)
   listening on port 9100 like a real Boca; every ticket and receipt is rendered to
   `tmp/printed_tickets/NNNNNN.pdf`
4. **DB Setup** - One-time database initialization

## Configuration

- `config/authorization.yml` - API authentication credentials (created by `docker/init.sh` if missing)
- `config/printer.yml` - Printer connection settings. `start-printer.sh -m MODE` copies
  `config/printer.yml.MODE` into place: `config/printer.yml.test` (address `boca_printer`) is in git;
  `config/printer.yml.live` holds the real printer's address and is created on the production machine.

## Testing Printer Communication

1. Start the services: `./start-printer.sh -m test`
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
- **Nothing printed in test mode**: Check `boca_printer` is running (`docker compose ps`) and that
  `config/printer.yml` has `address: "boca_printer"`
