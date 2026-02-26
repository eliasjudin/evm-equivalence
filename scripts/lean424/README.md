Lean 4.24 migration guardrails
------------------------------

This folder isolates migration checks so toolchain/API updates do not silently change proof intent.

Files:

- `check_trust_base.sh`: fails if the diff adds `sorry`, `axiom`, or `private axiom`.
- `check_signature_drift.py`: reports declaration signature drift in changed `.lean` files (with optional allowlist).
- `DifferentialHarness.lean`: deterministic opcode snapshot harness.
- `run_differential_harness.sh`: runs the harness on a baseline branch and candidate branch, then diffs results.

Usage:

```bash
# From repository root.
scripts/lean424/check_trust_base.sh origin/master HEAD
python3 scripts/lean424/check_signature_drift.py --base origin/master --head HEAD
scripts/lean424/run_differential_harness.sh /path/to/base/worktree /path/to/candidate/worktree
```
