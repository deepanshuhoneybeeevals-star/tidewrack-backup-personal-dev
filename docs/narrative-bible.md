# Tidewrack — Narrative Bible

The single source of truth for story, characters, tone, and timeline. Dialogue,
design docs, and marketing copy all defer to this file.

## Logline

The new keeper of a remote Pacific Northwest lighthouse uncovers what happened
to the keeper before them — and the light offshore that answered hers.

## Setting

**Cape Marrow Light** stands on Marrow Island, a granite hump of rock and
salal off the outer Washington coast, reachable only by boat. Perpetual fog,
kelp, foghorn, cold. The year is deliberately vague — mid-century, radios and
paraffin lamps, no cell phones. Isolation is the antagonist as much as any
person.

**Tone:** quiet dread, melancholy, restraint. Closer to *Firewatch* and *Dear
Esther* than to horror. The uncanny is implied, never gored.

## Characters

- **The player** — the new keeper. Unnamed, lightly defined so the player
  projects onto them. Arrived to replace Edith after her disappearance.
- **Edith Vane** — the previous keeper, missing eleven days at the story's
  start. Meticulous, private, unraveling in her final log entries. Heard a
  light off the north rocks answering her signal and rowed out to meet it.
- **Tom Salish** — mainland harbormaster and the player's only regular contact,
  by radio. Ran Edith's last supply. Gruff, protective, knows more than he
  volunteers. Wants any findings brought to *him*, not the county.
- **The light off the north rocks** — the mystery. Never named, never
  explained in the vertical slice. It keeps the keeper's rhythm.

## Story flags (canonical)

These are set by dialogue choices or world interactions and persist via `GameState`. Keep names
stable — save files and future branches depend on them.

| Flag            | Set by                                   | Meaning |
|-----------------|------------------------------------------|---------|
| `skeptic`       | Logbook, choice 1                        | Player dismisses Edith's account. |
| `believer`      | Logbook, choice 1                        | Player believes something was out there. |
| `trusted_edith` | Logbook, choice 2 (true/false)           | Player will / won't share the log. |
| `radioed_tom`   | Radio conversation                        | Player has contacted Tom; subsequent calls use his returning greeting. |
| `lamp_relit`    | Interacting with the great lamp            | Lamp is lit; restores gold color and glow after Continue. |

Keeper decisions are remembered when the log is reread. The two stance flags
are mutually exclusive when chosen. `trusted_edith: false` is a deliberate
quiet decision; a missing flag means the player has not answered. Legacy saves
with both stances true require a new stance choice because their ordering is
unknown. Canonical flag names and the version-1 save format remain unchanged.

Either radio topic sets `radioed_tom` true. Later calls acknowledge that contact
and still offer both Edith and check-in topics. Missing/false uses the first-call
greeting; Continue retains the returning greeting and New Game resets it.

## Timeline (fiction)

1. Edith keeps the light alone; the fog rolls in for three nights.
2. A light off the north rocks begins answering her signal.
3. Edith relights the lamp "so whoever comes next can find the way back," then
   rows out. The dinghy is never recovered.
4. Eleven days later, the player arrives to find the lamp dead and the log open.

## Arc beyond the slice (spoilers, subject to change)

- **Act 1 (demo):** relight the lamp; the light answers; first contact.
- **Act 2:** row out; discover what Edith found.
- **Act 3:** decide whether to keep the light — and the rhythm — going.
