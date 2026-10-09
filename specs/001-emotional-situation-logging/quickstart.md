# Quickstart — Validation Guide

How to run the app and prove the feature works end to end. Each scenario maps to the spec's requirements; exact field rules live in [data-model.md](./data-model.md), routes in [contracts/http-api.md](./contracts/http-api.md), and the persistence format in [contracts/storage-file.md](./contracts/storage-file.md).

## Prerequisites

- Ruby 3.3+ and the Rails 8.x gem available.
- A desktop with a home directory (the JSON file is written to `~/Desktop` by default).
- No database, no network access needed (the app is fully offline).

## Setup

```bash
git clone <repo> && cd top_leaders   # or work in the existing checkout
bundle install
export SITUATION_LOG_FILE="$HOME/Desktop/emotional_situations.json"   # optional: this is the default
bin/rails server
```

Open `http://localhost:3000` in a browser. For a safe dry run, point `SITUATION_LOG_FILE` at a scratch path instead of the real desktop file.

## Automated tests

```bash
bin/rails test                # model, repository, controller, integration
bin/rails test:system         # guided-form happy path (needs a JavaScript-capable driver)
```

Expected: all green. The request tests cover RF-01..RF-08 and CRF-01..CRF-05 one-to-one (see the test names in `test/`).

## Manual validation scenarios (browser)

### S1 — Guided form (RF-01)

1. On the main screen, select "Registrar situación".
2. **Expected**: the form shows exactly the 5 questions in order: ¿Qué pasó? · ¿Qué significado le diste a lo que pasó? · ¿Qué emoción sentiste? · ¿Cómo fue de intensa? · ¿Cómo reaccionaste? Intensity renders as a 5-option radio group.

### S2 — Save a complete entry (RF-03, RF-04)

1. Fill all 5 fields (intensity 4).
2. Select "Guardar".
3. **Expected**: the detail screen appears with the Flash notice "Tu registro se guardó." within 2 s, showing all answers, plus actions "Registrar otra situación" and "Volver".
4. Open `~/Desktop/emotional_situations.json`.
5. **Expected**: the entry is present with a UUID, an ISO 8601 `logged_at`, `emotion_tag` lowercased/trimmed (e.g. `Tristeza ` → `"tristeza"`), and `"status": "saved"`.

### S3 — Validation (RF-02)

1. Open a new form; enter over-length text in "¿Qué pasó?" (> 2000 chars) — or via `curl -X POST` with `intensity=6`.
2. Select "Guardar".
3. **Expected**: the form re-renders with an inline error on the offending field; your typed answers are still there; nothing was written to the JSON file.

### S4 — Drafts (D4, RF-06)

1. Open a new form, answer only "¿Qué pasó?".
2. Select "Guardar borrador".
3. **Expected**: success notice; the entry exists in the JSON file with `"status": "draft"`.
4. While editing a partially filled form, try closing the tab.
5. **Expected**: the browser asks before discarding ("Tienes respuestas sin guardar").
6. Reopen the draft from "Mis registros" (it has a "Borrador" badge), add the emotion, select "Guardar".
7. **Expected**: the same entry now has `"status": "saved"`, and `updated_at` is newer than `logged_at`.

### S5 — List and detail (CRF-01..CRF-04)

1. Save 3 entries at different times (S2/S4 count).
2. From the main screen select "Mis registros".
3. **Expected**: entries ordered newest first; each row shows date/time, emotion, intensity "n/5", a short snippet of "¿Qué pasó?"; the detail shows every answer and never shows the UUID.
4. In a fresh data file (change `SITUATION_LOG_FILE` to a new path and restart), open "Mis registros".
5. **Expected**: empty state "Aún no tienes registros." with a "Registrar situación" action.

### S6 — Edit and delete (RF-08)

1. Open a saved entry, edit "¿Cómo reaccionaste?", save.
2. **Expected**: updated in the detail screen and in the JSON file after a page reload; `updated_at` changed.
3. Open a draft, delete it, confirm "¿Eliminar este registro?".
4. **Expected**: entry gone from the list and from the JSON file.

### S7 — Save failure (RF-05)

1. `export SITUATION_LOG_FILE="/proc/nope/entries.json"` and restart the server.
2. Fill the form, select "Guardar".
3. **Expected**: an error message appears, the form keeps your answers, and no success notice is shown.
4. Restore the real path and re-save; the entry persists.

### S8 — Persistence across restarts (RF-03, NFR-04)

1. Save an entry, stop the server (`Ctrl+C`), start it again.
2. **Expected**: the entry is still in "Mis registros" with identical content — local persistence is the whole storage story.

## Definition of done for this validation

S1–S8 pass in the browser, `bin/rails test` and `bin/rails test:system` are green, and the desktop JSON file matches [contracts/storage-file.md](./contracts/storage-file.md) at every step.
