#!/bin/bash

wget -q --output-document=current-koha-package.conf https://orgaknecht.lmscloud.net/lms-cloud-packages/packages/current-koha-package.conf || exit 1
KOHAPACKAGE=$(head -n1 current-koha-package.conf | awk '{print $1;}') || exit 1
rm -f current-koha-package.conf || exit 1
wget -q --output-document="$KOHAPACKAGE" https://orgaknecht.lmscloud.net/lms-cloud-packages/packages/"$KOHAPACKAGE" || exit 1
