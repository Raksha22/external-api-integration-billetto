# External API Integration (Billetto Assessment)

This project implements **Step 1** of the Billetto Rails test:
- Rails app with PostgreSQL
- Billetto API ingestion with error handling (via **`app/integrations/billetto`** + **`Guidelines::PublicEventsImporter`**)
- Persisted **read model** `Guidelines::Event` (`events` table) with validations
- Optional **domain fact** on sync: `PublicEventsSynced` in **Rails Event Store** (see Design Notes)
- Events listing page (title, date, image, description)
- RSpec + SimpleCov setup

## Stack

- Ruby `3.0.2`
- Rails `7.1.6`
- PostgreSQL
- RSpec (`rspec-rails`)
- Coverage (`simplecov`)

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
4. Create and migrate database:
   - `bin/rails db:create db:migrate` (includes Rails Event Store tables for domain facts)
5. Start server:
   - `bin/rails server`
6. Open:
   - [http://localhost:3000](http://localhost:3000)

## Importing Events

- From UI: click **Sync Events** on the events page.
- From CLI: `bin/rails billetto:import_events`

## Testing

- Run tests: `bundle exec rspec`
- Coverage report: `coverage/index.html`

## Design Notes

This app follows the internal [Developer's Guide](../Developer's_Guide.md) patterns where applicable:

- Controllers stay thin: build a command and call `command_bus` (see `EventsController`).
- Bounded context `Guidelines` lives under `app/models/guidelines/` with facts (`PublicEventsSynced`), commands (`SyncPublicEvents`), handler (`Guidelines::Service`), and importer (`Guidelines::PublicEventsImporter`).
- Third-party HTTP lives under `app/integrations/billetto` (`Billetto::Client`) as an ACL-style adapter.
- `Guidelines::Event` is the persisted aggregate read model; sync publishes `PublicEventsSynced` via `rails_event_store`.
- Shared plumbing: `lib/command/` (bus + handler), `lib/fact.rb`, `lib/object_repository.rb`, `lib/application_subscriptions.rb` (merge point for module subscriptions).

## Assumptions

- Billetto uses the **`Api-Keypair`** header (`key:secret`), not Bearer auth — see their docs.
- Default host is `https://billetto.dk` with path `/api/v3/public/events`; override `BILLETTO_API_BASE_URL` for your region.

## Troubleshooting Billetto sync

- **404**: Wrong host or path. Use your regional site as base URL (`.dk`, `.co.uk`, etc.) and path `/api/v3/public/events`.
- **401 / authentication_error**: Missing or wrong key pair; ensure both parts are present as `key:secret` in `BILLETTO_API_KEYPAIR`.
