# TKTPrint Docker Environment

This Docker setup provides a development and testing environment that closely replicates the production Raspberry Pi environment.

## Quick Start

```bash
# Initialize and start all services
./bin/docker-dev up

# View logs
./bin/docker-dev logs

# Access Rails console
./bin/docker-dev console

# Stop services
./bin/docker-dev down
```

## Architecture

The Docker environment consists of:

1. **Web Service** - Rails application server (Puma)
2. **Worker Service** - Delayed Job background processor
3. **Printer Emulator** - TCP socket listener that simulates a thermal printer
4. **DB Setup** - One-time database initialization

## Configuration

Configuration files are automatically created on first run:
- `config/authorization.yml` - API authentication credentials
- `config/printer.yml` - Printer connection settings

In Docker, the printer address is set to `printer_emulator` which routes to the emulated printer service.

## Testing Printer Communication

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
3. Check printer emulator logs: `./bin/docker-dev logs printer_emulator`

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

- **Services not starting**: Check logs with `./bin/docker-dev logs`
- **Database errors**: Run `docker-compose exec web bundle exec rails db:migrate`
- **Permission errors**: Ensure files are owned by user ID 1000 (default appuser)
- **Printer not receiving**: Check printer_emulator is running on port 9100