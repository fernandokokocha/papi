# Comments review & refactor session

Reconnect the author with ~1,700 lines of app code written across 16 commits
(`ee7fe2a..HEAD`), and post-factum refactor it. Secondary goal: harvest the
judgment calls made along the way into durable `.md` rules.

## Scope

The comments feature and its blast radius: everything the 16 commits created,
plus the older code they lean on or distorted (`CandidatesController`,
`Candidate`/`Project`, the endpoint/entity/spec partials that grew comment
hooks, `sidebar_controller`, the React form). Pre-existing untouched core
(`Diff::*` except `LineIndexMap`, `json_schema_parser`, `node/*`) is out.

## Slices

Reviewed as vertical, full-stack features — click → Stimulus → route →
controller → model → DB → render → DOM. Not as layers.

1. **Candidate conversation** — post, reply, nest. The smallest complete loop.
2. **Card-anchored comments** — comment mode, click a card, thread pins beside
   it, sidebar badge updates live.
3. **Line-anchored comments** — pick a row in a JSON tree, inline vs. below
   placement, and going Outdated when the API changes underneath.
4. **Resolve / reopen** — resolve collapses a thread; a reply reopens it.
5. **Comments in the edit form** — server-rendered HTML shipped through a JSON
   attribute into React.
6. **The follow-ups** — hide/show toggle and Display popover, version⇄candidate
   navigation, Table/Activity projects page.

`CommentAnchor` and `CommentsHelper` get no slot of their own. They surface in
slices 1–3 from three directions, judged under load rather than read cold.

## Protocol per slice

1. Orientation: what the slice does, which files, how data flows. No verdicts.
2. Author reads the files, in a suggested order.
3. **Author's instinct first** — what bothers them, what it should look like.
4. *Then* the assistant's read: weaknesses, 2–3 alternative shapes with
   trade-offs, a recommendation.
5. Decide → refactor → specs green → visual check where it renders → commit.
6. Judgment calls appended to `docs/review/judgment-log.md`.

Tests are reviewed with the slice they belong to, not separately. The question
is whether a spec tests behavior or restates the implementation.

Cross-cutting code gets named when hit. Fix immediately if clearly right;
otherwise it goes to the log's cross-cutting section and is settled once enough
uses have been seen. Slice 2 does not pretend to have slice 3's information.

## Closing passes

**Confidence gap** — the whole suite, once the code has stopped moving. What
is untested that matters (~350 lines of Stimulus have no tests; the comment
interaction is covered only at the request level), and what is tested that
shouldn't be. Mutation testing is a candidate here — it is the only tool that
measures whether the suite would actually catch a behavior change — subject to
checking its cost and licensing.

**Harvest** — turn the judgment log into the real deliverable. Where each rule
lands (repo `CLAUDE.md`, a skill, memory) is decided then, with the rules in
hand.

## Conventions for this session

- Refactors go straight to `main`. Ask before every commit.
- First commit deletes `docs/superpowers/` (19 files, ~7,000 lines). Git keeps
  them.
- This file and the judgment log live in `docs/review/`. At the end of the
  session this file is deleted too — only the harvested rules survive.

## Rules banked so far

**R1 — Full-stack picture is king.** Review and reason about features
vertically. A per-layer view is misleading: it shows the abstraction without
the load it is carrying.

**R2 — Plan/design docs are pre-implementation artifacts.** Useful to review
before the build, garbage once it lands. Delete them when the feature ships
rather than accumulating them.

**R3 — A refactor must not change behavior, and the proof is per-case.**
Pick the cheapest honest safety net for the change at hand:

- *Trivial and obviously safe* (rename, extract with no logic change) — just do
  it. `bin/rubocop` and a green suite are enough.
- *Covered by existing behavior tests* — refactor, and those specs must stay
  green **unmodified**. If a spec has to change, stop and name why: either the
  refactor changed behavior, or the spec was testing implementation. Both are
  findings.
- *Not covered but testable* — add a characterization test that passes
  **before** the refactor, then refactor. This is a net, not a spec, and is not
  the failing-test-first workflow the author rejects.
- *Not covered and hard to test* (Stimulus, DOM, visual) — say so out loud, and
  choose deliberately: accept the risk behind a visual check, or skip the
  refactor. Do not pretend a net exists.

Deliberate behavior changes are welcome but never smuggled inside a refactor.
They are agreed separately and committed separately.
