# LMSTestingDocker

> This project adds the missing pieces to get the community ktd running with LMSCloud's custom fork of koha.

## Usage

To use this repo, you first need to setup the [community ktd](https://gitlab.com/koha-community/koha-testing-docker).
Then you'll need to add some additional variables to your .bashrc, .zshenv or whatever.

This is the config I currently use.

```sh
export LMSC_PROJECTS_DIR="$HOME/Projects/lmsc"
export LMSC_PROJECTS_DIR="$LMSC_PROJECTS_DIR"
export LMSC_SYNC_REPO="$LMSC_PROJECTS_DIR/Koha-LMSCloud"
export LMSC_KTD_HOME="$LMSC_PROJECTS_DIR/LMSTestingDocker"
```

Then, cp the directory contents to a local branch of the original ktd-repo.

```sh
cd $KTD_HOME
git checkout -B 22.11 origin/22.11 \
  && git checkout -b ktd-lms # optional
rsync -a --exclude='*.md' $LMSC_KTD_HOME/* $KTD_HOME
git checkout main -- docker-compose-arm64.yml
```

And run docker compose.

```sh
KOHA_IMAGE=ghcr.io/lmscloudpauld/lmscloud-koha-aarch64:latest
  docker compose \
  -f docker-compose-arm64.yml \
  -f docker-compose-lmscloud.yml \
  # -f docker-compose.koha-public-library-api.yml \
  -p koha \
  up
```

Depending on your architecture swap out these values in the `docker compose` call.

| arch        | amd64                                               | arm64                                                |
| ----------- | --------------------------------------------------- | ---------------------------------------------------- |
| base image  | `ghcr.io/lmscloudpauld/lmscloud-koha-x86_64:latest` | `ghcr.io/lmscloudpauld/lmscloud-koha-aarch64:latest` |
| entry point | `docker-compose-light.yml`                          | `docker-compose-arm64.yml`                           |

## Running 24.11.x code on a 22.11 image

After the merge of upstream/24.11.x, new Perl dependencies are required that aren't in the 22.11 container image. The `docker-compose-lmscloud.yml` handles this via:

1. **Volume mount** of a patched `run.sh` that supports `EXTRA_CPAN` / `EXTRA_APT` environment variables
2. **Environment variable** `EXTRA_CPAN` listing the missing modules

The patched `run.sh` installs these dependencies at container startup, before any Koha code runs. This avoids needing to rebuild the Docker image.

To add more missing dependencies as they're discovered, append them (space-separated) to the `EXTRA_CPAN` value in `docker-compose-lmscloud.yml`.

Once a 24.11 Docker image is built, these workarounds can be removed.
