# TKTPrint

A small Rails API that turns JSON orders into physical theater tickets and receipts on a
[Boca](https://www.bocasystems.com/) thermal printer. It speaks FGL (Boca's Friendly Ghost
Language) over a raw TCP socket on port 9100, queues print jobs with Delayed Job, and keeps
its own SQLite database so it runs happily on a Raspberry Pi in the box office.

Built for [Theater Wit](https://www.theaterwit.org) in Chicago, where the ticketing system
posts each sale here and the tickets come out of the printer at the counter.

## How it works

1. The ticketing system `POST`s an order (patron, performance, line items, payments, tickets).
2. An order whose status is `Unprinted` queues a print job. Delayed Job waits one second to
   batch any immediate updates, then prints.
3. `Printer` opens a socket to the Boca, sends the FGL for each ticket (barcode, logo, stub)
   and the receipt, and marks the order `Printed`.
4. Reprints go through `POST /orders/:id/print` or `PUT /orders/:id/reprint` and carry a
   REPRINT banner.

The theater logo is uploaded to the printer's memory at boot by `script/initialize_printer`.
Receipts can carry up to three small icons ("flags") chosen by the caller; TKTPrint attaches
no meaning to them.

## Requirements

- Ruby 3.2.2, Rails 6.1 (see `Gemfile`)
- SQLite 3
- A Boca printer reachable on the network, or the virtual printer below

## Setup

```bash
bundle install
cp config/authorization.yml.example config/authorization.yml   # API credentials
cp config/printer.yml.example config/printer.yml               # this machine's printer
bundle exec rails db:setup
```

`config/printer.yml` is gitignored and keyed by `RAILS_ENV`. Each machine sets its own
printer address:

| address | effect |
|---|---|
| `192.168.x.x` | prints real tickets on that Boca |
| `"boca_printer"` | renders tickets to PDFs via the virtual printer (Docker) |
| `"localhost"` | skips printing entirely (what the specs use) |

Two processes are needed:

```bash
bundle exec rails server
bundle exec bin/delayed_job start
```

In production also export `SECRET_KEY_BASE`, `RAILS_ENV=production`, and optionally
`PORT`, `WEB_CONCURRENCY` and `RAILS_MAX_THREADS`.

## Docker and the virtual printer

`./start-printer.sh` starts the web server and worker in Docker. When `config/printer.yml`
sends the current `RAILS_ENV` to `"boca_printer"`, it also starts a virtual Boca built from
[fgl-pdf](https://github.com/jwechsler/fgl-pdf). Every ticket and receipt is rendered to
`tmp/printed_tickets/NNNNNN.pdf`, with the raw FGL alongside and a line per ticket in
`index.jsonl`. This is the normal way to develop without a printer on the desk.

See `docker/README.md` for the compose layout, logs, console and production image, and
`.claude/skills/virtual-boca-printer/SKILL.md` for the rendering knobs (debug grid, feed DPI,
fonts).

## API

All endpoints require HTTP Basic Auth with the credentials in `config/authorization.yml`
and use the `.json` format.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/token` | Returns an auth token |
| `GET` | `/orders` | List orders |
| `POST` | `/orders` | Create an order (prints if status is `Unprinted`) |
| `GET` | `/orders/:id` | Show an order |
| `PUT` | `/orders/:id` | Update an order (prints if status becomes `Unprinted`) |
| `GET` | `/orders/:id/find_by_remote` | Look up by the ticketing system's `remote_id` |
| `POST` | `/orders/:id/print` | Force a reprint |
| `PUT` | `/orders/:id/reprint` | Reprint, replacing order data, tickets and flags if sent |
| `GET` | `/tickets?order_id=:id` | List an order's tickets |
| `PUT` | `/tickets/:id` | Update a ticket (for example its seat) |
| `POST` `GET` | `/print_batches` | Create or list print batches |
| `PUT` | `/print_batches/:batch_id/close` | Close a batch |

Example order:

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

All text fields are sanitized (HTML tags stripped) before printing. `flags` is an optional
array of icon names from `config/flags.yml`.

## Tests

```bash
bundle exec rspec
```

Specs force the printer address to `localhost`, so nothing is ever sent to a printer.
GitHub Actions runs the suite on every push.

## License

GPL-3.0. See `LICENSE`.
