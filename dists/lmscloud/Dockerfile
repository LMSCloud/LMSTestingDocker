ARG arch

# Base it on Debian 11
FROM debian:bullseye AS base

# File Author / Maintainer
# Author if this file is Tomás Cohen Arazi, modified by Paul Derscheid
LABEL maintainer="paul.derscheid@lmscloud.de"

ENV PATH /usr/bin:/bin:/usr/sbin:/sbin
ENV DEBIAN_FRONTEND noninteractive

# Set suitable debian sources
# RUN echo "deb http://httpredir.debian.org/debian bullseye main" > /etc/apt/sources.list

ENV REFRESHED_AT 2022-08-24

#RUN apt-get -y update

# Install apache2 and testting deps
# netcat: used for checking the DB is up
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      apache2 \
      build-essential \
      codespell \
      cpanminus \
      git \
      gnupg \
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
      iproute2 && \
      rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Set locales
RUN    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "de_DE.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && dpkg-reconfigure locales \
    && /usr/sbin/update-locale LANG=en_US.UTF-8

ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8

# Prepare apache configuration
RUN a2dismod mpm_event && \
    a2dissite 000-default && \
    a2enmod rewrite \
            headers \
            proxy_http \
            cgi

# Add Koha development repositories
RUN echo "deb [signed-by=/usr/share/keyrings/koha-keyring.gpg] http://debian.koha-community.org/koha-staging dev main" >> /etc/apt/sources.list.d/koha.list && \
    echo "deb [signed-by=/usr/share/keyrings/koha-deps-keyring.gpg] http://deb3.kohaaloha.com/ka/koha-deps stable main bullseye" >> /etc/apt/sources.list.d/koha.list && \
    wget -qO - http://debian.koha-community.org/koha/gpg.asc | gpg --dearmor -o /usr/share/keyrings/koha-keyring.gpg && \
    wget -qO - http://deb3.kohaaloha.com/ka/koha-deps/gpg.asc | gpg --dearmor -o /usr/share/keyrings/koha-deps-keyring.gpg && \
    apt-get update && \
    apt-cache policy koha-common && \
    apt-cache policy libmojolicious-perl && \
    apt-cache policy libjson-validator-perl && \
    apt-cache policy libmojolicious-plugin-openapi-perl && \
    apt-cache policy libyaml-libyaml-perl && \
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

FROM base AS branch-aarch64
# COPY arm_dependencies /kohadevbox/arm_dependencies

# RUN for f in /kohadevbox/arm_dependencies/*.deb; do gdebi -n "$f"; done && \
#     rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# WORKDIR /kohadevbox/arm_dependencies/libhttpd-bench-apachebench-perl
# RUN tar xf libhttpd-bench-apachebench-perl_0.73.orig.tar.gz

# WORKDIR /kohadevbox/arm_dependencies/libhttpd-bench-apachebench-perl/ApacheBench-0.73
# RUN perl Makefile.PL \
#     && make \
#     && make install

WORKDIR /kohadevbox

FROM base AS branch-x86_64
FROM branch-${arch} AS final

# We need to add our lmscloud package instead of fetching from the community repo
COPY koha-common_21.05.14lmscloud-1_all.deb /kohadevbox/

# Install koha-common
RUN apt-get update && apt-get install -y --no-install-recommends dpkg \
    && apt install -y ./koha-common_21.05.14lmscloud-1_all.deb \
    && apt-get -f install -y --fix-missing \
    && /etc/init.d/koha-common stop \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Install testing extras, packages and cpan
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libexpat1-dev \
    libtemplate-plugin-gettext-perl \
    libdevel-cover-perl \
    libmoosex-attribute-env-perl \
    libtap-harness-junit-perl \
    libtext-csv-unicode-perl \
    libdevel-cover-report-clover-perl \
    libwebservice-ils-perl \
    libselenium-remote-driver-perl \
    libauth-googleauth-perl \
    libemail-address-perl && \
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

## Add Yarn
# Add node repo
RUN wget -q -O- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
    echo "deb http://deb.nodesource.com/node_12.x sid main" > /etc/apt/sources.list.d/node.list && \
    wget -q -O- https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs yarn && \
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Install gulp
RUN npm install gulp-cli -g

# Add git-bz
RUN cd /usr/local/share \
    && git clone --depth 1 --branch apply_on_cascade https://gitlab.com/koha-community/git-bz git-bz \
    && ln -s /usr/local/share/git-bz/git-bz /usr/bin/git-bz

# Clone helper repositories
RUN cd /kohadevbox \
    && git clone https://gitlab.com/koha-community/koha-misc4dev.git misc4dev \
    && git clone https://gitlab.com/koha-community/koha-gitify.git gitify \
    && git clone https://gitlab.com/koha-community/qa-test-tools.git

# release-tools and koha-howto
RUN cd /kohadevbox && \
    git clone https://gitlab.com/koha-community/release-tools.git && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libhtml-tableextract-perl \
        libtext-multimarkdown-perl \
        bugz \
        librest-client-perl && \
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*

# Remote debugger
RUN cd /kohadevbox \
    && wget -q -O dbgp.tar.gz https://gitlab.com/mjames/dbgp/-/raw/master/dbgp.tar.gz \
    && tar xvzf dbgp.tar.gz \
    && rm dbgp.tar.gz

VOLUME /kohadevbox/koha

COPY files/run.sh /kohadevbox
COPY files/templates /kohadevbox/templates
COPY env/defaults.env /kohadevbox/templates/defaults.env

CMD ["/bin/bash", "/kohadevbox/run.sh"]

EXPOSE 8080 8081
