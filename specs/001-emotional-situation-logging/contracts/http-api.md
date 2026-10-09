# Contract — HTTP / UI Routes

Server-rendered Rails app. The "API" is the set of routes and screens below; content type is HTML for all responses. Redirects follow the POST/redirect/GET pattern; user-facing feedback uses Rails Flash notices (confirmation, A2) and inline form errors (RF-02/RF-05). All copy is Spanish (S5). The responsible-use notice is present in the layout on every screen (NFR-06/D10).

Data rules referenced below (D1–D5, RF-01..RF-08, CRF-01..CRF-05) are defined in [spec.md](../spec.md) and [data-model.md](../data-model.md).

## Main screen

| Method/Route | Screen | Behavior |
|---|---|---|
| `GET /` | Main screen | Two actions: "Registrar situación" and "Mis registros" (RF-01, CRF-01). Responsible-use notice visible. |

## Logging an entry (RF-01..RF-06)

| Method/Route | Action | Success behavior | Failure behavior |
|---|---|---|---|
| `GET /entries/new` | Show guided form | 5 questions in fixed order (RF-01): ¿Qué pasó? / ¿Qué significado le diste a lo que pasó? / ¿Qué emoción sentiste? / ¿Cómo fue de intensa? (radio 1–5) / ¿Cómo reaccionaste?. Fields pre-filled from `session[:draft_params]` if returning from a failed save. | Storage already failed earlier → storage-failure screen with retry hint. |
| `POST /entries` (params `entry[...]`, `commit=save`) | Save completed entry | Requires `emotion_raw` present (research §11). Persists with `status: "saved"`, `logged_at` now (RF-03). Redirect to `GET /entries/:id` with Flash: "Tu registro se guardó." Detail screen offers "Registrar otra situación" and "Volver" (RF-04). | Validation error (intensity out of 1..5, over-length text): re-render form, HTTP 422, field errors inline, data preserved. `StorageError`: re-render form, HTTP 503, storage error message, data preserved, no success message (RF-05). |
| `POST /entries` (params `entry[...]`, `commit=draft`) | Save draft | Valid with all fields empty (D3/D4). Persists with `status: "draft"`. Redirect to `GET /entries/:id` with Flash: "Tu borrador se guardó." | `StorageError`: same as above. (A draft cannot fail validation — empty is valid.) |

Client-side: the form's unload guard warns before discarding filled fields (RF-06, research §8).

## Viewing entries (CRF-01..CRF-05)

| Method/Route | Screen | Behavior |
|---|---|---|
| `GET /entries` | "Mis registros" list | All entries (saved + drafts), newest `logged_at` first (CRF-02). Per row: date/time, `emotion_tag`, intensity "n/5", ~80-char snippet of `what_happened`, "Borrador" badge for drafts (CD4). Empty state: "Aún no tienes registros." + action "Registrar situación" (CRF-04). No pagination/filters/search in MVP (CD1–CD3). |
| `GET /entries/:id` | Entry detail | All 5 answers (empty shown as "—"), date/time, edit/delete actions (CRF-03, CD5). `id` never displayed (CRF-03). Unknown/missing id → 404. |
| `GET /entries/:id/edit` | Edit form | Same 5-question form, pre-filled. Available for saved and draft entries alike (D5). |

## Editing and deleting (RF-08, D5)

| Method/Route | Action | Success behavior | Failure behavior |
|---|---|---|---|
| `PATCH /entries/:id` (params `entry[...]`, `commit=save` or `commit=draft`) | Update entry | Refreshes `updated_at`, persists, redirect to detail with Flash "Tu registro se actualizó." (RF-08) | Same validation/storage semantics as `POST /entries`. Unknown id → 404. |
| `DELETE /entries/:id` | Delete entry | Only after the confirmation screen/dialog "¿Eliminar este registro? Esta acción no se puede deshacer." (CD5). Removes from file, redirect to list with Flash "El registro se eliminó." | `StorageError`: redirect back to detail with error Flash; entry remains. |

## Status codes

| Code | Meaning in this app |
|---|---|
| 200 | Screen rendered (form, list, detail). |
| 303 | Redirect after successful create/update/delete (PRG). |
| 404 | Entry id not found. |
| 422 | Validation failure; form re-rendered with errors. |
| 503 | `StorageError`; form or storage-failure screen re-rendered with error, user data preserved. |

## Accessibility (NFR-05)

- All forms are label-associated; the intensity radio group has a fieldset/legend.
- Every action is reachable and operable by keyboard; focus management follows standard Rails/Turbo behavior.
- Contrast meets WCAG AA on the default Rails styling palette.
