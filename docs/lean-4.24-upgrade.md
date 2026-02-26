Lean 4.24.0 Upgrade: blockers and migration plan
================================================

Scope
-----

This branch is a migration branch from `origin/master` with:

- `lean-toolchain` updated to `leanprover/lean4:v4.24.0`,
- `doc-gen4` updated to `v4.24.0`,
- mechanical compile-driven edits in `EvmEquivalence/` (API/index updates only),
- reproducible `evmyul` pin (git SHA, no local path dependency).

No direct `mathlib` dependency was added in this repository.

Concrete blockers
-----------------

1. Upstream `evmyul` is pinned to Lean 4.22 stack.
   - `evmyul/lean-toolchain` is `leanprover/lean4:v4.22.0`.
   - `evmyul/lakefile.lean` requires `mathlib` `v4.22.0` and 4.22-era transitive revisions.

2. Transitive package incompatibility under project Lean 4.24.
   - `lake +leanprover/lean4:v4.24.0 update` reports Mathlib toolchain mismatch via evmyul’s dependency graph.
   - `lake +leanprover/lean4:v4.24.0 build EvmEquivalence` fails in transitive packages (`batteries`, `aesop`, `proofwidgets`, and 4.22 mathlib linter code) before project modules can fully validate.

3. API drift in `EvmYul.step` call shape.
   - 4.24 requires explicit `(arg := .none)` at some call sites.
   - Project-side mechanical adaptations are needed across summaries/interfaces.

4. Reproducibility risk from local path dependency workflow.
   - Previous local migration attempts required `path = "../EVMYulLean"` and local uncommitted changes in that dependency.
   - That state is not suitable for upstream CI or review.

5. Semantic-risk hotspots must be isolated.
   - Opcode summaries/equivalences should not be semantically rewritten inside the toolchain migration PR.
   - Semantic corrections must be split and justified with differential evidence.

Root cause (why upgrade is not upstream yet)
--------------------------------------------

The project migration is blocked by dependency ecosystem readiness and reproducibility, not by a single toolchain-file bump. Upstream `evmyul` has not yet published a Lean 4.24-compatible, pinned revision for deterministic downstream use, and previous local migration work mixed environment fixes with proof/content churn.

Semantics-preserving migration procedure
---------------------------------------

1. Dependency reproducibility first.
   - Keep `evmyul` as a pinned git SHA (no local path in upstream PR).
   - Wait for/publish a Lean-4.24-compatible `evmyul` revision.

2. Mechanical compile pass only.
   - Apply only compile-driven API/index edits.
   - Do not change theorem intent/specification in this phase.

3. Guardrails (added in `scripts/lean424`).
   - Trust gate:
     - `scripts/lean424/check_trust_base.sh origin/master HEAD`
   - Signature drift gate:
     - `python3 scripts/lean424/check_signature_drift.py --base origin/master --head HEAD`
   - Differential snapshot gate (baseline vs candidate):
     - `scripts/lean424/run_differential_harness.sh <base-worktree> <candidate-worktree>`

4. Split any true semantic fixes.
   - If semantic deltas appear in the differential harness, move fixes into a separate PR with explicit before/after evidence.

PR topology
-----------

Recommended upstream order:

1. Toolchain + dependency migration (mechanical, reproducible).
2. Compile/proof repairs caused by API drift (still non-semantic).
3. Any semantic corrections (only with explicit differential evidence).
