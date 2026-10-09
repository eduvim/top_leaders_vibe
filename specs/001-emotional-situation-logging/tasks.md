---
description: "Task list for feature implementation"
---

# Tasks: Emotional Situation Logging and Analysis (MVP)

**Input**: Design documents from `/specs/001-emotional-situation-logging/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included. plan.md and research.md (§14) commit to a test-first build: model/repository/request tests are written first and must FAIL before implementation. Each request test names its spec requirement (RF-xx / CRF-xx).

**Organization**: Tasks are grouped by user story. Priorities: US-01 (logging) is P1; US-02/US-03 (viewing, treated as one story — US-03 refines US-02 via module §11) is P2. US-01's edit/delete scope (AC6, RF-08) is sequenced after the viewing story because its actions live on the detail screen (research §9 CD5).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1, US2)
- All paths are repository-relative; the Rails app lives at the repo root (see plan.md Project Structure)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Rails application skeleton, no database, storage path configuration.

- [X] T001 Generate Rails 8 application at the repository root: `rails new . --skip-active-record --skip-git` (Gemfile, `bin/`, `config/`, `app/`). Verify with `bin/rails runner "puts :ok"`. Do not overwrite the existing `specs/` and `.specify/` directories.
- [X] T002 [P] Set Spanish as the default locale in `config/application.rb` (`config.i18n.default_locale = :es`) and confirm Rails boots with no database config (`--skip-active-record` removed ActiveRecord).
- [X] T003 [P] Create storage-path initializer `config/initializers/situation_log.rb`: resolves `ENV["SITUATION_LOG_FILE"]`, default `~/Desktop/emotional_situations.json` (research §3, contracts/storage-file.md).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Entry model, JSON repository, error handling, layout, and main screen — every user story depends on these.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 Write failing tests for the repository in `test/services/entry_repository_test.rb`: round-trip create/find/update/destroy; `all` returns newest `logged_at` first; missing file → empty list; corrupt JSON → `EntryRepository::StorageError`; writes are atomic; honors the path from `SITUATION_LOG_FILE` (uses `Dir.mktmpdir`, never the real desktop file).
- [X] T005 Implement `EntryRepository` in `app/services/entry_repository.rb` per `contracts/storage-file.md`: file format `{"version": 1, "entries": [...]}`, atomic write (temp file + rename in same directory), `StorageError` on unreadable/unwritable file, never overwrites a file it could not read (depends on T004).
- [X] T006 [P] Write failing tests for the model in `test/models/situation_entry_test.rb` covering data-model.md rules verbatim: intensity `inclusion: { in: 1..5 }` when present; optional when absent (D3); over-length rejection `what_happened ≤ 2000`, `meaning ≤ 1000`, `reaction ≤ 2000`, `emotion_raw ≤ 60` chars; `emotion_tag` derivation (lowercase, strip, collapse inner whitespace); valid-with-all-empty as draft; `status` only `"saved" | "draft"`; saving with `status: "saved"` requires `emotion_raw` present (research §11).
- [X] T007 Implement `SituationEntry` in `app/models/situation_entry.rb`: plain Ruby class with `ActiveModel::Model`, attributes `id`, `what_happened`, `meaning`, `emotion_raw`, `emotion_tag`, `intensity`, `reaction`, `logged_at`, `updated_at`, `status`; UUID via `SecureRandom.uuid`; `emotion_tag` assigned from `emotion_raw` on validation (depends on T006).
- [X] T008 [P] Create layout `app/views/layouts/application.html.erb` with the responsible-use notice partial `app/views/shared/_responsible_use_notice.html.erb`: "Esta aplicación es un registro personal de autoconocimiento. No sustituye la atención psicológica profesional." (NFR-06/D10, research §10).
- [X] T009 [P] Add storage-failure handling in `app/controllers/application_controller.rb`: `rescue_from EntryRepository::StorageError` → renders the RF-05 failure path (503, error message, no success notice).
- [X] T010 Define routes in `config/routes.rb`: `root "home#index"` and `resources :entries, only: [:new, :create, :index, :show, :edit, :update, :destroy]` per `contracts/http-api.md`.
- [X] T011 [P] Create main screen: `app/controllers/home_controller.rb` + `app/views/home/index.html.erb` with actions "Registrar situación" and "Mis registros" (RF-01, CRF-01).

**Checkpoint**: Foundation ready — `bin/rails test` green for T004/T006 suites; user story implementation can begin.

---

## Phase 3: User Story 1 — Log a situation (Priority: P1) 🎯

**Goal**: From the main screen the user opens the guided 5-question form, answers any subset, saves (or saves as draft), and receives an on-screen confirmation; failures keep all captured data.

**Independent Test**: quickstart.md scenarios S1 (form), S2 (save + JSON file), S3 (validation), S4 (drafts + unload guard), S7 (storage failure).

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation.** Each test names its spec requirement (RF-01..RF-06).

- [X] T012 [US1] Write failing request tests in `test/controllers/entries_controller_test.rb`: RF-01 `GET /entries/new` shows the 5 questions in order with Spanish copy; RF-02 intensity `6` → 422 with inline error and data preserved; RF-03 `POST /entries` persists to the JSON file with UUID, `logged_at`, `status: "saved"`, lowercased `emotion_tag`; RF-04 redirect to detail with Flash "Tu registro se guardó."; RF-05 storage error (unwritable `SITUATION_LOG_FILE`) → 503, form data preserved, no success flash; RF-06 `POST` with `commit=draft` and all fields empty → persisted with `status: "draft"`.
- [X] T013 [P] [US1] Write failing system test in `test/system/log_entry_test.rb`: main screen → "Registrar situación" → fill fields → radio intensity 4 → "Guardar" → confirmation visible; closing the tab with filled fields triggers the unload guard.

### Implementation for User Story 1

- [X] T014 [US1] Implement `new`/`create` in `app/controllers/entries_controller.rb`: strong params for all fields + `commit`; `commit=draft` allows all-empty (D3/D4); `commit=save` requires emotion (research §11); on validation error re-render form with params (422); on `StorageError` re-render with 503 (RF-05); redirect-to-detail with Flash on success (RF-04) (depends on T005, T007, T012).
- [X] T015 [P] [US1] Create form partial `app/views/entries/_form.html.erb`: 5 labeled questions in fixed order (¿Qué pasó? / ¿Qué significado le diste a lo que pasó? / ¿Qué emoción sentiste? / ¿Cómo fue de intensa? / ¿Cómo reaccionaste?); intensity as a radio group of 5 options with fieldset/legend ("1 — Muy leve" … "5 — Muy intensa"); inline field errors; two submit buttons "Guardar" and "Guardar borrador" (RF-01, RF-02, NFR-05).
- [X] T016 [P] [US1] Create `app/views/entries/new.html.erb` (renders the form) and `app/views/entries/show.html.erb` (confirmation target: Flash notice "Tu registro se guardó."/"Tu borrador se guardó.", the saved answers, actions "Registrar otra situación" and "Volver") (RF-04).
- [X] T017 [US1] Add the unload guard to `app/views/entries/_form.html.erb`: plain scriptlet warning before discarding a partially filled form ("Tienes respuestas sin guardar"); degrades silently without JS (RF-06, research §8) (depends on T015).

**Checkpoint**: US-01 works end-to-end alone (quickstart S1–S4, S7). This is the minimum demoable product.

---

## Phase 4: User Story 2/3 — View my entries (Priority: P2)

**Goal**: "Mis registros" shows all entries newest-first with row summaries and draft badges; each entry opens in a full-detail view; empty state guides the first log.

**Independent Test**: quickstart.md scenario S5 (list ordering, row content, detail fidelity, empty state).

### Tests for User Story 2/3

- [X] T018 [P] [US2] Write failing request tests in `test/integration/entries_view_test.rb`: CRF-01 list reachable from main screen; CRF-02 3 entries at different times render newest-first with date/time, `emotion_tag`, intensity "n/5", ~80-char snippet of `what_happened`, "Borrador" badge on drafts; CRF-03 detail shows all 5 answers (blank as "—") and never the UUID; CRF-04 empty file → "Aún no tienes registros." + "Registrar situación" action; unknown id → 404.

### Implementation for User Story 2/3

- [X] T019 [US2] Implement `index` in `app/controllers/entries_controller.rb` using `EntryRepository#all` (newest first) (depends on T018).
- [X] T020 [P] [US2] Create `app/views/entries/index.html.erb`: rows per CRF-02/CD4 (date/time, emotion, "n/5", snippet, "Borrador" badge), each row links to detail; empty state per CRF-04 (depends on T016 for shared styling conventions).
- [X] T021 [US2] Extend `app/views/entries/show.html.erb` to the full CRF-03 contract: all 5 answers with "—" for blanks, date/time, no UUID displayed.
- [X] T022 [US2] Wire "Mis registros" from the main screen in `app/views/home/index.html.erb` (CRF-01).

