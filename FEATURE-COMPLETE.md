# Feature complete

Observed on 2026-10-06. Local suite command, from a checkout of `05dd3620eb559754cb0e5eb07606c4e8364e779d`:

```bash
/opt/homebrew/bin/python3.11 -m venv /tmp/cr-venv311
/tmp/cr-venv311/bin/pip install 'conereplay==0.1.2'
PATH="/tmp/cr-venv311/bin:$PATH" bash tests/run_all.sh
```

That run printed `comment: 10 passed`, `gate: 37 passed`, `python: 4 passed`, and `run: 10 passed`.

Live proof is the self-hosted runner `mac-docker-conereplay-action` on pull request https://github.com/gitdhillonai/conereplay-action/pull/1. Workflow run: https://github.com/gitdhillonai/conereplay-action/actions/runs/37505537062. Head `05dd3620eb559754cb0e5eb07606c4e8364e779d`. The `pull_request` merge ref printed in the comment was `ad0a9c916766ac72d44f823e79652532052e6e63`. Jobs `tests`, `replay`, and `fork-fallback` completed with conclusion SUCCESS.

Nothing is hosted. There is no deploy step.

| feature | status | test | evidence |
|---|---|---|---|
| Replay one trace file with `conereplay replay` | DONE | `tests/test_run.sh` (`published package replays one fixture file`); workflow step `Replay one trace file` | Run 37505537062 log: `outcome_changed=True, token_delta=+14`. Installed `conereplay==0.1.2` from PyPI into a virtualenv. |
| Replay a directory with `conereplay corpus` | DONE | `tests/test_run.sh` (`published package replays the fixture directory`); workflow step `Replay a directory of traces` | Same run log: `traces=3, processed=3, outcome_change_rate=100.0%`. |
| Replay a glob, passed through without shell expansion | DONE | `tests/test_run.sh` (`glob is passed to corpus without shell expansion`, `published package replays the fixture glob`); workflow step `Replay a glob of traces` | Same run log: `outcome_change_rate=100.0%` for `example/traces/*.json`. The PR comment lists `refund-order-a.json`, `refund-order-b.json`, and `refund-order-c.json`. |
| `fail-on` accepts `never` and `outcome-change:<number>%`; exit 1 above the threshold; exit 2 when invalid | DONE | `tests/test_gate.sh` (37 passed, including equal, above, `never`, and invalid values) | Same run, `tests` job. Each replay step logged `ConeReplay: fail-on is never; reporting only` and the job stayed green at a 100% rate. |
| One pull request comment, updated on the next run | DONE | `tests/test_comment.sh` (create, patch, duplicate removal) | Issue comment 6021991674, created `2026-10-06T17:42:07Z`, updated `2026-10-06T17:42:16Z`. It is the only comment on the pull request. File, directory, and glob steps each logged `Posted ConeReplay report: https://github.com/gitdhillonai/conereplay-action/pull/1#issuecomment-6021991674`. The stored body is the three-trace corpus report at 100.0%. |
| No write token: log and continue | DONE | `tests/test_comment.sh` (empty token does not call curl; HTTP 403 skips; HTTP 500 fails) | Same run, job `fork-fallback`, token permission `PullRequests: read`. Log: `GitHub API returned HTTP 403` and `skipping PR comment; no pull-requests write token`. Next step logged `fork fallback left comment-url empty`. This was the same repository with a read-only job token, not a pull request opened from a fork. |
| Fixture traces and modification | DONE | `tests/test_run.sh` and the replay job | `example/traces/refund-order-a.json`, `refund-order-b.json`, `refund-order-c.json`, and `example/modify.json`. The comment quotes target event `e3` and substituted output `POLICY: 5 days`. |
| Self-test workflow on this repo's pull requests | DONE | `.github/workflows/self-test.yml` | Run 37505537062 on pull request 1. `contents: read` and `pull-requests: write` on `tests` and `replay`. `fork-fallback` set `pull-requests: read`. |
| Example workflow file | DONE | Not executed as its own workflow. The inputs it documents are the ones the self-test ran. | `examples/workflow.yml`. The run above used `runs-on: self-hosted`, not the file's `ubuntu-latest`. |
| Checkout pin and no downloaded installer | DONE | Workflow uses `actions/checkout@11d5960a326750d5838078e36cf38b85af677262` | That checkout step succeeded in all three jobs. `scripts/install.sh` pip-installed `conereplay==0.1.2`. `actions/setup-python` is not referenced. The runner's Python was `Python 3.12.3` at `/usr/bin/python3` when `python3.11` was absent. |
