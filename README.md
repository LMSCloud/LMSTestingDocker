<h1 align="center">Welcome to LMSTestingDocker 👋</h1>
<p>
  <img alt="Version" src="https://img.shields.io/badge/version-0.1.0-blue.svg?cacheSeconds=2592000" />
</p>

> This project adds the missing pieces to get the community ktd running with LMSCloud's custom fork of koha.

## Usage

To use this repo, you first need to setup the [community ktd](https://gitlab.com/koha-community/koha-testing-docker).
Then you'll need to add some additional variables to your .bashrc, .zshenv or whatever.

This is the config I currently use. Some of these vars may be unnecessary (atm). 
```sh
export LMS_PROJECTS_DIR=~/.local/src/lmsc
export LMS_PROJECTS_DIR="$LMS_PROJECTS_DIR"
export LMS_SYNC_REPO=$LMS_PROJECTS_DIR/Koha-LMSCloud
export LMS_KTD_HOME=$PROJECTS_DIR/koha-testing-docker
export LMS_PATH=$PATH:$KTD_HOME/bin
```

## Show your support

Give a ⭐️ if this project helped you!

***
_This README was generated with ❤️ by [readme-md-generator](https://github.com/kefranabg/readme-md-generator)_