**Checkpoint**: With Phases 1–4 complete, the spec's MVP scope (logging plus view screen, research §15 item 5) is delivered — full quickstart S1–S5 + S8 pass.

---

## Phase 5: User Story 1 (completion) — Edit and delete (Priority: P3)

**Goal**: US-01 AC6 / RF-08 / D5: the user can edit any saved or draft entry and delete it after explicit confirmation, with change timestamps recorded.

**Independent Test**: quickstart.md scenario S6 (edit persists across reload with `updated_at` change; delete removes from list and JSON file).

> Sequenced after US-02 because the actions live on the detail screen (research §9 CD5).

### Tests

- [X] T023 [P] [US1] Write failing request tests in `test/integration/entry_edit_delete_test.rb` (RF-08): `GET /entries/:id/edit` prefills all fields; `PATCH` updates the field, refreshes `updated_at`, persists to JSON; `PATCH` with `commit=draft` downgrades a saved entry to draft; `DELETE` removes the entry from file and list; unknown id → 404; `StorageError` on update/delete leaves the original entry intact with an error message.

### Implementation

- [X] T024 [US1] Implement `edit`/`update`/`destroy` in `app/controllers/entries_controller.rb`: same validation/draft/storage semantics as `create` (contracts/http-api.md); Flash "Tu registro se actualizó." / "El registro se eliminó." (depends on T023).
- [X] T025 [P] [US1] Create `app/views/entries/edit.html.erb` reusing `app/views/entries/_form.html.erb`, prefilled, for saved and draft entries alike (D5).
- [X] T026 [US1] Add edit/delete actions to `app/views/entries/show.html.erb`: "Editar" and "Eliminar" buttons; delete asks "¿Eliminar este registro? Esta acción no se puede deshacer." before the destructive action (CD5) (depends on T021).

