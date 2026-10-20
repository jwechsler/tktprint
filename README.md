# TKTPrint

A Rails 6.1 API-only application that receives JSON order data and prints physical theater tickets on a Boca thermal printer using FGL (Form Generation Language) commands.

## Requirements

- Docker and Docker Compose (V2)
- Ruby 3.2.2 / Rails 6.1.7 (handled by the Docker image)

## Setup

### 1. Clone the repository

```bash
git clone <repo-url> && cd tktprint
```

### 2. Create configuration files

Three files are needed that are not checked into the repository:

**`config/authorization.yml`** — API credentials (HTTP Basic Auth). Copy the example and set your own username and password:

```bash
cp config/authorization.yml.example config/authorization.yml
```

```yaml
production:
  username: "your_username"
  password: "your_password"

development:
  username: "dev_user"
  password: "dev_password"

test:
  username: "test_user"
  password: "test_password"
```

**`config/printer.yml`** — printer address per environment. `start-printer.sh` copies the example on first run, but you can do it yourself:

```bash
cp config/printer.yml.example config/printer.yml
```

Edit it for this machine:

- **Development machine:** leave `development` pointing at `"boca_printer"` (the virtual printer renders PDFs to `tmp/printed_tickets/`).
- **Box-office / production machine:** set every section's address to the real Boca's IP (e.g. `192.168.0.209`).

```yaml
development:
  ticket_printer_1:
    address: "boca_printer"
    port: 9100
    logo: "public/logo.bmp"

production:
  ticket_printer_1:
    address: "192.168.0.209"   # the real Boca's IP
    port: 9100
    logo: "public/logo.bmp"
```

**`public/logo.bmp`** — the theater logo printed on every ticket. The app uploads it to the printer's memory (slot 1) at boot. Place your own 1-bit BMP logo here. Without this file the printer initializer skips the upload and **tickets print without a logo**.

### 3. Start the application

```bash
./start-printer.sh
```

This script:
- Creates `config/printer.yml` from the example if it doesn't exist yet
- Generates a `SECRET_KEY_BASE` and writes `.env` for Docker Compose
- Builds and starts the Docker containers (web server, background worker, database migration)
- Starts the virtual Boca printer when the current environment's address is `"boca_printer"`

By default it runs in the background. Use `-f` for foreground mode:

```bash
./start-printer.sh -f
```

The web server takes ~30-40 seconds to boot in production mode (it loads the logo into the printer during startup). This is normal.

### 4. Verify it's running

```bash
# Container status
docker compose ps

# Test the API (use your credentials from authorization.yml)
curl -u username:password http://localhost:3000/orders.json
```

## Environment

`RAILS_ENV` controls which section of `printer.yml` and `authorization.yml` the app reads. It defaults to `development` if unset:

```bash
# Production (for the box-office machine)
export RAILS_ENV=production
./start-printer.sh
```

## Logs

```bash
./show-tktprint-logs.sh -f          # Web server logs
docker compose logs -f worker       # Background worker logs
docker compose logs -f boca_printer # Virtual printer logs (dev only)
```

## Testing

```bash
bundle exec rspec                              # All specs
bundle exec rspec spec/models/order_spec.rb    # One file
```

Specs set the printer address to `localhost`, so nothing is sent to a real printer.

## Virtual Boca Printer (development)

When `config/printer.yml` points the current environment at `"boca_printer"`, `start-printer.sh` starts the [fgl-pdf](https://github.com/jwechsler/fgl-pdf) virtual printer alongside the app. It listens on port 9100 and renders every ticket to a sequentially numbered PDF:

```
tmp/printed_tickets/000001.pdf   # Rendered ticket
tmp/printed_tickets/000001.fgl   # Raw FGL commands
tmp/printed_tickets/index.jsonl  # One JSON line per ticket
```

To start over, stop services and delete `tmp/printed_tickets/`; numbering restarts at 000001.

**Fonts:** TKTPrint uses Verdana for `<RTF3..6>` text. Without it the virtual printer substitutes DejaVu Sans (slightly wider). To use Verdana, place the `.ttf` files in `tmp/fonts/` or set `BOCA_FONT_DIR`. Never commit font files.

**Send raw FGL by hand:**

```bash
printf '<RC10,10><F3>HELLO<p>' | nc localhost 9100
```

## API Endpoints

All endpoints require HTTP Basic Auth.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/orders.json` | List all orders |
| `POST` | `/orders.json` | Create order |
| `GET` | `/orders/:id.json` | Show order |
| `PUT` | `/orders/:id.json` | Update order |
| `POST` | `/orders/:id/print.json` | Print (or reprint) an order |
| `PUT` | `/orders/:id/reprint.json` | Reprint with updated data, tickets, and flags |
| `GET` | `/orders/:id/find_by_remote.json` | Find order by remote_id |
| `GET` | `/tickets.json?order_id=:id` | List tickets for an order |
| `PUT` | `/tickets/:id.json` | Update a ticket |
| `GET` | `/token` | Get auth token |

## Stopping

```bash
docker compose down
```
