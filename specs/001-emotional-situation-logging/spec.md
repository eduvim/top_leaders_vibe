# Spec — Emotional Situation Logging and Analysis

Version: 0.1 (draft for review) · Status: Under analysis · Author: Eduardo Villaseñor · Date: 2026-10-09

---

## 1. Problem and business need

People often react automatically to situations that trigger intense emotional responses, without stopping to observe what happened, what meaning they attributed to it, and how they acted. This lack of observation hinders self-knowledge and emotional self-regulation.

Business need: make it easy to log emotional situations in a structured way and analyze them afterwards, so the user can identify patterns (recurring meanings, dominant emotions, habitual reactions) and regulate their responses better.

Value proposition: a low-friction guided log (5 questions) plus later analysis.

Candidate success metrics (to be defined):
- Weekly retention of active users.
- Logs per user per week.
- Completion rate of started logs.
- Perceived usefulness reported by the user (NPS/CSAT survey).

---

## 2. Scope

Included in this version:
- Logging an emotional situation through a guided 5-question form.
- Confirming the log entry.
- Storing the entry for later analysis.

Out of scope in this version (assumption; to be confirmed):
- The later analysis module (only that the entry remains available is guaranteed).
- Reminders and notifications.
- Data export.
- Cloud sync, multi-user support, roles, sharing entries with therapists.

---

## 3. Decisions

### 3.1 Decisions made

| # | Decision | Resolution |
|---|----------|------------|
| D1 | Intensity scale | Numeric from 1 to 5, where 1 is the lowest intensity and 5 the highest. |
| D2 | Emotion format | Free text using tags: the user writes freely and the system stores normalizable tags (e.g., lowercase, no extra spaces). |
| D3 | Mandatory questions | All questions are optional. The user may answer only the ones they want. |
| D4 | Incomplete entries | Yes. An entry can be saved as a draft and completed later. |
| D5 | Editing and deleting entries | All operations allowed: the user can create, view, edit, and delete any saved or draft entry. |
| D6 | Storage | Local. Entries are saved to a JSON file on the user's desktop. No account or cloud sync for now. |

### 3.2 Pending decisions

| # | Decision | Options | Impact if not decided |
|---|----------|----------|------------------------|
| D7 | Later analysis: what exactly does it mean that the entry is "available"? | View list, view detail, view statistics | Defines the acceptance criteria of RF-07 |
| D8 | Should the entry's date/time be recorded automatically? | Yes / editable | Required for any time-based analysis |
| D9 | What later analysis is offered and when? | Filters, trends, keywords | Out of scope or roadmap |
| D10 | Is a responsible-use notice required (not a clinical device)? | Yes / No | Legal/ethical risk |

---

## 4. Assumptions

- S1. One entry corresponds to a single situation and a single main emotion (the question uses the singular: "What emotion did you feel?").
- S2. The user logs the situation at the moment or shortly after the event; there is no date/time field for the event itself, only for the log entry.
- S3. The later analysis will be performed by the user themselves (not by third parties).
- S4. The application is for a single person per account/profile; there is no social interaction.
- S5. The initial language is Spanish.
- S6. The entry is stored on the user's own device; it is not shared.

Contradiction found: the original text describes the process twice, identically. It is interpreted as an accidental duplicate, not as a flow of two consecutive entries.

---

## 5. Ambiguities and risks

Ambiguities:
- A1. "What meaning did you give it?" does not define format or limits (free text, maximum length, contextual help).
- A2. "The application confirms the situation was logged" does not define the mechanism (on-screen message, sound, notification).
- A3. "Available for later analysis" does not define where or how the user sees it.
- A4. Behavior on save failure (offline or storage failure) is not defined.
- A5. Whether the user can interrupt the log entry halfway, and what happens to data already captured, is not defined.

Risks:
- R1. Privacy: entries contain sensitive emotional information. Without encryption or a data policy there is regulatory and trust risk.
- R2. Abandonment: 5 free-text questions create friction. Without quick scales and defaults, the completion rate drops.
- R3. Inconsistent data: without an emotion catalog and a normalized scale, later analysis will be of little use.
- R4. Therapeutic expectation: if the user perceives the app as treatment, there is a risk of inappropriate use. A notice is advisable.
- R5. Data loss: if saving fails silently, the user believes they logged the entry and it does not exist.

