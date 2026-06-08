# LIFT

A personal 4-day training app — color-coded gym companion with weight/rep logging, installable as a PWA, and wrappable as a native iOS app. Static and dependency-free.

---

## The day-to-day loop (how you'll actually use this)

1. **Coach the program with Claude in the Claude.ai chat.** That's where training decisions happen — voice notes, what hit, what flared, periodization, etc.
2. **Bring the locked-in change to Claude Code here.** e.g. *"update program.js: Tuesday — swap hack squat for pendulum squat, 3 sets."*
3. **Claude Code edits `program.js` and pushes.** Your phone app auto-updates on next open. No rebuild.

`program.js` is the single source of truth for the workout. Everything else is the app shell.

---

## One-time setup

### 1. Put it on GitHub (this repo becomes your live site)
From this folder:
```
git init
git add -A
git commit -m "LIFT initial"
```
Create an empty repo on github.com (e.g. `lift`), then:
```
git remote add origin https://github.com/YOUR-USERNAME/lift.git
git branch -M main
git push -u origin main
```
Enable Pages: repo **Settings ▸ Pages ▸** Branch **main** / **root** → Save.
Live URL (≈1 min later): `https://YOUR-USERNAME.github.io/lift/`

### 2. Point the native app at your live URL
Open `ios/LIFTApp.swift`, set `APP_URL` to your live URL, then build & install via Xcode (Signing & Capabilities ▸ your team ▸ Run to your iPhone with Developer Mode on). Content updates after this never need another Xcode build.

### 3. Set up Claude Code (recommended)
Requires **Node.js 18+** and a **Claude subscription** (Claude Code is included on the paid plans). Install (check the docs for the current method):
```
npm install -g @anthropic-ai/claude-code
```
Then run it inside this folder:
```
claude
```
First thing, tell it: **"read CLAUDE.md"** — it'll then understand the project and the deploy flow.
Docs: https://docs.claude.com/en/docs/claude-code/overview

---

## Local preview
Open `index.html` in a browser — the data loads via a `<script>` tag, so it works locally too.
(The PWA *install* + *offline* features only switch on when served over https, i.e. once it's on GitHub Pages — not from a local file.)

---

## File map
See **CLAUDE.md** for the full file map and the `program.js` data structure.
