# Deploying myapp to Render

**Live at:** https://myapp-lqcq.onrender.com

This app extracts structured data (merchant, total, date, category) from
uploaded receipt photos using Google's Gemini API (free tier), and stores
images in Supabase Storage (S3-compatible). It runs on Render's native Ruby
build (no Docker required).

## 1. Supabase — storage bucket + keys (done)

Project: https://zffxswttavrsddvuovpx.supabase.co

The `receipts` bucket already exists. S3 access keys were generated under
**Storage → S3 Connection** in the Supabase dashboard and are set as env
vars on Render (see the table below) — not stored in this repo.

## 2. Gemini — free API key for receipt scanning

1. Get a free key at https://aistudio.google.com/apikey — no credit card
   required for the free tier.
2. Set it as `GEMINI_API_KEY` on the Render web service (see step 4).
3. Optional: `GEMINI_MODEL` env var overrides the default model
   (`gemini-3.6-flash`) if you want to try a different one.
4. Note: free-tier requests may be used by Google to improve their models
   (unlike paid-tier usage), worth keeping in mind since receipts contain
   personal spending data.

## 3. Push code changes

Whenever you change the app, from the `myapp` folder on your machine:

```bash
bundle install   # only needed if the Gemfile changed
git add -A
git commit -m "Describe the change"
git push
```

Render auto-deploys on every push to `main` (Deploys tab on the web service
shows progress).

## 4. Render — environment variables

Web service → **Environment** tab should have:

| Key | Value |
|---|---|
| `RAILS_MASTER_KEY` | contents of `config/master.key` |
| `DATABASE_URL` | Internal Database URL from the Postgres instance |
| `WEB_CONCURRENCY` | `2` |
| `GEMINI_API_KEY` | key from step 2 |
| `SUPABASE_ACCESS_KEY_ID` | access key from Supabase Storage → S3 Connection |
| `SUPABASE_SECRET_ACCESS_KEY` | secret key from Supabase Storage → S3 Connection |
| `SUPABASE_BUCKET` | `receipts` |
| `SUPABASE_REGION` | `us-west-2` |
| `ADMIN_EMAIL` | the email you want to log in with |
| `ADMIN_PASSWORD` | the password you want to log in with |

`OCR_SPACE_API_KEY` is no longer used and can be removed if present.

The app now requires login (added via Rails 8's built-in `bin/rails generate
authentication`). `ADMIN_EMAIL`/`ADMIN_PASSWORD` create your one account via
`db:seed` on first deploy — only if no user exists yet, so it's safe to
leave those vars set permanently. There's no public sign-up page by design
(this is a single-user app); to add another user later, set new values and
manually create one via `bin/rails console` on Render's Shell, or extend
`db/seeds.rb`.

Build command: `./bin/render-build.sh` — installs gems, precompiles assets,
runs `db:prepare`, and explicitly backfills the solid_cache/solid_queue/
solid_cable schemas if `db:prepare` skipped them (a known quirk when those
roles share one physical Postgres database with `primary`).

Start command: `bin/rails server`

After adding/changing an env var, Render usually needs a manual "Deploy
latest commit" to pick it up — saving the variable alone doesn't always
trigger a fresh deploy.

## 5. Try it

Open the live URL from any device and go to `/receipts/new` to upload a
photo.

## Notes

- `Dockerfile`, `.kamal/`, and `config/deploy.yml` are left in the repo but
  unused by this Render deploy.
- Local development still stores files on local disk (see the `local:`
  service in `config/storage.yml`) and doesn't require `GEMINI_API_KEY`
  unless you're testing the scanner locally.
- Render's free Postgres instance expires after 30 days — upgrade to a paid
  instance before then if you want to keep the data.
