# Tidewrack — Milestones

A nine-month schedule from kickoff to Steam launch. Dates are targets; the
GitHub Milestones mirror these and the issue tracker is grouped under them.

| # | Milestone       | Target date  | Definition of done |
|---|-----------------|--------------|--------------------|
| 0 | Kickoff         | 2026-03-02   | Repo, engine, dialogue system spike, GDD v0. |
| 1 | **Vertical slice** | 2026-05-15 | One explorable scene, working branching dialogue, save/load, menus. *(current build)* |
| 2 | **Public demo**    | 2026-08-15 | Second scene (the lamp room), journal discovery/persistence, controller support. Wall collision and journal reader UI deferred. Ships for Steam Next Fest. |
| 3 | **Press build**    | 2026-10-15 | Full act one, localization-ready strings, accessibility pass, review keys out. |
| 4 | **Full launch**    | 2026-11-20 | Complete game, Steam achievements, store page live, launch trailer. |

## Where things stand (2026-07)

Vertical slice is complete and in players' hands. Work now targets the **Public
Demo** for Next Fest: the lamp-room scene, a journal to track discovered logs,
and controller support left open in the slice. The original collision goal is
superseded by the demo scope decision below.

## Notes on scope

- **One location per milestone.** Each milestone adds exactly one new explorable
  space to keep the solo workload honest.
- **Narrative is the long pole.** Writing and iterating dialogue is the critical
  path; systems work is scheduled around leaving writing time.
- **Marketing beats are milestones too.** Store page, trailer, and Next Fest
  are tracked as first-class deliverables, not afterthoughts.

## Demo scope locked (Steam Next Fest)

For the public demo we ship the vertical slice **plus**:

- **Lamp-room chapter** — the stair from the ground floor opens into the lamp
  room; relighting the lamp is the demo's closing beat.
- **Journal** — record discovered logs and retain them across Save / Continue.
  The reader UI is deferred to a later milestone.
- **Controller support** — gamepad input map layered on the built-in actions.
- **Playtest fixes** — the round of fixes from the vertical-slice playtests.

Everything past this list (chapters 2+, full soundtrack, cover art integration)
is **out of demo scope** and deferred to the press/launch milestones. No crunch,
but the Next Fest date is firm.

## Deferred after the demo (decision: 2026-10-12)

- **Wall collision** is explicitly out of scope for the Next Fest demo and is
  not a release gate. The demo retains outer room bounds only; the unused
  collision helper in `scripts/player.gd` is still a TODO, not a finished system.
- [ ] Assign wall collision to a post-demo milestone and implement and playtest
  it before marking that follow-up complete. No target milestone or date has
  been committed yet.

The demo release checks are tracked in [choice-carry.md](choice-carry.md).
