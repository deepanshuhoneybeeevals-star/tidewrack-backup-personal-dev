# Tidewrack

A narrative adventure set on a fog-bound island off the Washington coast. You
are the new keeper of **Cape Marrow Light**. The keeper before you, Edith Vane,
rowed out into the fog eleven days ago and did not come back.

Built solo by **Fogline Games** (Seattle) in **Godot 4**, shipping to Steam.

> **Status:** Public-demo candidate (Steam Next Fest). Vertical slice +
> branching conversation with save/load. See [`docs/milestones.md`](docs/milestones.md)
> for the road to launch.

## Controls

| Action        | Key                     |
|---------------|-------------------------|
| Move          | Arrow keys              |
| Interact      | Enter / Space           |
| Advance / skip line | Enter / Space     |
| Pause / back  | Esc                     |

The game uses only Godot's built-in input actions, so it works with no input
remapping (dedicated controller support and remappable keys are outside this fix).

## Running it

Requires **Godot 4.3+** (standard, non-.NET build).

```bash
# Open in the editor
godot -e --path .

# Or run directly
godot --path .
```

The main scene is `scenes/main_menu.tscn`. Saves are written to Godot's
`user://save.json` (per-OS user data dir).

## Project layout

```
tidewrack/
├── project.godot            # engine config; registers the three autoloads
├── scenes/                  # thin .tscn wrappers (root node + script)
│   ├── main_menu.tscn
│   ├── game.tscn            # the vertical-slice level
│   └── ui/{dialogue_box,settings}.tscn
├── scripts/
│   ├── autoload/
│   │   ├── game_state.gd     # story flags + save/load  (autoload: GameState)
│   │   └── dialogue_manager.gd  # branching graph player (autoload: DialogueManager)
│   ├── main_menu.gd, settings.gd
│   ├── game.gd               # builds the level + HUD + pause menu
│   ├── player.gd             # top-down movement (Player)
│   ├── interactable.gd       # examinable world object (Interactable)
│   └── dialogue_box.gd       # dialogue UI, listens to DialogueManager
├── data/dialogue/
│   └── keeper_intro.json     # the keeper's-log conversation
├── assets/{sprites,audio,fonts}/   # placeholder art for now
├── tests/validate_dialogue.py      # engine-free dialogue-graph checker
└── docs/                     # GDD, narrative bible, milestones, credits
```

**Design note:** UI and levels are constructed in GDScript rather than authored
as large scene files. This keeps `.tscn` files small and reviewable in diffs and
avoids merge pain — a deliberate choice for a one-person studio.

## The dialogue system

Conversations are plain JSON graphs in `data/dialogue/`. Nodes can show a
linear line (`"next": "<id>"`, or `null` to end), offer choices (`"choices"`),
or route according to saved flags (`"branches"`).
Line and choice nodes can set story flags via `"set_flag"`, which `GameState`
persists. Routing nodes can read those flags via ordered `"branches"` with
`"when"` conditions and a fallback `"next"`. Keeper rereads follow the saved
stance and disclosure decision. A displayed node can record a discovered log
with `"journal_entry": "stable_log_id"`. The keeper log uses `keeper_log`;
`Journal` deduplicates discoveries and `GameState` persists them. The journal
reader UI is deferred. See [choice carry and journal persistence](docs/choice-carry.md).

```json
{
  "start": { "speaker": "Edith", "text": "…", "next": "choice1" },
  "choice1": {
    "text": "…",
    "choices": [
      { "text": "Trust her", "next": "end", "set_flag": { "trusted_edith": true } }
    ]
  },
  "end": { "speaker": "", "text": "…", "next": null }
}
```

## Verifying changes

```bash
# Validate every dialogue graph (targets resolve, has an ending, no orphans)
python3 tests/validate_dialogue.py

# Runtime + validator regressions (Linux/WSL, Godot 4.3; saves isolated)
python3 tests/run_tests.py --godot /path/to/godot
```

Godot 4.3 headless checks cover keeper choices, save/load, the menu Continue
flow, journal discovery/persistence (including a fresh-process Continue),
legacy saves, and keyboard mappings. An exported-build visual playthrough
and clean-account install remain release gates.

## Steam Next Fest demo

The public-demo target extends the vertical slice with the lamp-room chapter
and discovered-log tracking. Journal discovery and save persistence now work;
the reader UI belongs to a later milestone. Although this checkout carries
`v0.2-demo-rc`, the lamp room is still a scaffold and the stair is not connected
to it. The tag does **not** indicate a complete, feature-frozen demo.

See [the diagnosis and pre-branch checks](docs/choice-carry.md) for verified
behavior and remaining demo blockers. The current fix restores the built-in
keyboard actions; it does not add a controller-support milestone.
