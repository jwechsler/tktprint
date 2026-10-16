# TKTPrint Server

TKTPrint is a Rails API application that accepts JSON requests and manages ticket printing through an asynchronous job queue.

## System Requirements

- Ruby 3.2.2
- SQLite3
- Bundler

## Installation

1. Install dependencies:
```bash
bundle install
```

2. Set up the database:
```bash
bundle exec rails db:setup
```

## Running the Application

The application requires two processes to be running:

### 1. Web Server (Puma)

For development:
```bash
bundle exec rails server
```

For production:
```bash
# Set production environment variables first
export RAILS_ENV=production
export PORT=3000  # Change if needed
export WEB_CONCURRENCY=2  # Number of Puma workers
export RAILS_MAX_THREADS=5  # Threads per worker

# Start the server
bundle exec rails server -e production
```

### 2. Background Job Worker (Delayed Job)

Start the Delayed Job worker:
```bash
bundle exec bin/delayed_job start
```

To stop the worker:
```bash
bundle exec bin/delayed_job stop
```

To restart the worker:
```bash
bundle exec bin/delayed_job restart
```

## Environment Variables

The following environment variables can be configured:

### Puma Configuration
- `PORT`: The port Puma will listen on (default: 3000)
- `WEB_CONCURRENCY`: Number of Puma worker processes (default: 2)
- `RAILS_MAX_THREADS`: Maximum number of threads per worker (default: 5)
- `RAILS_MIN_THREADS`: Minimum number of threads per worker (default: same as max)

## Development

### Docker Development Environment

A Docker-based development environment is available that replicates the production Raspberry Pi setup.

#### Quick Start

```bash
# Start web, worker and (when config/printer.yml sends development to "boca_printer")
# the virtual Boca printer, which renders tickets to PDFs in tmp/printed_tickets/
./start-printer.sh

# View logs for all services
./bin/docker-startup logs

# View logs for a specific service
./bin/docker-startup logs web
./bin/docker-startup logs worker
./bin/docker-startup logs boca_printer

# Access Rails console
./bin/docker-startup console

# Open a shell in the web container
./bin/docker-startup shell

# Run tests
./bin/docker-startup test

# Stop all services
./bin/docker-startup down
```

#### Testing Printer Communication

1. Start the services: `./start-printer.sh`
2. Create a test order:
   ```bash
   curl -X POST http://localhost:3000/orders.json \
     -u dev_user:dev_password \
     -H "Content-Type: application/json" \
     -d '{
       "last_name": "Customer", "first_name": "Test",
       "performance_code": "TS001", "venue": "Theater Two", "theater": "Theater Wit",
       "title": "Test Show", "patron_code": "P1", "remote_id": 1001, "amount": "25.0",
       "performance_date": "2024-12-31", "performance_time": "2000-01-01T19:00:00.000+00:00",
       "flags": ["star", "heart"],
       "line_items_attributes": [{"description": "1 GENERAL", "amount": "25.0"}],
       "payments_attributes": [{"description": "MC ****4648::AUTH 123", "amount": "25.0"}],
       "tickets_attributes": [{"ticket_class": "GENERAL", "seat": ""}]
     }'
   ```
   Then print it with `curl -X POST -u dev_user:dev_password http://localhost:3000/orders/<id>/print.json`.
   `flags` is optional; see "Receipt flags" in CLAUDE.md.
3. Open the newest PDF in `tmp/printed_tickets/` (`index.jsonl` lists any rendering warnings)

The Docker environment includes:
- Rails web server (Puma) on port 3000
- Delayed Job worker for background processing
- A virtual Boca printer ([fgl-pdf](https://github.com/jwechsler/fgl-pdf)) on port 9100 that renders
  each ticket and receipt to a PDF; see "Virtual Boca printer" in CLAUDE.md
- Automatic configuration file setup

## Monitoring

To check the status of your processes:

1. Puma server:
```bash
ps aux | grep puma
```

2. Delayed Job worker:
```bash
ps aux | grep delayed_job
```

## Logs

- Web server logs: `log/production.log` or `log/development.log`
- Delayed Job logs: `log/delayed_job.log`
