#!/bin/sh

mkdir -p arm_dependencies && mkdir arm_dependencies/libhttpd-bench-apachebench-perl

DEPENDENCIES=(
    http://deb3.kohaaloha.com/koha-staging/pool/main/libh/libhttp-oai-3.27-perl/libhttp-oai-3.27-perl_3.27-1~koha+1_all.deb
    http://deb3.kohaaloha.com/ka/koha-deps/pool/main/libm/libmoosex-attribute-env-perl/libmoosex-attribute-env-perl_0.02-1_all.deb
    http://deb3.kohaaloha.com/ka/koha-deps/pool/main/libt/libtest-dbix-class-perl/libtest-dbix-class-perl_0.52-1_all.deb
    http://deb3.kohaaloha.com/ka/koha-deps/pool/main/libt/libtext-csv-unicode-perl/libtext-csv-unicode-perl_0.400-1_all.deb
    http://deb3.kohaaloha.com/ka/koha-deps/pool/main/libd/libdevel-cover-report-clover-perl/libdevel-cover-report-clover-perl_1.01-1_all.deb
    http://deb3.kohaaloha.com/ka/koha-deps/pool/main/libs/libselenium-remote-driver-perl/libselenium-remote-driver-perl_1.46-1_all.deb
    https://debian.koha.cz/pool/main/libc/libcache-memcached-fast-safe-perl/libcache-memcached-fast-safe-perl_0.06-1~koha1_all.deb
    http://debian.koha-community.org/koha/pool/main/libp/libpdf-fromhtml-perl/libpdf-fromhtml-perl_0.31-1~koha1_all.deb
    http://debian.koha-community.org/koha/pool/main/libs/libswagger2-perl/libswagger2-perl_0.77-1~koha1_all.deb
    http://debian.koha-community.org/koha/pool/main/libl/liblocale-xgettext-perl/liblocale-xgettext-perl_0.7-1~koha1_all.deb
    http://debian.koha-community.org/koha/pool/main/libt/libtemplate-plugin-gettext-perl/libtemplate-plugin-gettext-perl_0.6-1~koha1_all.deb
    http://debian.koha-community.org/koha/pool/main/libt/libtemplate-plugin-htmltotext-perl/libtemplate-plugin-htmltotext-perl_0.03-1koha1_all.deb
)

for i in "${DEPENDENCIES[@]}"; do
    wget $i -P arm_dependencies/
done

wget http://deb3.kohaaloha.com/ka/koha-deps/pool/bullseye/libh/libhttpd-bench-apachebench-perl/libhttpd-bench-apachebench-perl_0.73.orig.tar.gz -P arm_dependencies/libhttpd-bench-apachebench-perl