# External API Integration (Billetto Assessment)

This project implements **Steps 1–2** of the [Billetto Rails test](../billetto_rails_test.md). Use this README for **setup and configuration**; see **`follow-up interview.md`** for step-by-step talking points and interview prep.

## Assessment steps (what maps to what)

| Step | Brief goal | Status in this repo |
|------|------------|---------------------|
| **1** | Billetto API, ingestion, `Event` read model, listing UI | Done |
| **2** | Clerk auth; voting only when signed in; **`clerk_user_id`** on vote facts in Rails Event Store | Done |
| **3** | Vote counts on the listing (projection / read model from RES) | Not implemented yet |
| **4** | Tests: models, auth gate, RES; optional browser tests for Clerk + voting | Partially done (no browser suite yet) |

**Step 1 (done)**

- Rails app with PostgreSQL
- Billetto API ingestion with error handling (via **`app/integrations/billetto`** + **`Guidelines::PublicEventsImporter`**)
- Persisted **read model** `Guidelines::Event` (`events` table) with validations
- Domain fact on sync: **`Guidelines::PublicEventsSynced`** in **Rails Event Store**
- Events listing page (title, date, image, description)
- RSpec + SimpleCov setup

**Step 2 (done — [Clerk](https://clerk.com/) per test brief)**

- **Sign-in / sign-up / sign-out** via Clerk (`clerk-sdk-ruby` + Account Portal URLs from `.env`; layout loads Clerk JS so the Rack session stays in sync with the browser).
- **Account Portal return URL**: links append **`redirect_url`** (full URL back to this app’s **`/`**) so users land on the events page after auth instead of Clerk’s generic default ([direct links](https://clerk.com/docs/guides/account-portal/direct-links)).
- **Voting** (`POST /events/:id/vote` with `direction=up|down`) is allowed only when **`clerk.user?`** is true; guests are redirected to sign-in with **`allow_other_host: true`** (Rails 7.1 safe redirects).
- **Vote traceability**: **`Guidelines::EventUpvoted`** / **`Guidelines::EventDownvoted`** include **`clerk_user_id`** and **`event_external_id`**; streams follow the Developer’s Guide multi-stream pattern.
- **UX**: Successful vote sets flash **`notice: "Vote recorded."`** on the listing; there are **no per-event vote totals yet** (Step 3). Stale **“Please sign in to vote.”** flash is cleared on **`events#index`** once you are signed in.

## Stack

- Ruby `3.0.2`
- Rails `7.1.6`
- PostgreSQL
- RSpec (`rspec-rails`)
- Coverage (`simplecov`)

## Configuration reference

### Environment variables (`.env`)

Copy **`.env.example`** → **`.env`** and fill in real values. **`Dotenv.overload`** runs in **development only** (`config/application.rb`), so empty shell exports do not mask `.env`, and **test** keeps explicit placeholders from `rails_helper` when needed.

| Variable | Step | Purpose |
|----------|------|---------|
| `POSTGRES_*` / `DATABASE_URL` | 1 | Database connection (`DATABASE_URL` wins if set in the shell) |
| `BILLETTO_API_KEYPAIR` (or access key + secret) | 1 | Billetto **`Api-Keypair`** header |
| `BILLETTO_API_BASE_URL` | 1 | Regional API origin (default `https://billetto.dk`) |
| `CLERK_PUBLISHABLE_KEY` | 2 | Publishable key (`pk_test_…` / `pk_live_…`) — layout loads Clerk JS |
| `CLERK_SECRET_KEY` | 2 | Secret key (`sk_test_…` / `sk_live_…`) — server-side verification |
| `CLERK_SIGN_IN_URL` | 2 | Account Portal sign-in URL (from Clerk dashboard) |
| `CLERK_SIGN_UP_URL` | 2 | Account Portal sign-up URL |
| `CLERK_SIGN_OUT_URL` | 2 | Account Portal sign-out URL |

**Secret key resolution** (`config/initializers/clerk.rb`): **production** prefers **`Rails.application.credentials.dig(:clerk, :secret_key)`**, then **`ENV["CLERK_SECRET_KEY"]`**. **Development / test** prefers **`ENV`** first, then credentials; **test** uses a dummy `sk_test_…` only when both are blank (specs stub Clerk).

### Clerk dashboard checklist (Step 2)

- Use **one Clerk application**: publishable key, secret key, and Account Portal host must belong to the **same** instance (avoid mixing `pk_` from app A with `sk_` from app B).
- Copy **Sign in**, **Sign up**, and **Sign out** URLs into `.env`. This app **adds `redirect_url`** pointing at `http://localhost:3000/` (or your deployed origin) when building links — ensure allowed redirect origins in Clerk match how you run the app.
- If the Dashboard **Signing out** section shows **after sign out → Sign-in page on Account Portal** (`…/sign-in`), that is Clerk’s default destination **after** logout — change it to your **Rails URL** if you want the nav back on your app (see **`docs/CLERK_DASHBOARD.md` §2b**).
- **Rails vs Vite (`clerk-react`)**: see **Single sign-in across React and Rails** below.

### Single sign-in across React and Rails

**If you sign in only in the Vite app (`clerk-react` on port 5173), Rails (`localhost:3000`) will not automatically show Like/Dislike.** That is expected with this setup, not a bug.

Browsers treat **`http://localhost:5173`** and **`http://localhost:3000`** as **different origins** (scheme + host + port). Clerk’s session for the SPA lives in that SPA’s context. The Rails app uses **`clerk-sdk-ruby`** middleware + Clerk JS on **Rails-rendered pages** to attach a session to requests hitting **3000**. There is no built-in bridge in this repo that copies the React session onto Rails.

**Ways to get one login for both (conceptually):**

1. **Same origin in development** — Run the UI and API under one host/port (e.g. serve the Vite build from Rails, or put Vite behind a reverse proxy so both are `http://localhost:3000`). Then one Clerk session covers both.
2. **Cross-origin API style** — Keep two origins but have the SPA call Rails with **`Authorization: Bearer <token>`** (e.g. Clerk session token from `getToken()`), and teach Rails to verify that JWT with Clerk instead of relying only on cookie-based session for those requests. This is extra work beyond the stock Rails integration used here; see Clerk’s guide on [making authenticated requests / cross-origin](https://clerk.com/docs/guides/development/making-requests#cross-origin-requests).
3. **Production multi-domain** — Clerk supports patterns like **satellite domains** when you control real domains; localhost ports are still two origins until you unify URLs.

**Practical default for this assessment:** sign in using the **Sign in** link on the **Rails** events page when you want to vote.

**Sign out mirrors sign-in:** If you use **separate** servers (**React on 5173**, **Rails on 3000**), signing out in **React does not** sign you out on **Rails** — Clerk cookies are scoped per **origin**. Rails can still show **Sign in** leading to a quick return because your **`*.accounts.dev`** session or a **`localhost:3000`** cookie may still be active. **Fix:** use **Sign out** on Rails too, clear cookies for both hosts, or run **only** the unified flow (**`http://localhost:5173/billetto`**) so one origin shares one session.

## Setup

1. Install dependencies:
   - Ruby 3.0.2
   - PostgreSQL 13+
2. Install gems:
   - `bundle install`
3. Configure env vars (copy from `.env.example`):
   - `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
   - If **`DATABASE_URL`** is already set in your shell (e.g. `postgres://USER:…`), it overrides `POSTGRES_*`. Use real credentials or run `unset DATABASE_URL` before `bin/rails`.
   - Billetto **API key pair**: `BILLETTO_API_KEYPAIR=key:secret` (or `BILLETTO_API_ACCESS_KEY` + `BILLETTO_API_SECRET`). See [obtaining an API key](https://api.billetto.com/docs/obtaining-an-api-key).
   - If you are not on `.dk`, set `BILLETTO_API_BASE_URL` (e.g. `https://billetto.co.uk`).
   - **Clerk** (Step 2): **`CLERK_PUBLISHABLE_KEY`**, **`CLERK_SECRET_KEY`**, and **`CLERK_SIGN_IN_URL`**, **`CLERK_SIGN_UP_URL`**, **`CLERK_SIGN_OUT_URL`** — see **Configuration reference** above and [Clerk Rails docs](https://clerk.com/docs/reference/ruby/rails). Optional: store only the secret in **`bin/rails credentials:edit`** as `clerk.secret_key`.
4. Create and migrate database:
   - `bin/rails db:create db:migrate` (includes Rails Event Store tables for domain facts)
5. Start server:
   - `bin/rails server`
6. Open:
   - [http://localhost:3000](http://localhost:3000)

## Importing Events

- From UI: click **Sync Events** on the events page.
- From CLI: `bin/rails billetto:import_events`

## Voting (Step 2)

- On the events list, **Like** / **Dislike** submit `POST` to `/events/:event_id/vote` with `direction` `up` or `down`.
- Requires an active **Clerk session**; otherwise you are redirected to sign-in.
- Vote outcomes are stored as Rails Event Store facts (inspect `event_store_events.event_type` for `EventUpvoted` / `EventDownvoted`). **Vote counts on the listing** are part of **Step 3** in the test brief (not implemented here).

## Testing

- Install gems first: `bundle install` (if installing gems hits permission errors on your machine, use `bundle config set path vendor/bundle` once in this directory, then `bundle install` again).
- Run tests: `bin/rspec` (or `bundle exec ruby -S rspec` if `bundle exec rspec` is not found on your Ruby/Bundler setup).
- **Native gem mismatch (`incompatible library version` for `stringio.so`, `json.so`, `bootsnap.so`, …):** extensions in `vendor/bundle` were built for a **different Ruby** than the one running `bin/rspec` (common after upgrading Ruby, switching rbenv/rvm/system, or copying the project). Confirm **`ruby -v`** matches the Gemfile (**3.0.2**), then reinstall gems for that interpreter:
  - **`rm -rf vendor/bundle && bundle install`** (recommended), or
  - **`bundle pristine --all`** (rebuild every native extension in the current bundle path).
    Bootsnap load failures are also tolerated in **`config/boot.rb`** (the app boots without Bootsnap if the `.so` cannot load), but **`stringio` / `json`** must match your Ruby or RSpec cannot start—there is no runtime workaround beyond reinstalling.
- Coverage report: `coverage/index.html`

## Design Notes

This app follows the internal [Developer's Guide](../Developer's_Guide.md) patterns where applicable:

- Controllers stay thin: build a command and call `command_bus` (see `EventsController`).
- Bounded context `Guidelines` lives under `app/models/guidelines/` with facts (`PublicEventsSynced`, `EventUpvoted`, `EventDownvoted`), commands (`SyncPublicEvents`, `RecordEventVote`), handler (`Guidelines::Service`), and importer (`Guidelines::PublicEventsImporter`).
- **`EventVotesController`** issues **`RecordEventVote`** through the command bus only after **`require_clerk_session!`** (Developer’s Guide: no side-stepping the bus; auth gate at the HTTP boundary).
- Third-party HTTP lives under `app/integrations/billetto` (`Billetto::Client`) as an ACL-style adapter.
- `Guidelines::Event` is the persisted aggregate read model; sync publishes `PublicEventsSynced` via `rails_event_store`.
- Shared plumbing: `lib/command/` (bus + handler), `lib/fact.rb`, `lib/object_repository.rb`, `lib/application_subscriptions.rb` (merge point for module subscriptions).

## Assumptions

- Billetto uses the **`Api-Keypair`** header (`key:secret`), not Bearer auth — see their docs.
- Default host is `https://billetto.dk` with path `/api/v3/public/events`; override `BILLETTO_API_BASE_URL` for your region.

## Troubleshooting Billetto sync

- **404**: Wrong host or path. Use your regional site as base URL (`.dk`, `.co.uk`, etc.) and path `/api/v3/public/events`.
- **401 / authentication_error**: Missing or wrong key pair; ensure both parts are present as `key:secret` in `BILLETTO_API_KEYPAIR`.

## Troubleshooting Clerk

- **Boot error “Missing Clerk secret key”**: Add **`CLERK_SECRET_KEY`** to `.env` or set `clerk.secret_key` via `bin/rails credentials:edit` (see `.env.example`).
- **`secret_key must start with 'sk_'` / “Invalid Clerk secret key”**: Use the **Secret** key row in Clerk, not the publishable key; uncomment/fix the line in `.env`.
- **`KeyError` / missing `CLERK_SIGN_*_URL`**: Copy sign-in, sign-up, and sign-out URLs from the Clerk dashboard (Account Portal) into `.env`.
- **Unsafe redirect / 500 when voting while signed out**: Fixed in-app with **`allow_other_host: true`** to Clerk’s host; if you fork this, keep that on the vote gate redirect.
- **Redirect loops or malformed `redirect_url` query**: Ensure Clerk allowed origins / return URLs match **`request.base_url`**; this app builds **`redirect_url`** as a full URL to **`/`** via `ApplicationController#append_clerk_redirect_url`.
- **Signed in in nav but still see “Please sign in to vote.”**: Usually stale flash after returning from Clerk — **`EventsController`** clears that alert on **`index`** when **`clerk.user?`**; refresh the listing if needed.
- **Vote succeeds but UI looks unchanged**: Expect a green **“Vote recorded.”** notice only; **vote counts on cards** are Step 3.
- **Redirect loops or missing session**: Match application URL to how you open the app (`127.0.0.1` vs `localhost`), allow cookies, and sign in on **the same host/port** as the Rails app.
- **Still “Signed in” after Sign out:** the nav uses **`Clerk.signOut({ redirectUrl: root_url })`** when Clerk JS is loaded so cookies/session clear before reload. Ensure **`CLERK_PUBLISHABLE_KEY`** is set. **`CLERK_SIGN_OUT_URL`** must still be the hosted **`…/sign-out`** URL (fallback if JS fails).
