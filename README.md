# LMSTestingDocker

LMSCloud's extensions for Koha Testing Docker (KTD) and a two-phase build
pipeline for producing container images with a locally-built Koha package.

Upstream KTD installs `koha-common` from the public apt repo. This pipeline
builds `koha-common` from a Koha-LMSCloud (LMSCloud's Koha fork) checkout
instead and injects it into a KTD-style image.

## Layout

```
tools/                        Build pipeline
tools/install-node-modules.sh Install node_modules via a Linux Node container
dists/lmscloud/files/run.sh   KTD entrypoint with LMS-specific hooks
docker-compose-lmscloud.yml   Compose overlay for dev use
docker-compose.worktree.yml   Compose overlay: use a git worktree as sync repo
out/debian/                   .deb build output (git-ignored)
```

## Requirements

- Docker with buildx (for multi-arch / `--push`)
- `LMSC_SYNC_REPO` pointing to a local Koha-LMSCloud checkout
- The checkout must have `.github/scripts/build-koha.sh`

## Quick start

```bash
export LMSC_SYNC_REPO="/path/to/Koha-LMSCloud"

# Build .deb and image for local use (arm64)
./tools/build-image.sh \
  --koha-version <X.Y.Z>lmscloud \
  --koha-branch <koha-branch> \
  --ktd-branch 25.11 \
  --platforms linux/arm64

# Multi-arch + push to ghcr.io (needs PAT with write:packages)
./tools/build-image.sh \
  --koha-version <X.Y.Z>lmscloud \
  --koha-branch <koha-branch> \
  --ktd-branch 25.11 \
  --platforms linux/amd64,linux/arm64 \
  --push
```

Set `DEBUG=1` to enable bash-trace inside the Phase A container.

## Image tag convention

| Platform                              | Image                                              |
| ------------------------------------- | -------------------------------------------------- |
| `linux/arm64`                         | `<registry>/lmscloud-koha-aarch64:<version>`       |
| `linux/amd64`                         | `<registry>/lmscloud-koha-x86_64:<version>`        |
| multi-arch                            | `<registry>/lmscloud-koha:<version>` (no suffix)   |

The `lmscloud` suffix in the version (e.g. `25.11.03lmscloud`) is stripped
when forming the tag — the registry namespace already says `lmscloud-koha`.

The default `<registry>` is `ghcr.io/lmscloudpauld` (the namespace this
repo's pipeline currently publishes to). Override with `LMS_REGISTRY` (or
`--registry` on `build-ktd-image.sh`) when forking or pushing elsewhere.

### Provenance and rollback

The version tag is rolling — every rebuild of the same Koha version overwrites
it. Alongside it, tag each push with the short commit of the Koha-LMSCloud tree
it was built from:

| Purpose                       | Example                             |
| ----------------------------- | ----------------------------------- |
| Rolling, latest build         | `lmscloud-koha-aarch64:25.11.03`    |
| Immutable, one source commit  | `lmscloud-koha-aarch64:25.11.03-27f28ae` |

```bash
docker tag <image>:25.11.03 <image>:25.11.03-$(git -C "${LMSC_SYNC_REPO}" rev-parse --short HEAD)
```

The commit suffix, not a date stamp: the same Koha version gets rebuilt from
different trees, so "which tree is inside this image" is the question a tag
needs to answer, and a build date does not answer it.

For reproducible deployments pin the digest rather than any tag — it survives
someone else overwriting the rolling tag:

```bash
docker buildx imagetools inspect <image>:25.11.03   # prints Digest: sha256:...
KOHA_IMAGE=<image>@sha256:<digest> docker compose -f docker-compose-lmscloud.yml up
```

## KTD branch → Debian dist

| KTD branch                         | Debian dist |
| ---------------------------------- | ----------- |
| `24.05`, `24.11`                   | bullseye    |
| `25.05`, `25.11`                   | bookworm    |
| `26.05`, `26.11`, `master`, `main` | trixie      |
| anything else                      | bookworm    |

## Running the image

```bash
KOHA_IMAGE=ghcr.io/lmscloudpauld/lmscloud-koha-aarch64:25.11.03 \
SKIP_DATA_INIT=yes \
docker compose -f docker-compose-lmscloud.yml up
```

The compose overlay mounts `${LMSC_SYNC_REPO}` at `/kohadevbox/koha`. The
patched `run.sh` is baked into the image at build time.

`${LMSC_SYNC_REPO}` may be a Git worktree; `run.sh` detects
`GIT_WORKTREE_SOURCE` and adds the main-checkout root to `safe.directory`
so git ops as the instance user don't trip on dubious-ownership.

`ktd --wait-ready N` works against this image — `run.sh` writes
`/ktd_ready` once init completes.

### Runtime environment variables

LMSCloud-specific:

| Variable | Effect |
|---|---|
| `SKIP_DATA_INIT=yes` | Skip `do_all_you_can_do.pl` (DB schema + seed data). Populate manually after boot. |

Carried over from upstream KTD's `run.sh`:

| Variable | Effect |
|---|---|
| `EXTRA_APT` | apt packages to install before any Koha code runs |
| `EXTRA_CPAN` | CPAN modules to install before any Koha code runs |
| `CPAN=yes` | Install latest versions of installed CPAN deps via `cpan-outdated` |
| `INSTALL_MISSING_FROM_CPANFILE=yes` | `cpanm --installdeps ${BUILD_DIR}/koha/` at boot (slow — prefer baking deps into the image) |
| `USE_EXISTING_DB=yes` | Pass `--use-existing-db` to `do_all_you_can_do.pl` |
| `SKIP_L10N=yes` | Skip auto-clone/fetch of `koha-l10n` into `misc/translator/po` |
| `SKIP_CYPRESS_CHOWN=yes` | Skip recursive chown of `/kohadevbox/Cypress` after UID remap |
| `ENABLE_PLUGINS=yes` | Wire `${BUILD_DIR}/plugins/*` entries into `koha-conf.xml` |
| `RUN_TESTS_AND_EXIT=yes` + `TEST_SUITE=…` | Run a named suite (`light`, `es-only`, `selenium-only`, `all-perl-tests`, `db-compare-only`, `specific-tests`) via `misc4dev/run_tests.pl` and exit |
| `DEBUG_RUN=yes` + `DEBUG_RUN_URL` | wget a remote `run.sh` and exec it instead — iterate without rebuilding the image |
| `DEBUG_GIT_REPO_MISC4DEV=yes` (+ `_URL` + `_BRANCH`) | Re-clone `misc4dev` from the given branch |
| `DEBUG_GIT_REPO_QATESTTOOLS=yes` (+ `_URL` + `_BRANCH`) | Re-clone `qa-test-tools` |

## Using a git worktree as the sync repo

`LMSC_SYNC_REPO` can point at a linked git *worktree*, but two macOS-specific
snags will otherwise stop the stack from booting:

1. **`fatal: not a git repository` → koha exits 128.** A worktree's `.git` is a
   file pointing at the main checkout's gitdir by absolute host path, which
   isn't mounted into the container. Layer in `docker-compose.worktree.yml`,
   which bind-mounts the main checkout's `.git` at its identical host path:

   ```bash
   export LMSC_SYNC_REPO=/path/to/koha-lmscloud-worktree
   export LMSC_GIT_COMMONDIR=/path/to/Koha-LMSCloud/.git   # the MAIN checkout's .git
   ktd --name lmscloud \
     -f docker-compose-lmscloud.yml \
     -f docker-compose.worktree.yml \
     up
   ```

2. **Asset build fails (`@rspack/binding-linux-*` missing / `rspack: not
   found`).** A `node_modules` installed on macOS carries the wrong native
   bindings. Install them in a Linux Node container first:

   ```bash
   ./tools/install-node-modules.sh --repo /path/to/koha-lmscloud-worktree
   ```

   (Defaults to `$LMSC_SYNC_REPO` and Node 18 — see `--help`.) Run this once
   before starting the stack, or whenever the branch's JS dependencies change.

## Legacy 22.11 branch

For the old rsync-based 22.11 workflow, check out the `22.11` git branch and
follow its README. The tooling here does not apply.
