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
      - uses: actions/checkout@v4
      - uses: gitdhillonai/conereplay-action@v1
        with:
          traces: traces/            # a file, a directory, or a glob
          modify: changes/new-policy.json
          fail-on: outcome-change:5%
```

A single trace file runs `conereplay replay`; a directory or glob runs `conereplay corpus` across all of them. The report is posted as one PR comment, which is updated on each new push instead of stacking up. The same report goes to the job summary.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `traces` | required | Trace file, directory, or glob (JSON or JSONL from `conereplay.Recorder`). |
| `modify` | required | Modification JSON describing the proposed change. |
| `report` | `conereplay-report.md` | Where the Markdown report is written. |
| `fail-on` | `outcome-change:1%` | Fail the check above this outcome-change rate. `never` only reports. |
| `comment` | `true` | Post or update the PR comment. |
| `github-token` | `github.token` | Needs `pull-requests: write`. |
| `conereplay-version` | `0.1.1` | Version installed from PyPI. |
| `python-version` | `3.11` | Python 3.11+. |

## Outputs

`report`, `outcome-change-rate` (percent), `comment-url`.

## Example

`example/` holds three sanitized refund-workflow traces and a policy change (30-day to 5-day window). This repo's `self-test` workflow runs the action on them for every PR.

ConeReplay is proprietary, patent-pending software. This action only installs the published package.