**Checkpoint**: All stories complete — quickstart S1–S8 pass end-to-end.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Quality concerns spanning all stories.

- [X] T027 [P] Extract all UI copy to `config/locales/es.yml` and reference it from views (S5, D-language consistency).
- [X] T028 [P] Add `.rubocop.yml` (Rails omakase defaults), run `rubocop`, fix offenses.
- [X] T029 Accessibility pass (NFR-05): verify every form control has a label, the intensity fieldset/legend is announced by a screen reader, all actions are keyboard-operable, and text contrast meets WCAG AA across `app/views/`.
- [X] T030 Performance check (NFR-03): with 500 seeded entries in `SITUATION_LOG_FILE`, verify save-to-confirmation and list load complete well under 2 s (quickstart timing).
- [X] T031 Run the full `specs/001-emotional-situation-logging/quickstart.md` validation (S1–S8) against the real desktop path and confirm `~/Desktop/emotional_situations.json` matches `contracts/storage-file.md` at every step.
- [X] T032 [P] Write `README.md`: prerequisites, `bundle install`, `SITUATION_LOG_FILE` configuration, `bin/rails server`, test commands, link to quickstart.md.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories.
- **US-01 logging (Phase 3)**: Depends on Phase 2 (T005 repository, T007 model, T009 error handling, T011 main screen).
- **US-02/03 viewing (Phase 4)**: Depends on Phase 2; builds its list/detail on top of the entry views created in Phase 3 (T016).
- **Edit/delete (Phase 5)**: Depends on Phase 4 (detail screen T021 hosts the actions).
- **Polish (Phase 6)**: After all desired stories are complete.

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD per research §14).
- Model/repository before controllers; controllers before views; views before wiring.
- Story complete and independently verified (quickstart scenarios) before moving on.

### Parallel Opportunities

- T002 and T003 in Phase 1 (different files).
- T004 and T006 (test files), T008, T009, T011 in Phase 2 (different files).
- T013 with T012, and T015/T016 with each other in Phase 3 (different files).
- T018 (Phase 4) and T023 (Phase 5) test files can be drafted in parallel once Phase 2 lands.
- T027, T028, T032 in Phase 6 (different files).

---

## Parallel Example: User Story 1

```bash
# After Phase 2 checkpoint, launch in parallel:
Task: "T012 [US1] Request tests RF-01..RF-06 in test/controllers/entries_controller_test.rb"
Task: "T013 [P] [US1] System test in test/system/log_entry_test.rb"

# Then implementation in parallel:
Task: "T015 [P] [US1] Form partial app/views/entries/_form.html.erb"
Task: "T016 [P] [US1] new/show views app/views/entries/new.html.erb, app/views/entries/show.html.erb"
```

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 (Setup) + Phase 2 (Foundational).
2. Complete Phase 3 (US-01 logging) → **STOP and VALIDATE** quickstart S1–S4, S7 — minimum demoable product.
3. Complete Phase 4 (US-02/03 viewing) → this completes the spec's MVP scope (logging plus view screen, research §15).
4. Complete Phase 5 (edit/delete) → full D5/RF-08 compliance.
5. Phase 6 polish, then the full quickstart S1–S8 validation.

### Incremental Delivery

Each phase ends at a checkpoint that adds user-visible value without breaking previous stories: foundation → log → view → edit/delete → polish.

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks.
- [Story] labels: US1 = spec US-01 (logging, incl. AC6 edit/delete in Phase 5); US2 = spec US-02/US-03 (viewing, module §11).
- Tests reference spec requirements by ID (RF-01..RF-08, CRF-01..CRF-05) for traceability.
- Verify tests fail before implementing; commit after each task or logical group.
- Never run tests against the real `~/Desktop/emotional_situations.json` — tests always set `SITUATION_LOG_FILE` to a temp dir.
