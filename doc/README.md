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
# Initialize and start all services (web, worker, database, printer emulator)
./bin/docker-dev up

# View logs for all services
./bin/docker-dev logs

# View logs for a specific service
./bin/docker-dev logs web
./bin/docker-dev logs worker
./bin/docker-dev logs printer_emulator

# Access Rails console
./bin/docker-dev console

# Open a shell in the web container
./bin/docker-dev shell

# Run tests
./bin/docker-dev test

# Stop all services
./bin/docker-dev down
```

#### Testing Printer Communication

1. Start the services: `./bin/docker-dev up`
2. Create a test order:
   ```bash
   curl -X POST http://localhost:3000/orders \
     -u dev_user:dev_password \
     -H "Content-Type: application/json" \
     -d '{
       "order": {
         "remote_id": "TEST001",
         "status": "Unprinted",
         "customer_name": "Test Customer",
         "performance_name": "Test Show",
         "performance_date": "2024-12-31",
         "tickets": [
           {
             "barcode": "123456789",
             "price": 25.00
           }
         ]
       }
     }'
   ```
3. Check printer emulator output: `./bin/docker-dev logs printer_emulator`

The Docker environment includes:
- Rails web server (Puma) on port 3000
- Delayed Job worker for background processing
- Printer emulator on port 9100 that logs all received print jobs
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
