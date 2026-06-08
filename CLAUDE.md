# LIFT — context for Claude Code

## What this is
A personal 4-day hypertrophy/physique training app for a single user. Three layers, one repo:
- **Web app** — `index.html` (UI + render logic + logging engine) and `program.js` (the workout data).
- **PWA layer** — `manifest.webmanifest`, `service-worker.js`, icons. Makes it installable, offline-capable, and auto-updating.
- **Native iOS wrapper** — `ios/LIFTApp.swift`, a thin SwiftUI `WKWebView` that loads the hosted URL. Built/installed via Xcode using the user's paid Apple Developer account.

It is intentionally a **static, dependency-free site** (no build step, no framework) so it stays trivially hostable on GitHub Pages and easy to edit. Keep it that way.

## The workflow — READ THIS
Training decisions are made by the user **in conversation with Claude in the Claude.ai chat** (voice notes, Q&A, periodization reasoning). They are **not** made here. Your job in Claude Code is to **apply locked-in changes and ship them**:

1. The user brings an already-decided change — e.g. *"swap Tuesday's hack squat for pendulum squat, 3 sets"*, *"bump side-delt volume on Friday"*, *"Wednesday rows drop to load-only."*
2. You edit **`program.js`** to match (that's the single source of truth for the program).
3. Commit and push. GitHub Pages redeploys (~1 min); the installed app pulls the new version on next open. **No app rebuild needed** for content changes (the service worker is network-first).

Occasionally you'll also tweak the UI in `index.html`, adjust the PWA files, regenerate icons, or edit the Swift wrapper — but the day-to-day is editing `program.js`.

## File map
- `index.html` — UI, the day/week renderer, and the on-device logging+history engine. Loads `program.js` via `<script src>`. **Do not put workout data here.**
- `program.js` — **the workout data.** `const PROGRAM = { ... }`. Edit this for any program change.
- `manifest.webmanifest` — PWA manifest (name "LIFT", icons, dark theme).
- `service-worker.js` — network-first SW (auto-update + offline). **If you add new files to the app, add their paths to the `CORE` array here**, or they won't be available offline.
- `icon-192/512/180.png`, `favicon-32.png` — web/PWA icons.
- `ios/LIFTApp.swift` — native wrapper. `APP_URL` must be the hosted URL.
- `ios/icon-1024.png` — app icon for the Xcode asset catalog.

## `program.js` data shape
```
const PROGRAM = {
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
Conventions:
- `reps` strings look like `"4×8–10"`, `"3×12–15"`, `"3×10/leg"`, `"4 sets"`, `"Burnout"`, `"AMRAP"`. (En-dash `–`, multiplication `×`.)
- The UI auto-detects "uneven" supersets (entries with different set counts) and shows a yellow ⚠ note telling the user how to run them. **This is expected behavior, not a bug.** `setsOf()` reads the leading integer when the string contains `×`/`x` or "sets".
- **Logging is keyed by exercise NAME** (`e[0]`). If you rename an exercise, its logged history won't follow it. Keep names stable unless a reset is intended.

## Deploy
This repo *is* the GitHub Pages site (served from the repo root). To ship a change:
```
git add -A && git commit -m "describe the change" && git push
```
Pages rebuilds in ~1 minute. The PWA and the native app are network-first, so they fetch the new version on next open. Content changes never require an Xcode rebuild.

## Don't
- Don't move workout data back into `index.html`.
- Don't introduce a framework, bundler, or build step — keep it static and dependency-free.
- Don't use `localStorage` beyond the existing logging code (which is wrapped in `try/catch` with an in-memory fallback — preserve that pattern).
- Don't coach or redesign the program on your own initiative; program decisions come from the chat. Apply what the user brings.
