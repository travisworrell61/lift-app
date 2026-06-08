# LIFT — context for Claude Code

## What this is
A personal 4-day hypertrophy/physique training app for a single user. Three layers, one repo:
- **Web app** — `index.html` (UI + render logic + logging engine) and the routine data (`program.json` live, `program.js` fallback).
- **PWA layer** — `manifest.webmanifest`, `service-worker.js`, icons. Makes it installable, offline-capable, and auto-updating.
- **Native iOS wrapper** — `ios/LIFTApp.swift`, a thin SwiftUI `WKWebView` that loads the hosted URL, plus a WidgetKit Lock Screen widget. Built/installed via Xcode (XcodeGen `ios/project.yml`) using the user's paid Apple Developer account.

It is intentionally a **static, dependency-free site** (no build step, no framework) so it stays trivially hostable on GitHub Pages and easy to edit. Keep it that way.

## The workflow — READ THIS
Training decisions are made by the user **in conversation with Claude in the Claude.ai chat** (voice notes, Q&A, periodization reasoning). They are **not** made here. Your job in Claude Code is to **apply locked-in changes and ship them**:

1. The user brings an already-decided change — e.g. *"swap Tuesday's hack squat for pendulum squat, 3 sets"*, *"bump side-delt volume on Friday."*
2. You produce the updated routine JSON (shape = the `program.json` object).
3. **It goes live with no rebuild.** The primary way the user ships it now is the **in-app "Update Program" screen** (long-press the LIFT logo → paste JSON → Publish), which POSTs to the Vercel `/api/program` endpoint and is live on all their devices within seconds. You can also commit `program.json` to GitHub as before — it's the fallback source.

**Live routine source order (see `loadProgram()` in index.html):** Vercel `/api/program` (in-app publish) → GitHub raw `program.json` → bundled `program.js`. The app caches the last-good copy.

> Keep `program.json` (GitHub) and `program.js` (bundled fallback) roughly in sync as the cold-start/offline copies, but the live edit path is now in-app publish → Vercel. The publish endpoint is secret-gated (`x-program-secret` = `PROGRAM_SECRET`, Vercel env only); the user enters that token once in the Update Program screen (stored on-device). Never commit it.

Occasionally you'll also tweak the UI in `index.html`, adjust the PWA files, regenerate icons, or edit the Swift wrapper — but the day-to-day is editing `program.json`.

## File map
- `index.html` — UI, the day/week renderer, the on-device logging+history engine, the runtime loader that fetches `program.json` (`PROGRAM_URL`), and the native bridges (`liftPushState` → widget, `liftSyncLogs` → cloud upload). Loads `program.js` via `<script src>` as the fallback. **Do not put workout data here.**
- `program.json` — **the live workout data**, fetched at runtime from raw.githubusercontent. `{ mon, tue, wed, fri }` as JSON. **Edit this to change routines.**
- `program.js` — bundled **offline / cold-start fallback** only (`var PROGRAM = { ... }` — `var`, so the live fetch can override it). Not the live source.
- `manifest.webmanifest` — PWA manifest (name "LIFT", icons, dark theme).
- `service-worker.js` — network-first SW (auto-update + offline). **If you add new same-origin files, add their paths to the `CORE` array here.** (The cross-origin `program.json` fetch is intentionally not cached by the SW.)
- `icon-192/512/180.png`, `favicon-32.png` — web/PWA icons.
- `ios/LIFTApp.swift` — native wrapper. `APP_URL` must be the hosted URL. Hosts the `lift` (widget state) and `liftSync` (log upload) message handlers.
- `ios/Secrets.swift` — **gitignored.** Holds the Vercel sync URL + WRITE_SECRET for native uploads. Never commit it (`ios/Secrets.example.swift` is the committed template).
- `ios/Shared/LiftStore.swift`, `ios/LIFTWidget/*` — App Group store + Lock Screen widget.
- `ios/project.yml` — XcodeGen project spec (run `xcodegen generate` in `ios/` after changing sources/targets).

## `program.json` data shape
```
{
  mon|tue|wed|fri: {
    n: <day number>, title: <string>, sub: <muscles string>,
    type: 'pri' | 'main',                 // priority day vs maintenance day
    warm: <warm-up string>,
    fin: { core: <string>, cardio: <string> },
    prog: { c: <hex color>, t: <HTML progression note> },
    A: [ block, ... ],                    // A-week
    B: [ block, ... ]                     // B-week
  }
}
block = {
  t: 'solo' | 'ss',                       // single lift, or a superset
  w: <where / label string>,
  e: [ [name, reps, note], ... ]          // exercises; a superset has 2+ entries
}
```
`program.json` may be a raw object (above) or wrapped as `{ "program": { ... } }` — the loader accepts both.

