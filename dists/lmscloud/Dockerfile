# Define build argument for architecture
ARG arch

# Determine the correct base image
FROM debian:bullseye AS x86_64_base
FROM arm64v8/debian:bullseye AS aarch64_base

# Use the correct base image depending on the architecture argument
FROM ${arch}_base AS base

# Define build argument for the .deb package
ARG KOHA_PACKAGE

# Check if KOHA_PACKAGE is set and fail the build if it is not
RUN if [ -z "$KOHA_PACKAGE" ]; then echo "KOHA_PACKAGE argument not provided" && exit 1; fi

# File Author / Maintainer
LABEL maintainer="paul.derscheid@lmscloud.de"

# Set environment variables
ENV PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    DEBIAN_FRONTEND="noninteractive" \
    LANGUAGE="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    LC_CTYPE="en_US.UTF-8" \
    REFRESHED_AT="2023-03-20"

# Install apache2 and testting deps
# netcat: used for checking the DB is up
RUN apt-get -y update \
    && apt-get -y upgrade \
    && apt-get -y install \
      apache2 \
      build-essential \
      codespell \
      cpanminus \
      git \
      tig \
      libcarp-always-perl \
      libgit-repository-perl \
      libmemcached-tools \
      libmodule-install-perl \
      libperl-critic-perl \
      libtest-differences-perl \
      libtest-perl-critic-perl \
      libtest-perl-critic-progressive-perl \
      libfile-chdir-perl \
      libdata-printer-perl \
      pmtools \
      locales \
      netcat \
      python-gdbm \
      vim \
      tmux \
      wget \
      curl \
      apt-transport-https \
      mlocate \
      iproute2 \
   && rm -rf /var/cache/apt/archives/* \
   && rm -rf /var/lib/apt/lists/*

# Set locales
RUN    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && dpkg-reconfigure locales \
    && /usr/sbin/update-locale LANG=en_US.UTF-8

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8

# Prepare apache configuration
RUN a2dismod mpm_event
RUN a2dissite 000-default
RUN a2enmod rewrite \
    headers \
    proxy_http \
    cgi

# Add Koha development repositories
RUN echo "deb [signed-by=/usr/share/keyrings/koha-keyring.gpg] http://debian.koha-community.org/koha-staging dev main" >> /etc/apt/sources.list.d/koha.list \
    && echo "deb [signed-by=/usr/share/keyrings/koha-deps-keyring.gpg] http://deb3.kohaaloha.com/ka/koha-deps stable main bullseye" >> /etc/apt/sources.list.d/koha.list \
    && wget -qO - http://debian.koha-community.org/koha/gpg.asc | gpg --dearmor -o /usr/share/keyrings/koha-keyring.gpg \
    && wget -qO - http://deb3.kohaaloha.com/ka/koha-deps/gpg.asc | gpg --dearmor -o /usr/share/keyrings/koha-deps-keyring.gpg \
    && apt-get update \
    && apt-cache policy koha-common \
    && apt-cache policy libmojolicious-perl \
    && apt-cache policy libjson-validator-perl \
    && apt-cache policy libmojolicious-plugin-openapi-perl \
    && apt-cache policy libyaml-libyaml-perl \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

RUN mkdir /kohadevbox
WORKDIR /kohadevbox

# Install testing extras, packages and cpan
RUN apt-get -y update \
    && apt-get -y install \
    libexpat1-dev \
    libtemplate-plugin-gettext-perl \
    libdevel-cover-perl \
    libcrypt-cbc-perl \
    libmoosex-attribute-env-perl \
    libtest-dbix-class-perl \
    libtap-harness-junit-perl \
    libtext-csv-unicode-perl \
    libdevel-cover-report-clover-perl \
    libwebservice-ils-perl \
    libselenium-remote-driver-perl \
    inotify-tools \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/api/lists/*


# Copy and install Koha package
COPY ${KOHA_PACKAGE} .
RUN apt-get update && apt-get install -y --no-install-recommends dpkg \
    && apt-get install -y ./${KOHA_PACKAGE} \
    && apt-get -f install -y --fix-missing \
    && /etc/init.d/koha-common stop \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Add Node.js
RUN wget -O- -q https://deb.nodesource.com/setup_14.x | bash -
# Pin Node.js v14
COPY files/nodejs.pin /etc/apt/preferences.d/nodejs

# Add yarn repo
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
   && wget -O- -q https://dl.yarnpkg.com/debian/pubkey.gpg \
      | gpg --dearmor \
      | tee /usr/share/keyrings/yarnkey.gpg >/dev/null \
   && echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | tee /etc/apt/sources.list.d/yarn.list

# Install Node.js (includes npm) and Yarn
RUN apt-get update \
   && apt-get -y install nodejs yarn \
   && rm -rf /var/cache/apt/archives/* \
   && rm -rf /var/lib/api/lists/*
# Install gulp
RUN npm install gulp-cli -g

# Embed /kohadevbox/node_modules
RUN cd /kohadevbox \
    && wget -q https://gitlab.com/koha-community/Koha/-/raw/master/package.json?inline=false -O package.json \
    && wget -q https://gitlab.com/koha-community/Koha/-/raw/master/yarn.lock?inline=false -O yarn.lock \
    && yarn install --modules-folder /kohadevbox/node_modules \
    && mv /root/.cache/Cypress /kohadevbox && chown -R 1000 /kohadevbox/Cypress \
    && rm -f package.json yarn.lock

# Clone helper repositories
RUN cd /kohadevbox \
    && git clone https://gitlab.com/koha-community/koha-misc4dev.git misc4dev \
    && git clone https://gitlab.com/koha-community/koha-gitify.git gitify

# Install temporary packages
RUN apt-get update \
    && apt-get -y install \
    libmojolicious-plugin-oauth2-perl \
    libmojolicious-plugin-renderfile-perl \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/api/lists/*

# Install some quality of life improvements
RUN apt-get update \
    && apt-get -y install \
    bat \
    cmake \
    curl \
    fd-find \
    fzf \
    gettext \
    ninja-build \
    ripgrep \
    unzip \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/api/lists/* 
RUN git clone https://github.com/neovim/neovim
WORKDIR /kohadevbox/neovim
RUN git checkout stable \
    && make CMAKE_BUILD_TYPE=RelWithDebInfo
WORKDIR /kohadevbox/neovim/build
RUN cpack -G DEB \
    && dpkg -i nvim-linux64.deb 
WORKDIR /kohadevbox
RUN rm -rf neovim \
    && git clone https://github.com/LazyVim/starter ~/.config/nvim \
    && rm -rf ~/.config/nvim/.git \
    && mkdir -p /var/lib/koha/kohadev/.config \
    && cp -r ~/.config/nvim /var/lib/koha/kohadev/.config/nvim

VOLUME /kohadevbox/koha

COPY files/run.sh /kohadevbox
COPY files/templates /kohadevbox/templates
COPY env/defaults.env /kohadevbox/templates/defaults.env

EXPOSE 8080 8081
CMD ["/bin/bash", "/kohadevbox/run.sh"]
