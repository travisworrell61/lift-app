# LIFT — Code-Side State & Data Contracts
### Production brief for the coaching chat (the one that writes the workouts)
_Purpose: so your program JSON + data files never contradict what the app now does. Read §3 (contracts) and §4 (what changed) most carefully._

---

## 1. The model, in one paragraph
LIFT is a **single-user, week-to-week** app. There is only ever *this* week — **no week numbers, no phases, no multi-week plan**. The app renders **your** data; Code owns rendering/logging/sync. **You own the data**: the published program JSON (`recs`, `plates`, `alts`, `exLib`, `plateMode`, `corePools`) and two bundled files (`exercise-library.json`, `equipment-catalog.json`). Code owns everything the athlete *does* with that data. Publishing is a **manual in-app paste** (Update Program → paste → Check → Publish), on Travis's clock.

---

## 2. What the app now does automatically (so you don't compensate in prose)
- **Notes render on every card** (the 3rd element of each exercise array). This is where your target/plate/cue text is shown mid-set.
- **Warm-up renders** on the day screen. `warm` used to be invisible — **it is now displayed to the athlete.** Write it for him, not as filler.
- **Target on the collapsed row**: each collapsed exercise shows `sets×reps · <target>` pulled from `recs` (plate → `/side`, DB → `lb`, stack/cable → bare number). No expand needed to scan the plan.
- **Weight box prefills the `recs` target** (editable), with last week shown as a reference.
- **Machine-aware logging**: the app knows each exercise's logging convention from `exercise-library.json` and handles per-side vs marked automatically.
- **Cable scale tags**: for `scale_tag_required` exercises the athlete picks the station; the tag is stored on the log entry and **never converted** across scales.
- **Add-Exercise on the fly**: a muscle-grouped picker sourced from `exercise-library.json`; bonus lifts log as real entries and **rehydrate** onto that day after restarts. A **"promote?" flag** appears after an added exercise recurs 3 sessions.
- **Day review**: progress reads "X/Y logged"; a "⚠ Not logged" chip lists misses (tap to backfill), and the core-timer's "Workout Complete" screen does the same.
- **Logged state survives restarts** (week-scoped, see §4).
- **Core timer** (Mon/Wed): randomized circuit, Randomize re-roll, total-duration readout, spoken transitions.

---

## 3. DATA CONTRACTS you must honor

### 3a. Program JSON — publish shape
All four days (`mon`, `tue`, `wed`, `fri`). Each day:
```
{ "title": "...", "sub": "...", "warm": "...", "fin": { "core": "...", "cardio": "..." },
  "prog": { "c": "#hex", "t": "day-overview text" },
  "A": [ block, block, ... ] }
```
Block: `{ "t": "solo" | "ss", "w": "muscle/context label", "e": [ exercise, ... ] }`
Exercise array: `[ name, reps, note, tags? ]`
- `warm` is **required and now shown** — real warm-up text.
- `note` (3rd element) is **shown on the card** — put target load, plate math, and the technique cue here.
- `w` (block label) is **shown** ("● Solo · <w>", "SUPERSET · <w>"). Don't leave it undefined.
- Optional 4th `tags` → **amber card highlight + badges** (`dropset`, `partials`, `restpause`, `amrap`, `failure`, `tempo`). The tagged exercise now gets an amber border/tint so the special set in a block stands out at a glance (Ticket 24). Append it as `[name, reps, note, ["dropset"]]`.

### 3b. `recs` — day-nested target numbers (drives prefill + collapsed-row target)
```
"recs": { "mon": { "Exact Exercise Name": 60 }, "tue": {…}, "wed": {…}, "fri": {…} }
```
- Numbers in the **logging convention**: per-side for plate machines, total for stacks/DBs/fixed bars — i.e. exactly what gets logged.
- **Omit bodyweight moves** (no rec → the card stays a "Mark done" card).

### 3c. `plates` — day-nested per-side display strings (display only)
```
"plates": { "fri": { "Exact Exercise Name": "45 + 35 + 5/side" } }
```
- Present **only** for plate-loaded moves. Never for DBs/cables/stacks/bodyweight.

### 3d. Naming rules (exact-name keying — this is the #1 source of silent breakage)
- `recs`, `plates`, `alts`, `exLib`, `plateMode` all key by the **exact** exercise name — it must match the exercise array's `name` byte-for-byte (spaces, `·`, `—`, quotes, parens).
- **`" / "` (space-slash-space) is RESERVED** — it triggers the variant selector (two interchangeable machines). Don't use it in a non-alternate name.
- **`·` and `→` are never split** — safe to use inside a name.
- Reps set-count is parsed as the number before `×`/`sets`; a **range uses the TOP** (`2–3×…` → 3 rows) so the athlete never under-logs (Ticket 24). Keep `N×…`/`N sets`/`N–M×…` forms.
- The publish **Check also lints for HTML outside `prog.t`** — a `<b>`/`<span>`-shaped string anywhere else warns (it would render as literal text). Plain `<45°` / `(<60s rest)` prose never warns. `prog.t` remains the only rich-text field.
- The publish **Check now validates the day-nested `recs`/`plates`** and warns on inner names that don't match a real exercise (and on `plates` too). If it warns, it's a typo — fix it. (It no longer false-warns on `mon`/`tue`/`wed`/`fri`.)