---

## 6. Functional requirements (observable and verifiable behaviors)

Format: Given / When / Then.

RF-01. Access to the log form
- Given the user is on the main screen.
- When they select "Log situation".
- Then the system shows the form with the 5 questions in the defined order:
  1. What happened?
  2. What meaning did you give to what happened?
  3. What emotion did you feel?
  4. How intense was it?
  5. How did you react?
- QA verification: navigate to the main screen, tap the button, verify presence, order, and wording of the 5 questions.

RF-02. Field capture
- Given the form is open.
- When the user enters the values.
- Then the system applies the decided rules (D1–D4): all questions are optional; intensity only accepts integer values from 1 to 5; emotion is captured as free text with tags.
- QA verification: cases with all fields empty (must save as a draft or save according to the chosen flow), intensity outside the 1–5 range (e.g., 0, 6, text), and overly long text; the system shows the corresponding error and does not save.

RF-03. Saving
- Given the form has valid values according to RF-02.
- When the user selects "Save".
- Then the system persists the entry to the local JSON file (D6), with: the answers given, save date and time (pending D8), a unique identifier, and status (saved or draft, per D4).
- QA verification: save an entry, reload the app, verify the entry persists in the JSON file; save an entry with empty fields and verify it is stored as a draft.

RF-04. Confirmation
- Given the save succeeded.
- When the entry has been persisted.
- Then the system shows a visible confirmation to the user (mechanism to be defined, A2) and allows logging another situation or going back.
- QA verification: save and verify the confirmation message appears within a reasonable time (e.g., < 2 s).

RF-05. Save failure handling
- Given the save fails (storage unavailable).
- When the user selects "Save".
- Then the system shows an error message, keeps the captured data on screen, and does not claim the entry was logged.
- QA verification: simulate a persistence failure; validate the message and that no success message appears.

RF-06. Interrupting the log entry
- Given the form has partial data.
- When the user exits without saving.
- Then the system offers to save the data as a draft (D4) or discard it, and does not lose data without the user's consent.
- QA verification: fill in partially, exit, reopen; verify the system offers to save as a draft or that the draft was saved.

RF-07. Availability for later analysis
- Given an entry was saved.
- When the user views their entries (view to be defined, A3/D7).
- Then the entry appears with its answers, date/time, and is viewable.
- QA verification: log N entries, open the view screen, verify presence and fidelity of all fields.

RF-08. Editing and deletion (per D5)
- Given a saved or draft entry exists.
- When the user selects edit or delete and confirms the action.
- Then the system updates or removes the entry in the local JSON file, records the date/time of the change, and reflects the result in the view screen.
- QA verification: edit a field and verify the change after reloading; delete an entry and verify it disappears from the list and from the JSON file.

---

## 7. Non-functional requirements

- NFR-01 Privacy and security: entries are visible only to the user; encryption at rest and in transit if cloud sync is added; data is not used for other purposes without consent.
- NFR-02 Usability: a regular user should be able to complete an entry in under 2 minutes.
- NFR-03 Performance: save and confirm in under 2 s under normal conditions.
- NFR-04 Availability: local storage works offline given decision D6 is local.
- NFR-05 Accessibility: forms navigable by keyboard and screen reader; sufficient contrast.
- NFR-06 Responsible-use notice: the app does not replace professional psychological care; show a visible notice (pending D10).

---

## 8. Provisional data model

Entity: SituationEntry
- id: UUID, unique, generated on save.
- whatHappened: text, optional (D3) (maximum length to be defined).
- meaning: text, optional (D3).
- emotion: free text stored as tags (D2).
- intensity: integer from 1 to 5 (D1).
- reaction: text, optional (D3).
- loggedAt: automatic timestamp (pending D8).
- status: saved | draft (D4).

Storage (D6): entries are persisted to a single JSON file located on the user's desktop. Each entry is an object inside an array in the file. The file format is to be defined during technical design (name, wrapper structure, atomic write handling).

---

## 9. User stories and acceptance criteria

