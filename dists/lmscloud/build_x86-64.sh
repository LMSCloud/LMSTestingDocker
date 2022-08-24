#!/bin/bash

cd "${KOHA_TESTING_DOCKER_HOME}" || exit 1

echo 'Building image for x86_64'

cp -r files dists/lmscloud/ \
    && cp -r env dists/lmscloud/

docker build --build-arg arch=x86_64 -t lmscloud-koha-x86_64 dists/lmscloud/ \
    && echo 'Build finished.' \
    && docker tag lmscloud-koha-x86_64:latest jpahd/lmscloud-koha-x86_64:latest \
    && echo 'Linking done.' \
    && docker push jpahd/lmscloud-koha-x86_64:latest \
    && echo 'Image published. 👋 Ciao'

