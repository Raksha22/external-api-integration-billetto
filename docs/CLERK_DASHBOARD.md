# Clerk Dashboard configuration (Rails + React + unified `/billetto`)

Use **one** Clerk application for both **`external-api-integration`** (Rails) and **`clerk-react`** (Vite). Copy **Publishable** and **Secret** keys from the same **Development** instance.

Clerk’s UI labels move occasionally; if a menu name differs, search the dashboard for **Paths**, **redirect**, or **URLs**.

---

## 1. API keys

1. Open [Clerk Dashboard](https://dashboard.clerk.com/) → your application → **Configure** → **API keys** (or **Developers** → **API keys**).
2. Copy **Publishable key** (`pk_test_…`) into:
   - `external-api-integration/.env` → `CLERK_PUBLISHABLE_KEY`
   - `clerk-react/.env` → `VITE_CLERK_PUBLISHABLE_KEY`
3. Copy **Secret key** (`sk_test_…`) into **`external-api-integration/.env` only** → `CLERK_SECRET_KEY`  
   (never commit secrets into the React-only `.env` if it ships to the browser; here Vite only exposes `VITE_*` publishable values.)

---

## 2. Account Portal URLs (Rails `clerk-sdk-ruby`)

Rails uses **hosted** Account Portal links from `.env`:

1. Dashboard → **Configure** → **Account Portal** (sometimes under **User & authentication**).
2. Open each hosted page and copy the browser URL, or use the **copy link** actions Clerk provides:
   - **Sign-in** → `CLERK_SIGN_IN_URL`
   - **Sign-up** → `CLERK_SIGN_UP_URL`
   - **Sign-out** → `CLERK_SIGN_OUT_URL`  
   Typical shapes: `…/sign-in`, `…/sign-up`, `…/sign-out` — **three different URLs**. Do **not** paste the sign-in URL into `CLERK_SIGN_OUT_URL`; if you do, **Sign out** in the Rails nav will open the **sign-in** page (looks like “sign out does the same as sign in”). On boot, development logs a warning if these look misconfigured.

Rails **appends** `redirect_url` so users return to your app after auth. No extra dashboard toggle is required for that; ensure redirects are allowed (step 4).

### 2b. “Signing out” in the Dashboard — two different things

Clerk’s **Account Portal** screen often shows something like:

- **Signing out** — *Specify where to take a user after they sign out*
- **Sign-in page on Account Portal** → `https://YOUR-SLUG.accounts.dev/sign-in`

That setting is **not** your `CLERK_SIGN_IN_URL` row in `.env` by mistake — it means: **after** Clerk finishes signing the user out, send them to the **hosted sign-in page** on Account Portal. That is **normal Clerk defaults**, but for this Rails app you usually want users to **land back on your server** so the nav shows **Sign in / Sign up** on **your** origin.

**What to do**

1. In **Account Portal**, find the control for **where to go after sign out** (same area as “Signing out” / post sign-out destination).
2. Choose **custom URL**, **application URL**, **development host**, or whatever option lets you enter **your Rails URL**, for example:
   - `http://127.0.0.1:3000/`  
   - or, if you use `RAILS_RELATIVE_URL_ROOT=/billetto`: `http://127.0.0.1:3000/billetto`  
   - or unified Vite SSO: `http://localhost:5173/billetto`
3. Keep that URL in your **allowed / fallback redirect** lists (step 4).
4. **`CLERK_SIGN_OUT_URL` in `.env`** should still be Clerk’s **sign-out** endpoint URL (path usually **`/sign-out`** on the same `*.accounts.dev` host — copy it from the Portal “links” / hosted URLs, not from this “after sign out → sign-in page” line). The boot warning in Rails flags if sign-out and sign-in URLs are identical.

The Rails layout also calls **`Clerk.signOut({ redirectUrl: root_url })`** so the browser clears the session and returns to your app; aligning the Dashboard **after sign-out** destination avoids Clerk sending people to **`…/sign-in`** on the Portal when you expected your homepage.

**Note:** Clerk may show *“Setting component paths via the Dashboard will be deprecated…”* — they are moving some URL configuration into code. Until you migrate, use the Dashboard for redirects; your `.env` hosted URLs remain valid.

### Dev-only: “instant” sign-in, no email step, and `__clerk_handshake`

With **`sk_test_`** and Clerk **browser JS** on the Rails layout, Clerk often completes a **handshake** (`GET /?__clerk_handshake=…`) to sync cookies. That path **does not show** the hosted Account Portal email/password screen. It can feel like **Sign in** does nothing visible or logs you in without choosing an email.

**What to do if you want to see email / identifier entry**

1. **Incognito/private window**, or clear cookies for your app origin **and** your Clerk Account Portal host (`*.accounts.dev` or whatever matches `CLERK_SIGN_IN_URL`).
2. **Dashboard → User & authentication → Email, phone, username** — ensure **Email address** (or another identifier you expect) is **on** for sign-in. If only **Google** / Apple / etc. is enabled and your browser is already logged into that provider, Clerk may skip any “enter email” step entirely.
3. Open your hosted **`…/sign-in`** URL manually after a clean browser state — you should then see whatever strategies you enabled.

There is no separate Rails change required for this; it is how Clerk **development** + hosted vs handshake flows behave.

### Sign out in React vs Rails (two ports)

**`http://localhost:5173` (Vite) and `http://localhost:3000` (Rails) are different origins.** Signing out in the React app clears Clerk state for **5173**, not necessarily cookies on **3000**. Rails may still let you use **Sign in** quickly because of an existing **`localhost:3000`** session or your Clerk Account Portal session on **`*.accounts.dev`**.

Use **Sign out** on Rails as well, clear cookies for both hosts, or develop only against **`http://localhost:5173/billetto`** (unified SSO — one cookie jar).

---

## 3. Component paths (React — `/sign-in`, `/sign-up`)

The Vite app uses **embedded** Clerk on your origin:

- Sign-in route: `http://localhost:5173/sign-in`
- Sign-up route: `http://localhost:5173/sign-up`

In the dashboard:

1. Go to **Configure** → **Paths** (or **Customization** → **Application paths**).
2. Set paths so they match the React app (exact labels vary):
   - **Sign-in URL** → `/sign-in` or full URL `http://localhost:5173/sign-in`
   - **Sign-up URL** → `/sign-up` or full URL `http://localhost:5173/sign-up`
3. **Home URL** / application URL → `http://localhost:5173` is a good default for unified dev.

If Clerk shows validation errors, use the **full** `http://localhost:5173/...` form.

---

## 4. Allowed / fallback redirect URLs (required for both flows)

Rails and React both send users back with `redirect_url` or equivalent. Those destinations **must** be allowlisted.

Add entries for **development** (adjust if you only use one host):

| Purpose | Example values |
|--------|----------------|
| React + unified Rails proxy | `http://localhost:5173/**` or `http://localhost:5173/*` |
| Rails-only dev | `http://localhost:3000/**` |
| Same with `127.0.0.1` (if you use it) | `http://127.0.0.1:5173/**`, `http://127.0.0.1:3000/**` |

Where to set them (names vary by Clerk version):

- **Configure** → **Paths** → **Allowed redirect URLs** / **Redirect URLs**, or  
- **Account Portal** → **Redirects** / **Fallback redirect URL**, or  
- **Configure** → **Domains** → redirect allow list.

Include paths used after login:

- `http://localhost:5173/`  
- `http://localhost:5173/billetto` and `http://localhost:5173/billetto/` (unified SSO — see main README)  
- `http://localhost:3000/` (if you open Rails directly)

Wildcards (`**` or `*`) reduce churn when Clerk adds query strings.

---

## 5. Unified single sign-in (`localhost:5173` + `/billetto`)

1. Set **`RAILS_RELATIVE_URL_ROOT=/billetto`** in `external-api-integration/.env`.
2. Run Rails on **`127.0.0.1:3000`** and Vite on **`5173`** (see README / `Procfile.dev`).
3. In Clerk, ensure **`http://localhost:5173`** (and **`/billetto***) appear in allowed redirects (step 4).
4. Prefer **`http://localhost:5173`** in the browser (not mixing `localhost` and `127.0.0.1`), so cookies stay consistent.

The React app sets **`allowedRedirectOrigins`** for common dev origins (override with `VITE_CLERK_ALLOWED_REDIRECT_ORIGINS` in `clerk-react/.env`).

---

## 6. Production

- Use **Production** keys (`pk_live_…` / `sk_live_…`) and your **real domain(s)** in Paths and redirect allow lists.
- Serve Rails and the SPA under a clear URL strategy (same site or documented satellite setup); do not rely on `localhost` patterns.

---

## Quick checklist

- [ ] Same Clerk app for Rails + React keys  
- [ ] `CLERK_SIGN_*_URL` trio copied for Rails  
- [ ] Paths: `/sign-in`, `/sign-up` (or full `http://localhost:5173/...`)  
- [ ] Redirect allow list includes `5173` and `3000` (and `/billetto` if using unified dev)  
- [ ] Optional: `RAILS_RELATIVE_URL_ROOT=/billetto` + open `http://localhost:5173/billetto`