### 3e. `exercise-library.json` — you own the content; Code bundles + fetches it
Groups by muscle in **array order = display order** in the picker. Each exercise:
```
{ "name", "implement", "convention", "in_program", "default_equipment"?, "scale_tag_required"?, "note" }
```
- `convention` = `per_side` | `as_marked` | `bodyweight`. Drives how an **added** exercise logs.
- `default_equipment` is now the **scale-tag HOME default** — it must name the athlete's **home** station (e.g. "Hoist CMJ-6175 …" → defaults `hoist_cmj`). **Do NOT name the fallback machine here** (that caused the versa mistags).
- `scale_tag_required: true` → the card shows the cable-station picker.
- `note` shows on the added card.
- To add a movement: append to the right group's `exercises[]` and hand me the file (or I'll re-bundle on request). **I just added `Incline Cable Fly`** (Upper Chest, cable, `scale_tag_required`, defaults hoist) per Ticket 22.

### 3f. `equipment-catalog.json` — you own the content
Each line: `scale_tag`, `type`, `convention`, `default_equipment`, `ratio`. Cable scales in play: `hoist_cmj` (~1:1, HOME), `versa` (1:2, fallback), `matrix_g3ms53` (**ratio TBD**).
- **Tag-and-store only — the app NEVER does ratio math.** A number difference across tags is not a strength change.
- When you lock the `matrix_g3ms53` ratio, update the catalog note and tell me — but the app still won't convert; it just stores the tag.

### 3g. `corePools` — Mon/Wed core timer (optional; falls back to bundled pools)
```
"corePools": { "weightedPool": [ {ex, sec, pair?, pairLabels?, note?} ], "bodyweightPool": [ … ] }
```
- Monday = **guaranteed** (CORE_TARGET-2)=**4 weighted + 2 bodyweight** intervals; Wednesday = 6 bodyweight. A `pair` move = **2 intervals**. `CORE_TARGET` is 6 (Code constant — ask if you want it changed).

---

## 4. What CHANGED recently — stop fighting the old behavior

1. **scale_tag default is now the HOME station (`default_equipment`), never last-used.** So: (a) you can stop compensating in notes for the Versa skew; (b) the real mistagged entries (Overhead Extension / Rope Pushdown on 6/29, 7/03, 7/06 read `versa` but were Hoist) can be **corrected in-app** — the athlete taps the tag badge in an exercise's History to cycle stations. Operating rule going forward: **assume home machines; the athlete flags exceptions.**
2. **Note dates are fixed.** A note now keys to the **session's real logged date**, not the tab's nominal date (the `07-07|tue` vs `07-08` skew is gone going forward; old notes untouched). A note typed *before* the first set migrates onto the lifts' date on save.
3. **Per-side is ONE UI: a numeric box for "one side's number."** There is **no plate picker** for per-side program exercises anymore (it stored the doubled total and could double-log). The plate breakdown comes from your `plates` string (display), not a picker. So `recs` per-side numbers = one side; that's what's stored.
4. **Bodyweight is triggered by the REPS field, not the name.** Use `AMRAP`, `… × burnout`, or `to failure` in reps to make a move bodyweight (no weight box, "Mark done"). Putting "burnout" in the *name* does **not** trigger it (so "Standing DB Lateral · burnout" correctly stays weighted).
5. **Logged state is week-scoped, not "today".** A day counts as logged if there's an entry for (this Mon–Sun week, that day, variant). This makes completed days rehydrate and lets a session slide a day (Tuesday's legs done Wednesday) without losing state. **Weekend note:** on Sat/Sun the tabs now show the week just trained (for review/backfill), not a preview of next week.
6. **A notes-only sync can no longer wipe the log history** (server now merges). Your reads of the blob are safe.

---

## 5. Division of labor (don't try to change these via data — send a ticket)
- **You (coaching chat) own:** program content, `recs`/`plates`/`alts`/`exLib`/`plateMode`/`corePools`, and the two `*.json` data files. Program swaps happen only when Travis pastes.
- **Code owns:** rendering, the weight logger, week-slot logging + rehydration, the day review, the picker, machine-aware logging, the scale-tag store, the core timer, sync, and the native shell. You cannot change these through the program JSON — if you want a behavior change, write a ticket (same as 06–22).
- `w:null` = done/no-load; `p` = per-side plate breakdown on a log entry; `v` = chosen variant; `scale_tag` = cable station; `added:1` = a bonus (non-program) lift — it drives the promote-after-3 flag, read it as "athlete chose this on his own".

---

## 6. Deployment reality (FYI)
- Program/data changes ship via **paste-publish** (Vercel) and take effect on the app's next open. The `program.json` GitHub fallback can drift stale — **I refresh it when I'm in the code; not your concern.**
- The **latest native install** (in progress) adds offline caching (service worker) — invisible to you; no data impact.

---

**Bottom line for you:** keep names exact, put targets in `recs` (per-side numbers for plate machines) and plate strings in `plates`, put the HOME station in `default_equipment`, use AMRAP/burnout in reps for bodyweight, write real `warm` text, and let the app handle conventions/tags/rehydration. Everything 06–22 is shipped and consistent with the above.
