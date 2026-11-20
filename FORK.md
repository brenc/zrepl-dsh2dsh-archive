# Fork workflow

This repo (`brenc/zrepl`) is a downstream fork of
[`dsh2dsh/zrepl`](https://github.com/dsh2dsh/zrepl), which is itself a fork
of the original `zrepl/zrepl`. We track dsh2dsh, build our own binaries from
our `main`, and only send changes upstream on purpose.

Upstream does not accept AI tooling in the repo, so **nothing fork-only may
ever reach a PR branch**.

## Remotes and branches

| Name | What it is |
|------|------------|
| `origin` | `github.com/brenc/zrepl`, ours |
| `upstream` | `github.com/dsh2dsh/zrepl`, default branch `master` |
| `main` | upstream + our fork-only commits. We build and deploy from this. |
| `pr/<topic>` | One upstream PR each, cut from `upstream/master`. |

Setup on a fresh clone:

```sh
git remote add upstream https://github.com/dsh2dsh/zrepl.git
git fetch upstream
git config alias.pr-check '!git show main:fork/check-pr-branch.sh | sh -s --'
```

## Fork-only paths

These live on `main` and must never appear in a PR branch:

- `AGENTS.md`, `CLAUDE.md`, `.claude/`, `.agents/`, `REVIEW.md`
- `FORK.md` (this file)
- `fork/` (tooling such as `fork/check-pr-branch.sh`)

The security audit and roadmap are kept out of this public repo, in the
private `brenc/zrepl-notes`, because they describe unfixed vulnerabilities.

Put any new fork-only material under `fork/` so this list stays short. If you
add a path elsewhere, add it here and to the pattern in
`fork/check-pr-branch.sh`.

## Syncing from upstream

Do this every week or two. Upstream code is untrusted until reviewed.

1. `git fetch upstream`
2. Review what's new before merging:
   `git log main..upstream/master` and
   `git diff $(git merge-base main upstream/master) upstream/master`.
   Record the result in `security_audit.md` in `brenc/zrepl-notes`
   (reviewed range, findings).
3. `git switch main && git merge upstream/master`
   (commit message: `chore: merge upstream dsh2dsh/zrepl master`)
4. `make vet && make lint && make test-go`
5. `git push origin main`
6. Production builds come from a tag on `main` that passed the steps above,
   never straight from upstream.

## Sending a PR upstream

1. Start from upstream, not `main`:

   ```sh
   git fetch upstream
   git switch -c pr/<topic> upstream/master
   ```

2. Make the change. Follow upstream's commit style (short plain subject, e.g.
   `Fix rollback error being ignored in ZFSRecv`), not our Conventional
   Commits convention.
3. Run the guard. It fails on fork-only paths, merge commits, or any commit
   that came from our `main`:

   ```sh
   git pr-check
   ```

   `fork/` doesn't exist on a PR branch, so the script is run from `main`
   through an alias. Set it up once per clone:

   ```sh
   git config alias.pr-check '!git show main:fork/check-pr-branch.sh | sh -s --'
   ```
4. Push and open the PR:

   ```sh
   git push -u origin pr/<topic>
   gh pr create -R dsh2dsh/zrepl --base master --head brenc:pr/<topic>
   ```

5. Get the fix into our build without waiting:
   `git switch main && git cherry-pick <sha>`. If upstream merges it, the next
   sync deduplicates it; if they change it, take their version on merge.

### Rules

- **Never** merge or cherry-pick from `main` into a `pr/` branch.
- **Never** open a PR from `main`.
- To update a PR branch with newer upstream, rebase it:
  `git rebase upstream/master`.
- Before pushing, read the full `git diff upstream/master...HEAD` yourself.
- Don't send security findings as public PRs or issues before checking how
  upstream wants them reported.
- Upstream closes anything that reads as AI-written without acting on it
  (issue #82, a real bug, was closed with "LLM output detected"). Keep PR
  descriptions and issues short, plain and written by a person, with a
  concrete reproduction.
