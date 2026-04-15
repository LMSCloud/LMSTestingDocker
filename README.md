# LMSTestingDocker

LMSCloud's extensions for Koha Testing Docker (KTD) and a two-phase build
pipeline for producing container images with a locally-built Koha package.

Upstream KTD installs `koha-common` from the public apt repo. This pipeline
builds `koha-common` from a Koha-LMSCloud (LMSCloud's Koha fork) checkout
instead and injects it into a KTD-style image.

## Layout

```
tools/                      Build pipeline
dists/lmscloud/files/run.sh KTD entrypoint with LMS-specific hooks
docker-compose-lmscloud.yml Compose overlay for dev use
out/debian/                 .deb build output (git-ignored)
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

The compose overlay mounts `${LMSC_SYNC_REPO}` at `/kohadevbox/koha` and
overlays our patched `run.sh`. Supported environment variables: `SKIP_DATA_INIT`,
`EXTRA_APT`, `EXTRA_CPAN`.

## Legacy 22.11 branch

For the old rsync-based 22.11 workflow, check out the `22.11` git branch and
follow its README. The tooling here does not apply.
