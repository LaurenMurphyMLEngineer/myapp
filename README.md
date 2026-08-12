# myapp — receipt capture, powered by Gemini vision

Upload a photo of a receipt from any device with a browser, and the app
extracts the merchant, total, purchase date, and spending category
automatically — no manual data entry, no local OCR binary.

**Live:** https://myapp-lqcq.onrender.com

## How it works

1. You snap or upload a photo of a receipt (`/receipts/new`).
2. The image is stored in Supabase Storage (S3-compatible object storage).
3. The photo is sent to Gemini's API along with a JSON schema describing the
   fields to extract — Gemini returns merchant, total, purchase date,
   category, and the raw transcribed text as typed JSON matching that
   schema, not free-form text to be parsed.
4. The receipt is saved with that structured data and shown immediately.

## Stack

- **Rails 8** (Ruby), Hotwire (Turbo/Stimulus)
- **PostgreSQL** — application data, plus Solid Queue / Solid Cache / Solid
  Cable each running as separate logical databases on the same instance
- **Active Storage** with a custom **Supabase Storage** (S3-compatible)
  backend for uploaded images
- **Gemini API** (vision + schema-constrained structured output) for
  receipt extraction
- Deployed on **Render** (native Ruby build, no Docker)

## Why this project

Most "OCR a receipt" demos stop at dumping raw scanned text on the page.
This one asks a vision model to return typed, structured data directly —
merchant name, total, date, and a spending category — using Gemini's
schema-constrained response format, so the output is immediately usable
(search, filter, sum by category) rather than text a person still has to
read and re-type.

## Local development

```bash
bin/setup
bin/rails server
```

Requires a local PostgreSQL instance. Uploaded images are stored on local
disk in development — no external credentials needed unless you're testing
the receipt scanner itself, which requires `GEMINI_API_KEY`.

## Deployment

See [DEPLOY.md](DEPLOY.md) for the full Render + Supabase setup, including
required environment variables.
