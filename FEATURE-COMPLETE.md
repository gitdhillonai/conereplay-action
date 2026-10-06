# Feature complete

Observed on 2026-10-06. Local suite command, from a checkout of `05dd3620eb559754cb0e5eb07606c4e8364e779d`:

```bash
/opt/homebrew/bin/python3.11 -m venv /tmp/cr-venv311
/tmp/cr-venv311/bin/pip install 'conereplay==0.1.2'
PATH="/tmp/cr-venv311/bin:$PATH" bash tests/run_all.sh
```

That run printed `comment: 10 passed`, `gate: 37 passed`, `python: 4 passed`, and `run: 10 passed`. The same command on the tree that added the JSONL checks printed `run: 12 passed`. The other three counts were unchanged.

Live proof is the self-hosted runner `mac-docker-conereplay-action` and a GitHub-hosted `ubuntu-latest` job. The comment proof is pull request https://github.com/gitdhillonai/conereplay-action/pull/1, workflow run https://github.com/gitdhillonai/conereplay-action/actions/runs/37505537062. The later `main` run that also covered JSONL, the 5% gate, and `ubuntu-latest` is https://github.com/gitdhillonai/conereplay-action/actions/runs/37523084318 at `c80fea0`. Jobs `tests`, `ubuntu`, `threshold`, and `replay` completed with conclusion SUCCESS. `fork-fallback` was skipped because that event was a push.

Nothing is hosted. There is no deploy step.

| feature | status | test | evidence |
|---|---|---|---|
| Replay one trace file with `conereplay replay` | DONE | `tests/test_run.sh` (`published package replays one fixture file`); workflow step `Replay one trace file` | Run 37505537062 log: `outcome_changed=True, token_delta=+14`. Installed `conereplay==0.1.2` from PyPI into a virtualenv. |
| Replay a directory with `conereplay corpus` | DONE | `tests/test_run.sh` (`published package replays the fixture directory`); workflow step `Replay a directory of traces` | Same run log: `traces=3, processed=3, outcome_change_rate=100.0%`. |
| Replay a glob, passed through without shell expansion | DONE | `tests/test_run.sh` (`glob is passed to corpus without shell expansion`, `published package replays the fixture glob`); workflow step `Replay a glob of traces` | Same run log: `outcome_change_rate=100.0%` for `example/traces/*.json`. The PR comment lists `refund-order-a.json`, `refund-order-b.json`, and `refund-order-c.json`. |
| `fail-on` accepts `never` and `outcome-change:<number>%`; exit 1 above the threshold; exit 2 when invalid | DONE | `tests/test_gate.sh` (37 passed). Workflow job `threshold` runs the action. | Run 37523084318 logged `outcome-change rate 100.0% is above the 5% threshold` and `invalid fail-on 'nope'`. Both steps had outcome `failure`, and the following steps logged `outcome-change:5% failed the check` and `invalid fail-on failed the check`. The job succeeded. |
| One pull request comment, updated on the next run | DONE | `tests/test_comment.sh` (create, patch, duplicate removal) | Issue comment 6021991674, created `2026-10-06T17:42:07Z`, updated `2026-10-06T17:42:16Z`. It is the only comment on the pull request. File, directory, and glob steps each logged `Posted ConeReplay report: https://github.com/gitdhillonai/conereplay-action/pull/1#issuecomment-6021991674`. The stored body is the three-trace corpus report at 100.0%. |
| No write token: log and continue | DONE | `tests/test_comment.sh` (empty token does not call curl; HTTP 403 skips; HTTP 500 fails) | Same run, job `fork-fallback`, token permission `PullRequests: read`. Log: `GitHub API returned HTTP 403` and `skipping PR comment; no pull-requests write token`. Next step logged `fork fallback left comment-url empty`. This was the same repository with a read-only job token, not a pull request opened from a fork. |
| Fixture traces and modification | DONE | `tests/test_run.sh` and the replay job | `example/traces/refund-order-a.json`, `refund-order-b.json`, `refund-order-c.json`, and `example/modify.json`. The comment quotes target event `e3` and substituted output `POLICY: 5 days`. |
| Self-test workflow on this repo's pull requests | DONE | `.github/workflows/self-test.yml` | Run 37505537062 on pull request 1. `contents: read` and `pull-requests: write` on `tests` and `replay`. `fork-fallback` set `pull-requests: read`. |
| Example workflow on `ubuntu-latest` | DONE | `.github/workflows/self-test.yml` job `ubuntu`, same inputs as `examples/workflow.yml` with `fail-on: never` and `comment: false`. | Run 37523084318 job `ubuntu` logged `ubuntu-latest replay rate=100.0`. |
| JSONL trace file and a directory of JSONL | DONE | `tests/test_run.sh` (`published package replays a JSONL trace`, `published package replays a directory of JSONL traces`). Workflow step `Replay a JSONL trace`. | `example/jsonl/refund-order-a.jsonl` is six JSON lines. Run 37523084318 logged `outcome_changed=True, token_delta=+14` for that file. The output check required rate `100`. |
| Checkout pin and no downloaded installer | DONE | Workflow uses `actions/checkout@11d5960a326750d5838078e36cf38b85af677262` | That checkout step succeeded in all three jobs. `scripts/install.sh` pip-installed `conereplay==0.1.2`. `actions/setup-python` is not referenced. The runner's Python was `Python 3.12.3` at `/usr/bin/python3` when `python3.11` was absent. |
