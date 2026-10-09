# Implementation Plan: Emotional Situation Logging and Analysis (MVP)

**Branch**: `001-emotional-situation-logging` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-emotional-situation-logging/spec.md`

## Summary

A single-user local web application to log emotional situations through a guided 5-question form, save them with draft support to a JSON file on the user's desktop, and view them later in a newest-first list with full detail, editing, and deletion. The application is a Ruby on Rails app **without a database**: entries are persisted by a small repository class to a single JSON file (D6), using ActiveModel for validations and ERB + Turbo for the Spanish-language UI.

## Technical Context

**Language/Version**: Ruby 3.3+ (Rails 8.x, created with `--skip-active-record`)

**Primary Dependencies**: Ruby on Rails (ActionPack, ActionView, ActiveModel — no ActiveRecord), Turbo Drive (bundled). No JS framework, no additional gems beyond the Rails default set.

**Storage**: No database. A single JSON file on the user's desktop (default `~/Desktop/emotional_situations.json`, overridable via `SITUATION_LOG_FILE` env var), written atomically (temp file + rename). Schema and wrapper format defined in [contracts/storage-file.md](./contracts/storage-file.md).

**Testing**: Rails' built-in Minitest (`test/models`, `test/controllers`, `test/integration`, `test/system`). TDD: model and repository tests first, request tests for each RF, one lightweight system test for the guided form flow.

**Target Platform**: Local machine; user runs `bin/rails server` and opens `http://localhost:3000`. Works fully offline (NFR-04).

**Project Type**: Local web application (single user, no accounts, no cloud).

**Performance Goals**: Save + confirmation under 2 s (NFR-03); page loads well under that for a single-user local app with a small JSON file (hundreds of entries read in-memory per request is acceptable at this scale).

**Constraints**: Offline-capable; entries never leave the device (NFR-01); UI language Spanish (S5); keyboard/screen-reader navigable forms, sufficient contrast (NFR-05).

**Scale/Scope**: One user, personal volume (a few entries per week, expected lifetime total in the hundreds to low thousands — in-memory read of the JSON file per request is fine; no pagination required for MVP, see research.md CD1).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is currently an **unfilled template placeholder** — no project-specific principles or gates have been ratified. No violations are possible against a placeholder; the following speckit defaults apply for this plan (and `/speckit-constitution` should be run to ratify real principles):

| Default gate | Status | Notes |
|---|---|---|
| Simplicity / YAGNI | PASS | Single Rails app, no DB, no extra dependencies, no filters/search/pagination in MVP. |
| Test-first | PASS | Model, repository, and request tests are written before implementation (see research.md and quickstart.md). |
| Clear contracts | PASS | HTTP routes and the JSON storage file format are documented in `contracts/`. |
| Complexity justified | PASS | No violations to justify; "Complexity Tracking" left empty. |

**Post-Phase-1 re-check**: design re-evaluated after `research.md`, `data-model.md`, `contracts/*`, and `quickstart.md` were produced. Still no project-specific gates (constitution remains a placeholder); the speckit defaults above still pass — the design added no dependencies, one entity, one repository, and two documented contracts, with every deferred feature (filters, search, statistics) explicitly out of MVP scope.

## Project Structure

### Documentation (this feature)

```text
specs/001-emotional-situation-logging/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── http-api.md      # Rails routes / request-response contract
│   └── storage-file.md  # JSON persistence file contract (the "later analysis" interface)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
├── app/
│   ├── models/
│   │   └── situation_entry.rb      # ActiveModel (no DB): fields, validations, states
│   ├── services/
│   │   └── entry_repository.rb     # JSON-file persistence: all CRUD, atomic writes
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── home_controller.rb      # Main screen (RF-01 entry point)
│   │   └── entries_controller.rb   # Form, save, list, detail, edit, delete
│   ├── views/
│   │   ├── home/index.html.erb     # Main screen
│   │   ├── entries/_form.html.erb  # Guided 5-question form
│   │   ├── entries/index.html.erb  # "Mis registros" list (CRF-01..CRF-05)
│   │   ├── entries/show.html.erb   # Entry detail
│   │   └── layouts/application.html.erb  # Responsible-use notice (NFR-06/D10)
│   └── helpers/
├── config/routes.rb
├── test/
│   ├── models/situation_entry_test.rb
│   ├── services/entry_repository_test.rb
│   ├── controllers/entries_controller_test.rb
│   ├── integration/entry_flow_test.rb
│   └── system/guided_form_test.rb
└── (storage path configured via SITUATION_LOG_FILE, default ~/Desktop/emotional_situations.json)
```

**Structure Decision**: Single Rails application (no `backend/`/`frontend/` split — the app is server-rendered ERB + Turbo). `SituationEntry` is a plain ActiveModel class (no ActiveRecord; the app is generated with `--skip-active-record`), and `EntryRepository` is the only component that touches the JSON file, isolating persistence behind one contract. The repository writes to `~/Desktop` per D6, configurable by env var so tests never touch the real file.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations — empty by design.