Conventions:
- `reps` strings look like `"4×8–10"`, `"3×12–15"`, `"3×10/leg"`, `"4 sets"`, `"Burnout"`, `"AMRAP"`. (En-dash `–`, multiplication `×`.)
- The UI auto-detects "uneven" supersets (entries with different set counts) and shows a yellow ⚠ note. **This is expected behavior, not a bug.** `setsOf()` reads the leading integer when the string contains `×`/`x` or "sets".
- **Logging is keyed by exercise NAME** (`e[0]`). If you rename an exercise, its logged history won't follow it. Keep names stable unless a reset is intended.

## Deploy
This repo *is* the GitHub Pages site (served from the repo root). To ship a change:
```
git add -A && git commit -m "describe the change" && git push
```
Pages rebuilds in ~1 minute. The PWA and the native app are network-first, so they fetch the new version on next open. Routine changes (`program.json`) never require an Xcode rebuild; Swift/widget changes do.

## Cloud sync — how it ACTUALLY works (read before touching sync)
Logs sync one-way to a Vercel backend so the **Claude.ai chat can read the user's progress**. The mechanism is **native push**, not a web-side write:

- **Upload path:** on each save, web calls `liftSyncLogs()` → posts the full log blob over the `liftSync` WKScriptMessageHandler → `ios/LIFTApp.swift` `uploadLogs()` does a `URLSession` `POST` to the Vercel endpoint. This only runs inside the **native app** (the bridge is a no-op in a plain browser/PWA).
- **Why native, not web:** the GitHub repo is **public**. The write credential must never live in committed web source. It sits in gitignored `ios/Secrets.swift` + the Vercel server env only.
- **API contract (deployed — `lift-sync-api`, a SEPARATE repo at `…/Desktop/CLAUDE PROJECTS/lift-sync-api`):**
  - WRITE: `POST /api/logs` with header `x-write-secret: <WRITE_SECRET>`, body = the raw logs object `{ "<exercise name>": [ {date,day,wk,sets:[{w,r}]} ] }`.
  - READ: `GET /api/logs?token=<READ_TOKEN>` → `{ updated, logs }`. The read URL (token embedded) is what the user pastes into the Claude.ai chat.
  - Read and write use **different** credentials (read token ≠ write secret) — by design, so the chat's read link can't write.
- **Not implemented (deliberately):** a web-side read/merge/write layer (PWA cross-device sync). It would require a write-capable token in public JS / on-device, which breaks the secret model above. If cross-device PWA sync is ever wanted, change the API + auth deliberately — don't bolt a `?token=` web write onto the current read-token API (the credentials don't match).
- The service worker ignores cross-origin requests, so the Vercel calls always hit the network.

## Lock Screen widget
- `liftPushState()` (web) posts the current day + exercise list + `currentIndex` over the `lift` bridge to `LiftStore` (App Group `group.com.travisworrell61.lift`); the widget reads it.
- "Current" exercise = first one not yet logged today (auto-advances as the user logs; Lock Screen widgets can't scroll).
- Changing widget/native code requires `xcodegen generate` + an Xcode rebuild.

## Don't
- Don't move workout data back into `index.html`.
- Don't introduce a framework, bundler, or build step — keep it static and dependency-free.
- Don't use `localStorage` beyond the existing logging + program-cache code (wrapped in `try/catch` with fallbacks — preserve that pattern). In particular `loadLogs()` loads from disk **once** then treats the in-memory `memStore` as the source of truth (write-through). Don't change it to re-read `localStorage` on every call — that reintroduces a bug where a failed write (private mode / quota) gets clobbered by a stale re-read.
- Logging UI is tap-first: weight uses ±5 steppers (still typeable for odd values), reps use chips auto-generated by `repTargets(repsString)` (reads the rep side after `×`). On save, weight-bearing rows are kept; for pure bodyweight sets (no weights at all) reps-only rows are kept. Keep that distinction so bodyweight exercises (AMRAP push-ups, pull-ups) still log.
- Don't commit secrets. `ios/Secrets.swift` is gitignored; verify with `git check-ignore ios/Secrets.swift` and grep tracked files before committing anything sync-related.
- Don't coach or redesign the program on your own initiative; program decisions come from the chat. Apply what the user brings.
