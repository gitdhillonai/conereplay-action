# ConeReplay GitHub Action

Replay recorded agent traces against a proposed change on every pull request, and post the divergence report straight into the PR as a comment. Built on [conereplay](https://pypi.org/project/conereplay/) ([conereplay.com](https://conereplay.com)).

## Usage

```yaml
name: conereplay
on: pull_request
permissions:
  contents: read
  pull-requests: write
jobs:
  replay:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
      - uses: gitdhillonai/conereplay-action@v1
        with:
          traces: traces/            # a file, a directory, or a glob
          modify: changes/new-policy.json
          fail-on: outcome-change:5%
```

The same workflow is in `examples/workflow.yml`.

A single trace file runs `conereplay replay`. A directory or a glob runs `conereplay corpus`. The glob string is passed through to conereplay, which expands it. The report is posted as one PR comment. A later run on the same pull request updates that comment and removes older comments that carry the same hidden marker. The same report is appended to the job summary.

The action creates a virtualenv with the runner's Python and installs `conereplay` with `pip` at the pinned `conereplay-version`. It does not download a shell script or a Python build. The runner must already provide Python 3.11 or newer (`python3.11` or `python3`). `actions/setup-python` is not used, because that action's archive contains symlinks and this repo's self-hosted runner cannot create them while extracting it.

## Permissions

| Scope | Access | Why |
|---|---|---|
| `contents` | read | Check out the traces and the modification file. |
| `pull-requests` | write | Create or update the report comment. |

`github-token` defaults to `github.token`. On a pull request opened from a fork, GitHub does not grant that token write access. The action then logs `no pull-requests write token` and exits the comment step successfully. The report remains in the job log and the job summary.

`fail-on` accepts `never` or `outcome-change:<number>%` (for example `outcome-change:5%`). The check fails with exit 1 only when the measured rate is above the threshold. An equal rate passes. Any other value exits 2. A single file reports `100` or `0` because the CLI prints a boolean. A directory or glob reports the corpus percentage, such as `100.0`.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `traces` | required | Trace file, directory, or glob (JSON or JSONL from `conereplay.Recorder`). |
| `modify` | required | Modification JSON describing the proposed change. |
| `report` | `conereplay-report.md` | Where the Markdown report is written. |
| `fail-on` | `outcome-change:1%` | `never`, or `outcome-change:<number>%`. Exit 1 above the threshold, exit 2 if the value is invalid. |
| `comment` | `true` | Post or update the single PR comment. |
| `github-token` | `github.token` | Needs `pull-requests: write` on same-repo pull requests. |
| `conereplay-version` | `0.1.2` | Exact version installed from PyPI. |
| `python-version` | `3.11` | Preferred `pythonX.Y` already installed on the runner. `python3` is used when it is 3.11 or newer. |

## Outputs

`report`, `outcome-change-rate` (percent), `comment-url`.

## Example

`example/` holds three sanitized refund-workflow traces and a policy change (30-day to 5-day window). `examples/workflow.yml` is the workflow above. This repo's `self-test` workflow runs the script tests, then runs the action on a file, the directory, and the glob for every pull request and every push to `main`.

## Tests

```bash
python3 -m venv .venv
.venv/bin/pip install 'conereplay==0.1.2'
PATH=".venv/bin:$PATH" bash tests/run_all.sh
```

Needs `bash` and `jq`. The tests call the published `conereplay` 0.1.2 package and a local stub for the shell scripts.

This repository is not listed on the GitHub Marketplace.

ConeReplay is proprietary, patent-pending software. This action only installs the published package.
