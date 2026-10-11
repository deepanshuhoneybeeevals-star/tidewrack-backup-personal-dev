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
missing. The fix restores Godot's built-in actions.

## Behavior after this change

- First visits still offer the original choices and prose.
- Rereading follows the previously selected stance response and disclosure
  ending, both within the session and after Continue. New Game clears them.
- Choosing a stance sets the other stance false.
- An absent disclosure flag means unanswered; a stored false means keep quiet.
- Version-1 saves keep their schema, canonical names, and unknown flags.
  Single-stance old saves work without migration. Old saves with both stances
  true ask for a stance again; the new answer resolves the conflict. There is
  no history in the old save that identifies which answer was most recent.
- This is scene/flag persistence, not a mid-line or player-position checkpoint.
  Saving remains available after finishing the conversation via the pause menu.

Routing nodes in dialogue JSON use ordered `branches` containing `when` flag
maps and `next` targets, plus a fallback `next`. Every flag in a condition must
exist and match. Routing does not show text or apply effects. A runtime guard
stops routing cycles; the validator checks routing structure and target reachability.

## Repeatable checks

On Linux or WSL with Godot 4.3 installed:

```bash
python3 tests/run_tests.py --godot /path/to/godot
```

The runner isolates `user://` in a temporary directory, validates both authored
graphs, runs seven validator unit tests, imports the project, and runs Godot
regressions. The engine tests cover all four stance/disclosure combinations,
false versus absent, exclusive flags, legacy/ambiguous saves, repeated reads,
New Game, invalid choice indexes, keyboard mappings, and the real world-object,
choice-button, pause Save, Main Menu, and Continue signal flow. The test scene
refuses to run against the ordinary user-data directory.

Before the fix, the disk checks passed and the two reread checks failed. Before
the input fix, all seven keyboard-binding checks failed. All now pass.

## Before cutting the demo branch

This fixes choice carry; it does not establish that the tagged candidate is a
complete public demo. In this checkout:

- `scripts/lamp_room.gd` is an empty room/placeholder lamp. The ground-floor stair
  still starts the “next chapter” line instead of changing scenes. There is no
  relighting interaction or closing beat; `data/dialogue/lamp_room.json` is draft.
- `scripts/journal.gd` has storage helpers only, no reader UI or persistence, and
  is not registered as an autoload or connected to discovery.
- The wall-collision helper is a TODO and is not called; only room bounds work.

Do not treat the old README's “feature-frozen” wording or the release tag as
proof that those systems shipped. Resolve the required lamp-room and journal
work before labeling this checkout a complete demo. Controller work is not
expanded by this fix.

Manual release check, still required on the actual exported target build:
start with a fresh save; use keyboard navigation to choose skeptic and quiet;
finish the dialogue; Esc → Save → Main Menu → Continue; reread and verify the
skeptic response and quiet ending without new decisions. Repeat after fully
quitting the executable, then verify New Game offers both choices again. Check
visual layout, focus, and a clean-account installation. Headless signal tests
are not a visual playthrough or Steam export/install validation.
