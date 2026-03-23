# Releasing Vibe (seed compiler)

Vibe bootstraps from a **seed** `vibe_kernel` binary hosted on GitHub (not in git). Each seed tag corresponds to a self-hosted compiler that can compile the `.vibe` kernel **at that point in history**.

## Default download tag (`build.sh`)

`build.sh` defaults to **`v0.0.2-seed`** (macro-capable self-host). For commits that match an older kernel, use:

```bash
export VIBE_SEED_TAG=v0.0.1-seed
./build.sh build
```

When preparing a **new** seed tag, keep `build.sh` pointing at the **latest published** tag until the GitHub release exists (avoid 404 on clean clones). Publish with `./build.sh release-seed <tag>`, then bump `SEED_TAG` and docs in the same push as the release (or immediately after).

## Publish a new seed (maintainer)

### Option A — local

Requires [GitHub CLI](https://cli.github.com/) (`gh`) logged in with permission to create releases.

```bash
./build.sh release-seed v0.0.3-seed   # example next tag
```

This runs `./build.sh test`, copies `build/bin/vibe_kernel` to `build/release/vibe_kernel_seed`, strips it, then:

- If the GitHub release **exists**: uploads/replaces the `vibe_kernel_seed` asset (`--clobber`).
- Otherwise: `gh release create` with `doc/release-notes/<tag>.md` when that file exists.

Override repo: `GITHUB_REPOSITORY=owner/repo ./build.sh release-seed …`

### Option B — GitHub Actions

Workflow: **Release seed compiler** (`.github/workflows/release-seed.yml`), manual `workflow_dispatch`.

Runs on **macos-14**, installs LLVM via Homebrew, `./build.sh test`, strip, same `gh` create/upload logic.

**Caveat:** the job only succeeds if the **default** seed in `build.sh` can compile the current `main`. If not, use **Option A** on a machine with a working `vibe_kernel`, publish, then bump the default.

## Seed tags (reference)

| Tag           | Role |
|---------------|------|
| `v0.0.1-seed` | Original bootstrap chain; use via `VIBE_SEED_TAG` for old trees. |
| `v0.0.2-seed` | Default download: self-hosted compiler with in-kernel macro expander. |

## Platform

Seeds built on maintainer / Actions runners target **arm64-apple-darwin** (see `kernel/codegen.vibe`). Other targets need their own binary later.

## Asset name

The file must stay named **`vibe_kernel_seed`** (URLs in `build.sh` and `gh` asset name).
