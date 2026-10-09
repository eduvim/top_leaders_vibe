# Research — Emotional Situation Logging and Analysis (MVP)

Phase 0 output. Resolves the spec's pending decisions (D7–D10, CD1–CD5), its ambiguities (A2, A4, A5), and the technical unknowns of the chosen stack (Rails, no database). Each item follows Decision / Rationale / Alternatives considered.

## 1. Platform and stack (spec: no platform decision; user input)

- **Decision**: Ruby on Rails 8.x web application, generated with `--skip-active-record`, running locally (`bin/rails server`, `http://localhost:3000`). No database: persistence is a single JSON file on the user's desktop (D6).
- **Rationale**: User-selected direction ("Rails app, without a db"). Rails gives routing, form helpers, validations (ActiveModel), Flash-based confirmations, and a test framework for free, while `--skip-active-record` removes the DB entirely. A local server can write directly to `~/Desktop` with plain `File` I/O, which a browser-only solution cannot do reliably.
- **Alternatives considered**: Desktop GUI (Tauri/Electron — heavier build chain for a personal MVP); CLI (cheapest, but the spec's UX is screen-based: main screen, list, detail); static page with File System Access API (no server, but browser permission prompts contradict "save silently to desktop" and complicate RF-03/RF-05).

## 2. Rails without ActiveRecord: persistence pattern

- **Decision**: `SituationEntry` is a plain Ruby class including `ActiveModel::Model` (attribute API, validations, naming) with no persistence duties. A single `EntryRepository` service owns the JSON file: `all` (newest first), `find(id)`, `create(attrs)`, `update(id, attrs)`, `destroy(id)`. The app is generated with `--skip-active-record`, so no `config/database.yml` and no DB adapters at all.
- **Rationale**: Keeps the model unit-testable without touching the filesystem and isolates all I/O behind one class with a documented contract (`contracts/storage-file.md`). ActiveModel's validations implement D1/D2/D3 rules exactly like an ActiveRecord model would, so controllers and views stay idiomatic Rails.
- **Alternatives considered**: ActiveRecord + SQLite (rejected — user explicitly wants no DB; D6 mandates the JSON file as the storage interface); a JSON-backed `ActiveModel` with dirty-tracking callbacks (rejected — over-engineering for this scale); storing each entry as its own JSON file (rejected — D6 says "a single JSON file").

## 3. JSON file format, location, and atomic writes (spec §8: "file format to be defined")

- **Decision**: File at `~/Desktop/emotional_situations.json` by default, overridable via `SITUATION_LOG_FILE` env var (tests point it at `Dir.mktmpdir`). Wrapper: `{ "version": 1, "entries": [ ... ] }` where `entries` is an array of entry objects in insertion order. Every write is atomic: serialize to a temp file in the same directory, `FileUtils.mv` (rename) over the target. Reads parse the whole file; a missing file yields an empty list; a corrupt file raises a repository error that the controller maps to the RF-05 failure path.
- **Rationale**: D6 pins "single JSON file on the user's desktop". The `version` wrapper makes future format evolution (e.g., the analysis module, D9) possible without breaking existing files. Atomic rename prevents a crash mid-write from corrupting the user's emotional log (risk R5 — data loss). The env var keeps tests hermetic and never touching the real desktop file.
- **Alternatives considered**: Append-only NDJSON (simpler writes, but D6 says one JSON file and reads would need full-file parsing anyway); write-through with `.bak` backup (rejected — rename is atomic and sufficient; a backup can be added later if R5 materializes).

## 4. Timestamps (spec D8)

- **Decision**: `logged_at` is recorded automatically on create (server time, ISO 8601 UTC in the file; rendered in local time). `updated_at` is recorded on every edit (RF-08 requires the change timestamp). Neither is user-editable in this MVP; there is no event date/time field (consistent with S2).
- **Rationale**: RF-03/RF-08 and CRF-02 need reliable, non-spoofable timestamps for ordering; S2 states the user logs at/near the moment of the event. Editable timestamps add UI friction (risk R2) with no MVP benefit.
- **Alternatives considered**: Editable auto-timestamp (deferred to a future version if users backfill old situations); client-side timestamps (rejected — server time is trustworthy and testable).

## 5. "Available for later analysis" = view list + detail (spec D7, A3)

- **Decision**: D7 resolves to **list + detail**, exactly as module §11 specifies: a "Mis registros" screen lists entries newest-first (CRF-02) and each row opens the full 5 answers (CRF-03). Statistics, trends, and keyword analysis stay out (D9 → roadmap).
- **Rationale**: Module §11 already specifies this scope; it is the minimum that satisfies RF-07 and US-02/US-03 while keeping the analysis module a clean future addition over the same JSON file.
- **Alternatives considered**: Statistics dashboard (explicitly deferred by D9); raw file only (fails CRF-01..CRF-05).

## 6. Confirmation mechanism (spec A2)

- **Decision**: An on-screen Flash/Turbo notice ("Tu registro se guardó") rendered on the next screen (list or main screen), i.e., a server-rendered confirmation, no sound, no OS notification.
- **Rationale**: A2 requires a *visible* mechanism; Flash is idiomatic Rails, instant (NFR-03 < 2 s), works offline, and needs no JS. Sound/notifications add permission handling and aren't part of the value proposition.
- **Alternatives considered**: Toast + stay on form (requires JS state; deferred); desktop notification (needs native bridge, out of scope).

## 7. Save failure handling (spec A4, RF-05)

- **Decision**: `EntryRepository` raises `EntryRepository::StorageError` on any write/parse failure. `EntriesController` rescues it: re-renders the form with the user's data intact, shows an inline error ("No se pudo guardar tu registro. Tus respuestas siguen en pantalla. Inténtalo de nuevo."), and never shows the success notice. A test injects an unwritable path to verify the path end-to-end.
- **Rationale**: Directly satisfies RF-05 and risk R5 (silent data loss is the worst outcome for an emotional log). Rendering the form with populated `params` is the standard Rails pattern and keeps captured data on screen.
- **Alternatives considered**: Background retry queue (over-engineering for a local single-user app); writing to a fallback file (masks the failure the spec wants surfaced).

## 8. Interrupting an entry / drafts (spec A5, RF-06, D4)

- **Decision**: The form has two explicit actions: "Guardar" (saves with `status: "saved"`) and "Guardar borrador" (saves with `status: "draft"`, allowed even with every field empty). Leaving the form with any field filled triggers a lightweight `beforeunload` guard ("Tienes respuestas sin guardar") that offers to stay or discard; the guard is a plain scriptlet, degrades silently if JS is off. Drafts appear in the list with a "Borrador" badge and are completed by editing and saving normally.
- **Rationale**: RF-06 demands the user never loses data without consent and is *offered* draft-saving. A server-rendered app cannot intercept a browser close server-side, so the consent point must be client-side (`beforeunload`) plus an explicit draft button for the low-friction path. Empty draft save satisfies RF-02/RF-03 QA cases.
- **Alternatives considered**: Auto-save every keystroke to the file (rejected — constant disk writes and "when was it really saved?" ambiguity); skip the `beforeunload` guard (fails RF-06 for accidental tab close); client-side localStorage drafts (splits the draft state between two storages, contradicting D6's single-file rule).

## 9. List behaviors (spec CD1–CD5)

- **Decision**:
  - CD1: no pagination/scroll mechanics in MVP — the full list is rendered newest-first; personal volume (see plan.md Scale/Scope) makes this fine. Revisit if the file exceeds a few thousand entries.
  - CD2: no filters in MVP.
  - CD3: no text search in MVP.
  - CD4: each row shows date/time, normalized emotion, intensity (e.g., "4/5"), and a one-line snippet of "¿Qué pasó?" (truncated at ~80 characters), plus a "Borrador" badge when applicable.
  - CD5: edit and delete live on the detail screen; delete asks for confirmation ("¿Eliminar este registro? Esta acción no se puede deshacer.") before the destructive action.
- **Rationale**: Every deferred option (pagination, filters, search) is analysis-module territory (D9) and would grow the data layer (indexes, query logic) the MVP doesn't need. Row content satisfies CRF-02's "at minimum date/time, emotion, intensity" and adds the snippet because a list of bare dates has poor recall value. Delete confirmation protects against accidental loss of an emotional record (risk R1/R5).
- **Alternatives considered**: "Load more" button (premature — no evidence of that volume); filters by emotion/intensity/date (deferred with D9); inline list actions (rejected — cramped rows; detail is where D5 actions belong).

## 10. Responsible-use notice (spec D10, NFR-06, risk R4)

- **Decision**: Yes. A short, visible, dismissible-per-session notice in the layout: "Esta aplicación es un registro personal de autoconocimiento. No sustituye la atención psicológica profesional." Shown on the main screen and entry screens.
- **Rationale**: NFR-06 already requires it and R4 flags therapeutic expectation as a real risk; the cost is one partial in the layout.
- **Alternatives considered**: No notice (rejected — NFR-06 stands); first-run modal only (weaker than a persistent, visible notice).

## 11. Emotion tags (spec D2, risk R3) and field limits (spec A1)

- **Decision**: The user types one main emotion (S1) as free text in a single field. The entry stores the raw text plus a normalized tag: lowercase, stripped, inner whitespace collapsed to single spaces (tags are not split into multiple values in this MVP — one emotion per entry per S1). Max lengths: `what_happened` ≤ 2000, `meaning` ≤ 1000, `reaction` ≤ 2000, `emotion` raw ≤ 60. All questions remain optional except: saving as a **completed** entry requires at least the emotion (S1's "single main emotion") — a save with all fields empty (or no emotion) becomes a draft, never an error (D3/D4).
- **Rationale**: D2 mandates normalizable tags so later analysis (D9) can group; normalization at write time keeps the file analysis-ready (R3). Limits are generous enough for a guided log, bound the JSON file, and resolve A1's undefined limits. "No emotion → draft, not error" honors D3 (all optional) while keeping `status: "saved"` meaningful: a saved entry always has the one field that makes later analysis groupable.
- **Alternatives considered**: Multi-tag emotions (contradicts S1's singular question; deferred to the analysis roadmap); a pick-from-catalog dropdown (rejected — D2 explicitly chose free text; a catalog can be *suggested* later without schema change); no limits (unbounded file growth, fails A1).

## 12. Intensity input (spec D1, RF-02)

- **Decision**: A radio group of 5 options (1–5) rendered with labels ("1 — Muy leve" … "5 — Muy intensa"), server-validated as an integer in 1..5; empty is allowed. No free-text number field.
- **Rationale**: Radio buttons are keyboard/screen-reader navigable (NFR-05), make the 1–5 domain impossible to violate in the UI, and still validate server-side for non-UI writes (RF-02 QA case: `0`, `6`, text). This lowers friction (risk R2) versus typing.
- **Alternatives considered**: Number input (permits 0/6/typo; validation error friction); slider (poor screen-reader/keyboard ergonomics for 5 discrete values).

## 13. Privacy (spec NFR-01, S4, CS1, CRF-05)

- **Decision**: Single-user local app, no accounts. The app binds to `localhost` by default; the JSON file is user-owned on their desktop. CRF-05 is satisfied structurally: there is exactly one profile, so no cross-profile visibility is possible. No telemetry, no external requests; Rails' default CSP and `force_ssl` stay off (offline, local).
- **Rationale**: D6/S4/S6 define the product as single-user local. CRF-05's "two profiles" QA case degenerates to "there is no second profile" — the QA verification is a configuration assertion, not a runtime multi-tenancy feature.
- **Alternatives considered**: At-rest encryption (rejected for MVP — adds key management to a personal tool; flagged in plan as a roadmap item if the threat model grows); a PIN-gated file (deferred, same reason).

## 14. Test-first workflow (speckit default gate)

- **Decision**: Build order per component: (1) `SituationEntry` model tests (D1–D4 rules: intensity range, tag normalization, max lengths, draft-on-empty), (2) `EntryRepository` tests (round-trip, atomic write, corrupt-file error, env-var path), (3) request tests per RF (RF-01..RF-08, CRF-01..CRF-05 mapped one-to-one), (4) one system test for the guided form happy path. UI manual QA walkthrough lives in `quickstart.md`.
- **Rationale**: The repo starts empty; the spec's Given/When/Then blocks translate almost verbatim into Minitest request tests, giving traceability from requirement to test.
- **Alternatives considered**: RSpec (fine, but adds gems to a dependency-free MVP — Minitest ships with Rails); only system tests (slower, more brittle, less traceable).

## 15. Answers to the spec's open questions (§12)

1. D7–D10 and CD1–CD5: resolved in items 4–11 above; the "duplicated flow" in the original process is treated as an accidental duplicate (spec §4 already interprets it this way) — consecutive logging is naturally supported since the confirmation screen offers "Log another situation" (RF-04).
2. Regulatory/privacy: treated as personal non-clinical data, not a medical device (notice in item 10); formal legal review is out of scope of this plan.
3. UI/UX design: none exists; screens start from scratch using Rails defaults plus the copy in the spec (Spanish, see `contracts/http-api.md`).
4. MVP = logging **plus** view screen (module §11 is in scope); the analysis module is not.
