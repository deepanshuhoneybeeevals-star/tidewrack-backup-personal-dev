# Tidewrack demo stabilization and release checklist

This records the full demo-fix session on `fix/keeper-choice-carry`, in
[draft PR #1](https://github.com/deepanshuhoneybeeevals-star/tidewrack-backup-personal-dev/pull/1).
The inspected base was `8c9b1e4` (`v0.2-demo-rc`). Implementation and automated
verification below cover changes through `3aad371`, using Godot 4.3 stable on
Linux, headless. The demo branch has not been cut and the PR has not been merged.

## Keeper choices: the actual failure and the fix

The reported save/Continue failure was in the dialogue read path. `choose()`
applied `set_flag`, `save_game()` wrote the flags, and `load_game()` restored
them. A real disk round trip preserved `skeptic: true` and `trusted_edith: false`,
but rereading the logbook offered the original choices because nothing read
those flags. Choosing another stance could also leave both stances true. The
original graph checker passed because structural validity did not demonstrate
that saved choices affected dialogue.

The keeper graph now routes rereads through the selected stance response and
disclosure ending, using the original prose and skipping answered decisions.
First visits still offer both decisions. Choosing a stance explicitly clears
the opposite stance. `GameState.has_flag()` distinguishes an unanswered flag
from a stored false value.

Dialogue routing nodes use ordered `branches`, each with a `when` flag map and
`next` target, plus a fallback `next`. Every condition flag must exist and match;
the first matching branch wins. Routing nodes show no text and apply no effects.
The dialogue manager skips them automatically and guards against routing cycles.

## Flag writers and readers

The four flags written by `data/dialogue/keeper_intro.json` were all unread in
the original gameplay. Conversely, the lamp-room scaffold checked `lamp_relit`
but nothing set it. All five now have both a writer and a reader:

| Flag | What writes it now | What reads it now |
| --- | --- | --- |
| `skeptic` | Skeptic choice sets true; believer choice sets false. | `logbook_stance` selects the saved response or detects conflicting old stances. |
| `believer` | Believer choice sets true; skeptic choice sets false. | `logbook_stance` selects the saved response or detects conflicting old stances. |
| `trusted_edith` | Logbook disclosure choice sets true for sharing, false for keeping quiet. | `logbook_disclosure` selects the corresponding ending; absent means unanswered. |
| `radioed_tom` | Either radio topic sets true. | `radio` selects Tom's returning-call greeting. |
| `lamp_relit` | Interacting with the great lamp sets true. | `scripts/lamp_room.gd` restores its appearance and prevents repeat relighting. |

The logbook's sharing choice records intent; it does not itself place a radio
call. Merely opening the radio does not set `radioed_tom`. After choosing either
radio topic, subsequent calls start with Tom's “You again” greeting, and both
topics remain available. Missing or false retains the original first-call flow.

## Journal service, discovery, and persistence

`scripts/journal.gd` is now registered as the `Journal` autoload before
`GameState` in `project.godot`. Displayed dialogue nodes opt in with
`"journal_entry": "stable_log_id"`. Opening the keeper log records `keeper_log`;
radio and stair interactions do not add journal entries.

Discovery stores unique IDs in first-found order and emits `entry_added` only
for a new ID. `entries()` returns a copy. Continue replaces the current list
from the save without emitting discovery events, and New Game clears it.
Non-array saved values restore an empty list; mixed arrays discard invalid or
blank IDs and duplicates while retaining valid unknown IDs in order.

The journal screen remains deferred to a later milestone. The running service,
discovery hook, and save persistence are the agreed demo scope. There is no
reader UI in this PR.

## Save compatibility and boundaries

Save version remains 1, with canonical flag names and unknown flags preserved.
The optional `journal_entries` array is saved alongside `flags` and `scene`.

- Old single-stance saves work without migration. If both stances are true,
  the logbook asks again and the new answer resolves the conflict; the old save
  contains no history from which to infer the most recent choice.
- Missing `trusted_edith` means unanswered; false means the player chose quiet.
- Old saves without journal data restore an empty journal. Earlier discoveries
  cannot be reconstructed from absent history.
- Missing `lamp_relit` means unlit. Continue restores the saved room and its
  flag-driven appearance, including when saved upstairs.
- New Game clears flags and journal entries and returns to the ground floor.
- Saves preserve room, flags, and discovered logs, not player position or the
  current dialogue line. Finish the conversation before using pause-menu Save.

## Escape, pause, and controls

A second Escape previously restored movement without removing `PauseLayer`;
only Resume freed it, and repeated toggles could stack overlays. Escape and
Resume now share cleanup that immediately detaches the layer, queues deletion,
clears the reference, and restores movement. Escape inside Settings closes
Settings first and leaves the game paused. Dialogue still blocks pause, and
held-key repeat does not repeatedly toggle the menu.

The original `project.godot` gamepad-only action overrides removed all seven
checked keyboard bindings. The first fix removed those overrides, restoring
keyboard and directional defaults but inadvertently dropping A/B accept/cancel.
The follow-up restored A/B explicitly alongside the keyboard events:

| Action | Current bindings |
| --- | --- |
| Directional movement | Arrow keys, D-pad, left stick (Godot defaults; deadzone 0.5). |
| `ui_accept` | Enter, keypad Enter, Space, gamepad A (button 0). |
| `ui_cancel` | Escape, gamepad B (button 1). |

Synthetic Godot events verify all four stick directions through the actual
Player code, deadzone suppression, and A/B press/release. A physical controller
has not been tested.

## Minimal lamp-room loop

The ground-floor stair now opens `scenes/lamp_room.tscn`, with a return stair to
`scenes/game.tscn`. The lamp room inherits movement, prompts, dialogue UI, and
pause/save from `scripts/game.gd`. Scene changes are deferred until the current
interaction finishes, with input guarded against duplicate transitions. Room
entry updates `GameState.current_scene` for saving.

Interacting with the great lamp sets `lamp_relit`, changes its grey body to
gold, shows a warm glow, updates its label and prompt, and plays the short
completion line in `data/dialogue/lamp_room.json`. There is no puzzle. An
already-lit lamp does not replay the line. Revisiting, Continue, and a fresh
process restore the lit state; choices and journal entries survive the trip.

The old `door` dialogue node remains as a legacy graph entry, but the actual
stair uses scene transitions. Its obsolete “next chapter” placeholder was removed.

## Dialogue checker and authoring conventions

The journal helper code formerly below `sys.exit(main())` was dead and never
used. It was removed; journal validation now runs inside the normal checker.
`journal_entry` must be a nonblank string and cannot appear on routing nodes.
Routing conditions, fallback/branch targets, `set_flag` dictionaries, and
malformed choice/target data are also checked.

Every node ID beginning exactly with `entry_` is now a starting point, alongside
`logbook`, `radio`, `door`, and `start`. Each root must independently reach an
ending. Orphan detection uses the union of all roots, so journal-only graphs
receive reachability checks instead of only a “no entry point” warning.
`entry_` node IDs and `journal_entry` discovery metadata are separate conventions.
Reachability checks all authored edges; it does not prove termination for every
possible combination of flags.

All changed `.gd` files were reviewed for tab indentation, snake_case names,
and a `##` comment on every function, including inline callbacks. Python cache
files are ignored. `README.md`, `docs/GDD.md`, `docs/milestones.md`, and
`docs/narrative-bible.md` now reflect the implemented demo scope and remaining
work. The PR description lists every changed file by full repository-relative
path. The old “feature-frozen” claim and release tag are not release evidence.

## Automated verification

From the repository root, with Godot 4.3 installed:

```bash
python3 tests/run_tests.py --godot /path/to/godot
```

The full suite passed for implementation commit `3aad371`. The runner isolates
`user://` in a temporary directory; save-test scenes refuse the ordinary user
data directory. Coverage includes:

| Check | Evidence covered |
| --- | --- |
| `tests/validate_dialogue.py` and `tests/test_validate_dialogue.py` | Both authored graphs; 14 unit tests including journal-only and mixed roots, each root's ending, orphans, exact prefix, and malformed schema. |
| Godot headless import | Project/script loading before runtime regressions. |
| `tests/test_choice_carry.gd` | Four stance/disclosure combinations, absent vs false, exclusive and legacy/conflicting flags, rereads, both radio topics and repeat greetings, invalid choice indexes, New Game, keyboard mappings, real object/choice-button/Save/Main Menu/Continue signals, journal ordering/deduplication and malformed/legacy data. |
| `tests/test_pause_menu.gd` | Dispatched Escape events, repeated cycles, key-repeat suppression, Resume, nested Settings, and dialogue guard. |
| `tests/test_controller_input.gd` | Synthetic stick movement in all directions, deadzone, A/B press/release. |
| `tests/test_lamp_room.gd` | Enter through world interaction, both stairs, unlit/lit saves, one-time relighting, movement recovery, color/glow/label state, retained choices/journal, and New Game. |
| Separate write/read processes | Actual Continue restores multiple journal IDs and radio state; a separate lamp save/Continue restores the lit room upstairs. |

Before the fixes, disk flag checks passed while reread checks failed; keyboard
checks and the later A/B regression also reproduced their respective failures.
The corrected automated checks pass. Headless property assertions do not verify
visual presentation, physical controller compatibility, or a packaged install.

Latest standalone checker output (exit code **0**):

```text
[OK] data/dialogue/keeper_intro.json  (18 nodes)
[OK] data/dialogue/lamp_room.json  (1 nodes)

✓ all dialogue graphs valid (0 warning(s))
```

## Before cutting the demo branch

Completed in this PR and covered by automated checks:

- [x] Keeper stance/disclosure carry through rereads and Save/Continue; old saves handled.
- [x] Tom remembers completed radio calls through `radioed_tom`.
- [x] Journal discovery service runs and found logs persist across processes.
- [x] Escape and Resume both remove the pause overlay; nested Settings still works.
- [x] Keyboard bindings and synthetic stick/A/B checks pass.
- [x] Checker validates journal metadata and reachability from every `entry_` root.
- [x] Both stairs work; relighting sets `lamp_relit` and restores the lit appearance after Continue.
- [x] Changed GDScript follows tabs, snake_case, and `##` function comments.

Still required before release; check these on the actual exported target build:

- [ ] Run the keyboard flow from a fresh save: choose skeptic and quiet, finish
  the conversation, then Escape → Save → Main Menu → Continue. Reread without
  new decisions; fully quit/relaunch and repeat. Verify both radio topics and
  Tom's returning greeting. Check New Game resets the choices and discoveries.
- [ ] Check both stairs, save upstairs before and after relighting, quit and
  Continue, and inspect the lamp's color/glow/label and interaction prompt.
  Confirm movement returns after dialogue and transitions.
- [ ] Verify discovered journal IDs survive those exported-build saves, using
  save data or debug inspection while the reader UI is deferred. Check an old
  version-1 save without journal data also loads correctly.
- [ ] Visually check dialogue layout, focus/navigation, repeated Escape/Resume,
  and Settings dismissal. Confirm no stuck or stacked overlays.
- [ ] Test a physical controller on supported hardware: stick, deadzone, D-pad,
  A/B, interaction, and menu navigation.
- [ ] Verify the packaged/Steam build launches and saves on a clean account or
  installation, then resumes correctly after fully exiting.
- [ ] Review and integrate PR #1, rerun the suite on the final candidate after
  any changes, and cut the demo branch from the reviewed commit.

Scope decisions:

- [x] Wall collision is explicitly deferred until after the demo (2026-10-12).
  The demo uses room bounds only; the unused TODO helper in `scripts/player.gd`
  remains unfinished. This is no longer a demo release gate. Track the follow-up
  in `docs/milestones.md`; its implementation milestone is not yet assigned.
- The journal reader screen is deferred, and a larger lamp puzzle is outside
  the agreed minimal scope. Neither is an unfinished requirement for this PR.
