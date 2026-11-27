---
name: virtual-boca-printer
description: How tktprint's virtual Boca printer (fgl-pdf) works - starting it, where printed PDFs/FGL land, FGL_PDF_* and BOCA_* knobs, Verdana font setup, and sending raw FGL by hand. Use when debugging ticket or receipt rendering or changing printer output.
---

# Virtual Boca printer

The virtual printer renders every ticket and receipt to PDF instead of thermal stock. See `docker/README.md` for the compose service and `CLAUDE.md` for which `config/printer.yml` address selects it.

- The `boca_printer` service (compose profile `virtual-printer`) is built from
  [fgl-pdf](https://github.com/jwechsler/fgl-pdf). It listens on port 9100 like a real Boca;
  `start-printer.sh` starts it when `config/printer.yml` points the app at it.
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
