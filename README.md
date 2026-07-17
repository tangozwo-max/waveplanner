# 🌊 Wave Planner (online)

Online version of the Wave surf-session planner. Static front-end (`index.html`)
backed by **Supabase** (Postgres + Auth), deployed from **GitHub** to **Vercel**.

- Everyone signed in sees the **shared grid** (all surfers' sessions).
- You can only **add / edit / delete your own** sessions (enforced by Row Level Security).
- Wave levels are stored in the database (`waveplanner.levels`), not hard-coded.
- Per-person summary shows how many sessions each surfer has booked.

## Database

All objects live in a Postgres schema named **`waveplanner`** (not `public`).

| Table                   | Purpose |
|-------------------------|---------|
| `waveplanner.surfers`   | One row per person, linked 1:1 to a Supabase auth user (`user_id`). Holds the grid label `code` (e.g. `A`, `T`) and display `name`. |
| `waveplanner.levels`    | Wave types — `name`, `abbr`, `color`, `sort_order`, `active`. |
| `waveplanner.bookings`  | Sessions — `surfer_id`, `level_id`, `session_date`, `session_time`, `side` (`L`/`R`), `status` (`out`/`in`), `coaching`, `announcement`, `ref`. Unique per `(surfer_id, date, time)`. An `announcement` row marks that a session exists in a slot without booking anyone in — drawn as a subtle gray marker, excluded from per-person counts. |

RLS: read-all for signed-in users, write-your-own for `bookings`/`surfers`.
A trigger on `auth.users` auto-creates a `surfers` row on sign-up.

### One-time Supabase setup

1. **SQL Editor → New query** → paste and run [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql).
2. Run [`supabase/seed.sql`](supabase/seed.sql) to load the wave levels.
3. **Project Settings → API → Exposed schemas**: add **`waveplanner`** (and to the
   "Extra search path"). Save. *(Without this the REST API can't reach the tables.)*
4. **Authentication → Providers → Google**: enable it (see "Google sign-in" below).
   Email sign-in still works as a fallback via the "Sign in with email instead" link.

### Google sign-in setup

1. **Supabase → Authentication → Providers → Google** → toggle on. Note the shown
   **Callback URL**: `https://stfbdglkexcsgtfphvha.supabase.co/auth/v1/callback`.
2. **Google Cloud Console** (https://console.cloud.google.com) → APIs & Services:
   - Configure the **OAuth consent screen** (User type: External; add yourself + Tim as
     test users, or publish the app).
   - **Credentials → Create Credentials → OAuth client ID → Web application**:
     - **Authorized JavaScript origins**: your Vercel URL (and `http://localhost:3000` for local).
     - **Authorized redirect URIs**: `https://stfbdglkexcsgtfphvha.supabase.co/auth/v1/callback`
   - Copy the **Client ID** and **Client secret**.
3. Paste Client ID + secret into the Supabase Google provider and **Save**.
4. **Supabase → Authentication → URL Configuration**:
   - **Site URL** = your Vercel URL.
   - **Redirect URLs** = add your Vercel URL and your local dev URL.
     (The app redirects back to `window.location.origin + pathname`.)

## Local development

```bash
cp config.example.js config.js   # then fill in your SUPABASE_URL + anon key
# open index.html with any static server, e.g.:
npx serve .
```

`config.js` is git-ignored. The committed local copy already has this project's URL and
publishable (anon) key — the anon key is safe in the browser because RLS guards the data.

## Deploy to Vercel

1. Push this repo to GitHub (`tangozwo-max/waveplanner`).
2. In Vercel: **New Project → import the repo**. Framework preset: **Other**.
   Vercel reads `vercel.json` (`buildCommand: node build.js`).
3. **Project → Settings → Environment Variables**, add:
   - `SUPABASE_URL` = `https://stfbdglkexcsgtfphvha.supabase.co`
   - `SUPABASE_ANON_KEY` = your publishable/anon key
   `build.js` writes these into `config.js` at build time.
4. Deploy. Add the Vercel URL under Supabase **Authentication → URL Configuration**
   (Site URL / redirect URLs).

## Files

```
index.html                     the app (auth gate + planner)
config.js                      runtime keys (git-ignored; generated on Vercel)
config.example.js              template to copy for local dev
build.js                       writes config.js from env on Vercel
vercel.json / package.json     Vercel build config
supabase/migrations/0001_init.sql   schema + RLS + triggers
supabase/seed.sql                   wave levels
```
