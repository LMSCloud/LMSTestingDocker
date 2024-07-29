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
git checkout -B 22.11 origin/22.11 && git checkout -b ktd-lms
rsync -a --exclude='*.md' $LMSC_KTD_HOME/* $KTD_HOME
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
