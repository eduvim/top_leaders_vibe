# Data Model — Emotional Situation Logging and Analysis (MVP)

One entity, one value object, one repository. All persistence goes through `EntryRepository` to the JSON file described in [contracts/storage-file.md](./contracts/storage-file.md).

## Entity: SituationEntry

ActiveModel-backed plain Ruby class (no ActiveRecord). Field names below use the on-disk JSON keys; the Ruby class exposes snake_case accessors.

| Field | Type | Required | Rules (source) | Notes |
|---|---|---|---|---|
| `id` | UUID string | generated on create | RFC 4122, `SecureRandom.uuid` (spec §8) | Never shown in the UI (CRF-03); stable across edits |
| `what_happened` | text | optional (D3) | max 2000 chars, stripped (research §11) | Question 1: "¿Qué pasó?" |
| `meaning` | text | optional (D3) | max 1000 chars, stripped (research §11) | Question 2: "¿Qué significado le diste a lo que pasó?" |
| `emotion_raw` | text | optional (D3) | max 60 chars (research §11) | Exactly as the user typed |
| `emotion_tag` | text | derived | lowercase, stripped, inner whitespace collapsed (D2) | Derived from `emotion_raw` on save; the analysis-ready key |
| `intensity` | integer 1..5 or null | optional (D3) | `inclusion: { in: 1..5 }` when present (D1/RF-02) | `0`, `6`, non-integer → validation error |
| `reaction` | text | optional (D3) | max 2000 chars, stripped (research §11) | Question 5: "¿Cómo reaccionaste?" |
| `logged_at` | ISO 8601 timestamp | generated on create (D8) | server time, UTC, non-editable | Ordering key for CRF-02 (newest first) |
| `updated_at` | ISO 8601 timestamp | generated/refreshed on update | non-editable (RF-08) | Records date/time of the change |
| `status` | enum string | set by the save action | `saved` \| `draft` (D4) | See state transitions |

### Validation rules (RF-02)

- All questions optional (D3): an entry with every field blank is valid **as a draft**.
- Saving with `status: "saved"` requires `emotion_raw` to be present and valid — otherwise the save is refused and the entry can only be stored as a draft (research §11).
- Intensity: rejected if present and not an integer in 1..5 (D1). The UI offers only a 5-option radio group (research §12), so this is a server-side guard for non-UI writes.
- Over-length text (A1): rejected with a field-level error, data kept on screen.
- Tag normalization (D2) is applied before validation of `emotion_tag`: `Tristeza tras pelea ` → `"tristeza tras pelea"`.

### State transitions

```text
                     create via "Guardar borrador"
        (nothing) ───────────────────────────────────► [draft]
             │                                            │
             │ create via "Guardar"                       │ edit + "Guardar" (requires emotion)
             ▼                                            ▼
          [saved] ◄──────────────────────────────────── [draft]
             │        edit + "Guardar" (requires emotion)
             │
             │ edit + "Guardar borrador" (any content)
             ▼
          [draft]
```

- `draft → saved`: user edits and saves with at least the emotion answered (D4: "can be completed later").
- `saved → draft`: user edits an existing entry and explicitly saves it as a draft again (allowed; status is per save-action, not monotonic).
- Deletion (D5/RF-08) is available from either state and is final — the object is removed from the file after explicit confirmation in the UI.

## Value object: repository errors

`EntryRepository::StorageError` — raised when the JSON file cannot be read (corrupt JSON) or written (permission/disk). Carries a human-readable Spanish message; the controller maps it to the RF-05 failure path (research §7).

## Repository: EntryRepository (service)

The only component that touches the filesystem. Constructor takes the file path (default: `ENV["SITUATION_LOG_FILE"]` or `~/Desktop/emotional_situations.json`). Behavior:

| Operation | Contract |
|---|---|
| `all` | Returns every entry (saved + draft), newest `logged_at` first (CRF-02). Missing file → empty list. Corrupt file → `StorageError`. |
| `find(id)` | Entry or `nil` (controller maps `nil` to 404). |
| `create(entry)` | Assigns `id`, `logged_at`; appends; atomic write (temp file + rename). Returns the persisted entry. Raises `StorageError` on failure. |
| `update(id, entry)` | Refreshes `updated_at`; replaces by `id` in place; atomic write. Raises `StorageError`. |
| `destroy(id)` | Removes by `id`; atomic write. Raises `StorageError`. |

## Relationships

None. A single entity with no references — single user, no accounts, no relationships between entries (spec S1, S4).

## Storage

No database. Single JSON file, wrapper `{ "version": 1, "entries": [...] }`, atomic writes. Full schema, error semantics, and evolution policy: [contracts/storage-file.md](./contracts/storage-file.md).