US-01: Log a situation
- As a user, I want to log an emotional situation answering only what I want, so I can review it later without friction.
- AC1: I can open the form from the main screen with one tap.
- AC2: I can save the entry even if I leave questions empty (it will be saved as a draft, per D3 and D4).
- AC3: Intensity only accepts a value between 1 and 5.
- AC4: On save I receive a visible confirmation.
- AC5: The entry becomes available in the local JSON file for later review.
- AC6: I can edit or delete any entry (per D5).

US-02: View my entries
- As a user, I want to see my saved entries, to identify patterns.
- AC1: I see the list of entries with date and emotion.
- AC2: I can open the full detail of each entry.
- The scope of this view depends on decision D7.

---

## 10. Glossary

- Entry: a single instance of an emotional situation captured through the 5 questions.
- Intensity: the perceived magnitude of the emotion, measured on the scale defined in D1.
- Meaning: the interpretation or attribution the user gave to what happened.
- Later analysis: viewing and/or studying the saved entries; exact definition pending (D7, D9).

---

## 11. Module: Viewing entries (single person)

This module specifies requirement RF-07 and decision D7. Scope: allow a single user to view the emotional situation entries they themselves saved. It does not include statistics, trends, or export (see D9).

### 11.1 Assumptions

- CS1. Each user views only their own entries; no other person's entries exist in their view.
- CS2. The intensity scale and emotion format are already defined by D1 and D2.
- CS3. Each entry has a save date and time (depends on D8); without it, chronological ordering is not possible.

### 11.2 Functional requirements

CRF-01. Access to the view screen
- Given the user is on the main screen and has at least one saved entry.
- When they select "My entries".
- Then the system shows the view screen with the list of their entries.
- QA verification: save an entry, open "My entries", verify it appears in the list.

CRF-02. Entry list
- Given the user has N saved entries.
- When they open the view screen.
- Then the system shows a list with, at minimum, per entry: date/time, emotion, and intensity, ordered from newest to oldest.
- QA verification: save 3 entries at different times, open the view, verify the order and the content of each row.

CRF-03. Entry detail
- Given the user is viewing the list.
- When they select an entry.
- Then the system shows the full detail with the 5 answers, the date/time, and the identifier not visible.
- QA verification: open the detail of a known entry and compare each field with what was saved.

CRF-04. Empty state
- Given the user has no saved entries.
- When they open the view screen.
- Then the system shows a message stating there are no entries yet and an action to log a situation.
- QA verification: with a profile with no entries, open the view and validate the message and the visible action.

CRF-05. View privacy
- Given the user opens the view screen.
- When they view any entry.
- Then the system shows only entries created by that user; no other profile's entries are accessible.
- QA verification: with two different profiles, verify that each sees only their own entries.

### 11.3 Pending decisions for this module

| # | Decision | Options | Impact |
|---|----------|----------|---------|
| CD1 | Navigation with many entries | Pagination / infinite scroll / "load more" | Performance and UX |
| CD2 | Filters in the list | By emotion, by intensity range, by date range, no filters | Complexity and analysis value |
| CD3 | Text search | Yes / No | Indexing requirement |
| CD4 | Summary shown in the list | Show a snippet of "What happened?" / only emotion and date | List density |
| CD5 | Actions from the detail | Edit and delete are allowed (D5); the location of the actions and deletion confirmation remain to be defined | UX and prevention of accidental deletion |

### 11.4 User story

US-03: View my entries
- As a single user, I want to view the entries I saved, to review my situations and spot patterns.
- AC1: I see all my entries ordered from newest to oldest.
- AC2: I can open the full detail of any entry.
- AC3: If I have no entries, I see a clear message and an action to create the first one.
- AC4: I never see another person's entries.

---

## 12. Open questions for the team

1. Pending answers: D7–D10 and CD1–CD5 before estimating development.
2. Was the duplicated flow in the original process an error, or does it represent something (e.g., logging several situations in a row)?
3. Are there regulatory or privacy requirements applicable to the target jurisdiction (e.g., health data)?
4. Is there existing UI/UX design, or do we start from scratch?
5. What is the MVP: logging only, or logging plus a view screen?