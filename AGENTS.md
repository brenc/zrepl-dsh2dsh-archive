# AGENTS.md

## Project

zrepl: ZFS snapshot, replication and pruning daemon. It runs as root and
destroys snapshots, so correctness bugs here lose backups.

This repo (`brenc/zrepl`) is a downstream fork of `dsh2dsh/zrepl`, which is
itself a heavily rewritten fork of the original `zrepl/zrepl` (gRPC replaced
by REST/JSON, new config syntax, `slog`, bubbletea TUI). Go 1.27, module path
`github.com/dsh2dsh/zrepl`. Pure Go, always built with `CGO_ENABLED=0`.

## Fork workflow

Read `FORK.md` before syncing upstream or preparing an upstream PR.

- `main` carries fork-only files (this file, `FORK.md`, `fork/`). Upstream
  rejects AI tooling, so these must never reach a PR branch.
- Upstream PR work happens on `pr/<topic>` branches cut from
  `upstream/master`, never from `main`. Run `git pr-check` before pushing one.
- Don't rename the module path; it would make every upstream merge conflict.
- Avoid editing upstream-owned files on `main` for fork-only reasons (CI,
  Makefile, README): each such edit is a future merge conflict.
- The security audit lives in the private repo `brenc/zrepl-notes`, not
  here. Never write vulnerability details into this public repo.

## Commands

These match what upstream's GitHub Actions run. Tools needed on `PATH`: Go
1.27, `golangci-lint` v2, `goreleaser` v2.

| Task | Command |
|------|---------|
| Build (host) | `CGO_ENABLED=0 go build -o zrepl .` |
| Build (all release targets) | `goreleaser build --snapshot --clean --skip=before` |
| Test | `CGO_ENABLED=0 go test ./...` |
| Coverage | `CGO_ENABLED=0 go test -covermode=atomic -coverprofile=cover.out ./...` |
| Race detector | `CGO_ENABLED=1 go test -race ./...` |
| Vet | `CGO_ENABLED=0 go vet ./...` |
| Lint | `golangci-lint run ./...` |
| Format | `golangci-lint fmt ./...` (gofumpt + goimports) |
| Generate | `go generate ./...` (see Code generation) |
| All checks | `go vet ./... && golangci-lint run ./... && go test ./...` |

Single package or test:

```sh
CGO_ENABLED=0 go test ./internal/config/...
CGO_ENABLED=0 go test -run TestFunctionName ./internal/endpoint/...
```

`goreleaser build` writes to `.build/<name>_<os>_<arch>/zrepl` (gitignored)
for linux and freebsd, amd64 and arm64, with the version stamped in. Keep
`--skip=before`: the config's `before` hooks run `go mod tidy` and
`go mod vendor`, which modify the working tree.

## Legacy build files: do not use

`Makefile`, `.circleci/`, `build/` and `packaging/` are leftovers from the
original zrepl, last changed by its maintainer. Upstream builds with plain
`go` and goreleaser. The Makefile is broken in several ways:

- `GO_LDFLAGS` and `-coverpkg` point at `github.com/zrepl/zrepl`, so
  `make zrepl-bin` builds without a version and `COVER=1` measures nothing.
- `make build/install` needs `build/tools.go`, which upstream deleted.
- `make generate` runs `protoc` on `.proto` files that no longer exist.
- `make test-platform` targets `internal/platformtest`, which was deleted.
- `make format` uses the wrong import prefix.

`make vet` and plain `make test-go` still work. `docs/` (Sphinx) is mostly
original zrepl documentation; upstream documents its changes in `README.md`.

## CI

- `.github/workflows/go.yml` (build + test) triggers only on the `master`
  branch, so it doesn't run on our `main`.
- `golangci-lint.yml` runs on `master`, `main` and PRs, with lint `latest`.
- `release.yml`: goreleaser on `v*` tags. `snapshot.yml`: manual.

## Testing

Unit tests only. There are no tests against real ZFS: upstream deleted the
platform test suite, and `zfs` calls in tests are faked
(`internal/zfs/test_helpers/`, `ZfsBin` swapped in `zfs_test.go`).

Total statement coverage is about 20%, and lowest where data safety lives:

| Package | Coverage |
|---------|----------|
| `endpoint` (send/recv, holds, placeholders) | ~7% |
| `replication/logic` (planning, step building) | ~6% |
| `daemon/pruner` | ~8% |
| `daemon/snapper` | 0% |
| `pruning` (keep rules) | ~73% |
| `zfs/filter` (dataset filters) | ~77% |
| `config` | ~65% |

Any change to send, receive, replication planning, pruning or dataset
filtering needs new tests for the changed behavior, and verification on a
throwaway ZFS pool before it ships. `fork/testpool.ts` (Bun, Linux and
FreeBSD) builds one: file-backed source and destination pools, a push/sink
config over localhost HTTP, and a `verify` command that checks every
dataset replicated or stayed excluded as intended. Pool commands need root.

Run the race detector too: `CGO_ENABLED=1 go test -race ./...`. Upstream
never does (it builds with cgo off), and as of `afc56a6f` it fails in
`internal/zfs/zfscmd` (`TestCmd_Pipe`): with `execpipe`, the pipeline's
processes write stderr into one shared `bytes.Buffer` concurrently.

## Architecture

- `main.go` → `internal/cli`: cobra CLI and subcommands
- `internal/client`: CLI-side commands (`status` TUI, `monitor`, `signal`,
  `test`, `configcheck`, `migrate`, `zfs-abstraction`), plus `jsonclient`
  for the daemon API
- `internal/daemon`: daemon main, HTTP server, control socket, Prometheus
  - `job`: job types (snap, push, pull, sink, source; active vs passive
    side)
  - `middleware`: HTTP auth, logging, metrics, JSON handlers
  - `snapper`, `pruner`, `hooks`: snapshotting, pruning runs, pre/post hooks
- `internal/config`: YAML config parsing (`go.yaml.in/yaml/v4`) and
  validation (`go-playground/validator`, `creasty/defaults`)
- `internal/endpoint`: sender/receiver side of replication over ZFS
- `internal/replication`: `driver` (attempts, retries) and `logic`
  (planning; `pdu` holds the hand-written wire types)
- `internal/pruning`: keep rules (`grid`, `last_n`, `regex`,
  `not_replicated`)
- `internal/zfs`: `zfs` CLI wrappers; `zfscmd` (exec, pipes), `dataset`
  (paths), `filter` (dataset include/exclude rules)

## Code generation

`//go:generate` produces `*_enumer.go` (enumer) and `*_string.go` (stringer).
Generated files are committed; don't edit them by hand.

The committed enumer files came from `github.com/alvaroloes/enumer`, which
panics on Go 1.27. `github.com/dmarkham/enumer` works but regenerates every
enumer file with extra methods. Regenerate only when a `//go:generate` type
changes, and then only that file. Stringer is
`golang.org/x/tools/cmd/stringer`.

## Code conventions (enforced by `.golangci.yaml`)

- gofumpt with extra rules; goimports with local prefix
  `github.com/dsh2dsh/zrepl`.
- `//nolint` must name the linter and give a reason (`nolintlint`).
- `slog` calls use attributes only (`sloglint: attr-only`), e.g.
  `log.With(slog.String("fs", name)).Info("...")`.
- `wrapcheck`: wrap errors from outside packages; errors from
  `github.com/dsh2dsh/zrepl/*` and `encoding/*` are exempt.
- Tests use testify; `paralleltest` and `testifylint` are on.
