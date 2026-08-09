# Deploying myapp to Render

This app scans uploaded receipt images with OCR.space (no local binary
needed) and stores images in Supabase Storage (S3-compatible), so it can
run on Render's native Ruby build (no Docker required).

## 1. Supabase — storage bucket + keys

Project: https://zffxswttavrsddvuovpx.supabase.co

1. In the Supabase dashboard, go to **Storage** and create a bucket named
   `receipts` (private is fine — Active Storage generates signed URLs).
2. Go to **Storage → S3 Connection** (sometimes under Project Settings) and
   generate an **Access Key ID** / **Secret Access Key** pair for the S3
   protocol. Note the **region** shown there too (commonly `us-east-1`).
3. Keep these three values handy for step 4: access key id, secret access
   key, region.

## 2. OCR.space — free API key

1. Get a free key at https://ocr.space/ocrapi/freekey (25,000 requests/month
   free tier).
2. Keep the key handy for step 4.

## 3. Push the code

On your own machine, in the `myapp` folder:

```bash
bundle install          # regenerates Gemfile.lock (drops rtesseract, adds aws-sdk-s3)
git add -A
git commit -m "Switch OCR to OCR.space and storage to Supabase for Render"
git remote -v           # check if 'origin' is already set
# if not already set:
git remote add origin https://github.com/LaurenMurphyMLEngineer/myapp.git
git branch -M main      # only if your default branch isn't already named main
git push -u origin main
```

## 4. Render — database + web service

**Database:**
1. New → PostgreSQL. Note the connection string it gives you (or link it to
   the web service below in the same project so `DATABASE_URL` is wired
   automatically).

**Web service:**
1. New → Web Service → connect the `myapp` GitHub repo.
2. Environment: **Ruby** (native, not Docker).
3. Build command: `./bin/render-build.sh`
4. Start command: `bin/rails server`
5. Add these environment variables:

   | Key | Value |
   |---|---|
   | `RAILS_MASTER_KEY` | contents of `config/master.key` |
   | `DATABASE_URL` | from the Postgres instance (auto-filled if linked) |
   | `OCR_SPACE_API_KEY` | key from step 2 |
   | `SUPABASE_ACCESS_KEY_ID` | access key from step 1 |
   | `SUPABASE_SECRET_ACCESS_KEY` | secret key from step 1 |
   | `SUPABASE_BUCKET` | `receipts` |
   | `SUPABASE_REGION` | region from step 1 (e.g. `us-east-1`) |

   (`SUPABASE_STORAGE_ENDPOINT` doesn't need to be set — it already defaults
   to your project's endpoint in `config/storage.yml`.)

6. Deploy. Render runs `bin/render-build.sh` (bundle install, precompile
   assets, `db:prepare` — creates and migrates the primary DB plus the
   solid_cache/solid_queue/solid_cable tables in one step) then starts Puma.

## 5. Try it

Once the deploy is live, open the Render URL from your phone (or any
device on the web), go to `/receipts/new`, and upload a photo of a
receipt.

## Notes

- `Dockerfile`, `.kamal/`, and `config/deploy.yml` are left in the repo but
  unused by this Render deploy (they're for a Docker/Kamal-based deploy
  path, which was set aside in favor of Render's native Ruby build).
- Local development still stores files on local disk (see the `local:`
  service in `config/storage.yml`) — only production uses Supabase.
