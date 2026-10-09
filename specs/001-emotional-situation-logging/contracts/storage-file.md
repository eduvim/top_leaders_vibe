# Contract — JSON Storage File

This file is itself an interface: the spec (D6, RF-07, D9) guarantees entries stay available in a single local JSON file for later review and a future analysis module. Anything that reads this file — the app, the user, a future analysis tool — is a consumer of this contract.

## Location and naming

- Default path: `~/Desktop/emotional_situations.json` (D6: "on the user's desktop").
- Override: `SITUATION_LOG_FILE` env var with an absolute path (used by tests; also lets a user relocate their journal).
- The app creates the file on first save if it does not exist; it never deletes it implicitly.

## File format

UTF-8 JSON, pretty-printed (2-space indent) so the file is human-readable, with a trailing newline.

```json
{
  "version": 1,
  "entries": [
    {
      "id": "b7e6f5a2-0c4d-4e1f-9a3b-2d5c8f0a1e77",
      "what_happened": "Discutí con mi hermano por un mensaje que malinterpreté.",
      "meaning": "Pensé que no me tomaba en cuenta.",
      "emotion_raw": "Tristeza",
      "emotion_tag": "tristeza",
      "intensity": 4,
      "reaction": "Dejé de responderle el resto del día.",
      "logged_at": "2026-10-08T22:41:07Z",
      "updated_at": "2026-10-08T22:41:07Z",
      "status": "saved"
    }
  ]
}
```

| Key | Type | Constraints |
|---|---|---|
| `version` | integer | Format version. This MVP writes and reads `1`. |
| `entries` | array | Entry objects in insertion order; consumers must not assume order — sort by `logged_at` for display. |

## Entry object schema

| Key | Type | Constraints |
|---|---|---|
| `id` | string (UUID v4) | Unique across the file. Immutable. |
| `what_happened` | string or absent | ≤ 2000 chars. Absent/null if the question was skipped. |
| `meaning` | string or absent | ≤ 1000 chars. |
| `emotion_raw` | string or absent | ≤ 60 chars. User's original wording. |
| `emotion_tag` | string or absent | Derived from `emotion_raw`: lowercase, stripped, inner whitespace collapsed. Absent if `emotion_raw` absent. |
| `intensity` | integer 1..5 or absent/null | Absent or null if not answered. Never 0, never > 5. |
| `reaction` | string or absent | ≤ 2000 chars. |
| `logged_at` | string, ISO 8601 UTC | Set on create; never changes. |
| `updated_at` | string, ISO 8601 UTC | Set on create; refreshed on every edit (RF-08). |
| `status` | string | `"saved"` or `"draft"`. |

## Write guarantees

- **Atomicity**: every write serializes the full document to a temp file in the same directory and renames it over the target. A reader never observes a partially written file; a crash mid-write leaves the previous file intact (risk R5).
- **Single writer**: one local user, one server process; the repository does not implement cross-process locking.
- **No destructive maintenance**: the app rewrites the file only on create/update/destroy of an entry. Backup/compaction is out of this contract.

## Error semantics

| Condition | Behavior |
|---|---|
| File missing on read | Treated as empty list (`entries: []`); not an error. |
| File missing on first write | Created (including the desktop directory path if needed). |
| Unwritable path / disk full | `EntryRepository::StorageError`; the previous file (if any) is untouched; the UI shows the RF-05 failure path. |
| Corrupt JSON on read | `EntryRepository::StorageError` surfaced as a storage-failure screen — the app never overwrites a file it could not read. |

## Evolution policy

- Additive changes (new optional keys) bump nothing; readers must ignore unknown keys.
- Breaking changes to existing keys bump `version`; the app reads one version and fails loudly (`StorageError`) on a higher version rather than guessing.
- Consumers of the future analysis module (D9) should target this file, not scrape the UI.
