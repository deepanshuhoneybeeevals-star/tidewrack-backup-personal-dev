# Keeper choice carry: diagnosis and demo check

Inspected base: `8c9b1e4` (`v0.2-demo-rc`). Reproduced and tested with Godot
4.3 stable, Linux, headless.

## What failed

The reported save/Continue symptom is a dialogue read-path bug. `choose()`
applies `set_flag`; `save_game()` writes those flags; `load_game()` restores
them. A real disk round trip preserves both `skeptic: true` and
`trusted_edith: false`. However, the keeper graph did not read either flag:
interacting with the logbook always offered its original decisions again.
Choosing the other stance on a reread could leave both `skeptic` and `believer`
true. The original graph validator passed because it only checked graph shape,
not runtime state or the menu flow.

The project also replaced the default `ui_*` input arrays with gamepad-only
arrays. Engine checks confirmed all seven documented keyboard bindings were
missing. The directional actions now use Godot's defaults, which retain the
left stick, D-pad, and arrows at the same 0.5 deadzone. The initial removal of
all overrides also dropped gamepad A/B from accept/cancel; this follow-up
corrects that with explicit keyboard-plus-gamepad bindings for those two
actions. Enter, keypad Enter, Space, Escape, and A/B now coexist.

## Behavior after this change

- First visits still offer the original choices and prose.
- Rereading follows the previously selected stance response and disclosure
  ending, both within the session and after Continue. New Game clears them.
- Choosing a stance sets the other stance false.
- `radioed_tom` now selects a returning-call greeting after either radio topic.
  Both topics remain available. Missing/false gets the original first-call
  greeting; New Game resets it and Continue restores it.
- An absent disclosure flag means unanswered; a stored false means keep quiet.
- Version-1 saves keep their canonical names and unknown flags; an optional
  `journal_entries` array is added for discovered logs.
  Single-stance old saves work without migration. Old saves with both stances
  true ask for a stance again; the new answer resolves the conflict. There is
  no history in the old save that identifies which answer was most recent.
- This is scene/flag/journal persistence, not a mid-line or player-position checkpoint.
  Saving remains available after finishing the conversation via the pause menu.

Routing nodes in dialogue JSON use ordered `branches` containing `when` flag
maps and `next` targets, plus a fallback `next`. Every flag in a condition must
exist and match. Routing does not show text or apply effects. A runtime guard
stops routing cycles; the validator checks routing structure and target reachability.
The checker treats every node ID beginning with `entry_` as a starting point,
alongside `logbook`, `radio`, `door`, and `start`. Each starting point must reach
an ending; orphan checks use the union of all starting points. This convention
is separate from the `journal_entry` discovery metadata.

## Journal discovery and persistence

`Journal` is now an autoload, initialized before `GameState`. Displayed dialogue
nodes opt in with `"journal_entry": "stable_log_id"`; the existing logbook entry
records `keeper_log` on opening. Radio and stair interactions are not documents
and do not record logs. Further authored logs can use the same hook.

Discovery preserves first-found order and emits `entry_added` once per ID.
`GameState.save_game()` writes `journal_entries` alongside flags and scene;
Continue replaces the current journal from that array. New Game clears it.
Loading does not emit discovery events. Old saves without the optional array
load an empty journal; discoveries cannot be reconstructed from absent history.
Malformed arrays are treated as empty; within arrays, invalid/blank IDs are
ignored and duplicates removed while valid unknown IDs are preserved.

The journal screen is explicitly deferred to a later milestone. This change
implements the running service, discovery hook, and persistence only.

## Pause-menu cleanup

A second Escape previously restored movement without removing the pause layer;
only the Resume button freed it. Repeated toggles could stack overlays. Escape
and Resume now share one cleanup path that detaches and frees the overlay and
restores movement. Settings still consumes Escape first, leaving the game
paused, and dialogue still blocks pause.

## Repeatable checks

On Linux or WSL with Godot 4.3 installed:

```bash
python3 tests/run_tests.py --godot /path/to/godot
```

The runner isolates `user://` in a temporary directory, validates both authored
graphs, runs fourteen validator unit tests, imports the project, and runs Godot
regressions. The engine tests cover all four stance/disclosure combinations,
false versus absent, exclusive flags, legacy/ambiguous saves, repeated reads,
first/returning radio calls after both topics and a fresh-process Continue,
New Game, invalid choice indexes, keyboard mappings, and the real world-object,
choice-button, pause Save, Main Menu, and Continue signal flow. Journal checks
cover authored discovery, duplicate suppression, reset, legacy/malformed data,
and ordered multi-entry restoration. A separate Godot process saves and exits,
then a fresh process uses the actual Continue button to restore the entries.
The save test scene
refuses to run against the ordinary user-data directory. Pause regressions
dispatch actual Escape key events through Godot, covering repeated cycles,
key-repeat suppression, Resume, nested Settings, and the dialogue guard.
Controller regressions inject joypad events and verify all four left-stick
movement directions through the actual Player code, the deadzone, and A/B
action press/release. These are synthetic engine tests, not a physical-device
compatibility test.

Before the fix, the disk checks passed and the two reread checks failed. Before
the input fix, all seven keyboard-binding checks failed. All now pass.

## Before cutting the demo branch

This fixes choice carry; it does not establish that the tagged candidate is a
complete public demo. In this checkout:

- `scripts/lamp_room.gd` is an empty room/placeholder lamp. The ground-floor stair
  still starts the “next chapter” line instead of changing scenes. There is no
  relighting interaction or closing beat; `data/dialogue/lamp_room.json` is draft.
- Journal discovery and persistence now run. The reader UI is deferred to a
  later milestone and is not a release gate for this work.
- The wall-collision helper is a TODO and is not called; only room bounds work.

Do not treat the old README's “feature-frozen” wording or the release tag as
proof that those systems shipped. Resolve the required lamp-room
work before labeling this checkout a complete demo. Controller work is not
expanded by this fix.

Manual release check, still required on the actual exported target build:
start with a fresh save; use keyboard navigation to choose skeptic and quiet;
finish the dialogue; Esc → Save → Main Menu → Continue; reread and verify the
skeptic response and quiet ending without new decisions. Repeat after fully
quitting the executable, then verify New Game offers both choices again. Check
visual layout, focus, and a clean-account installation. Headless signal tests
are not a visual playthrough or Steam export/install validation.
