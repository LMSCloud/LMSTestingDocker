#!/bin/sh

cd ${KOHA_TESTING_DOCKER_HOME}

echo 'Building image for aarch64'

cp -r files dists/lmscloud/ \
    && cp -r env dists/lmscloud/

docker build --build-arg arch=aarch64 -t lmscloud-koha-aarch64 dists/lmscloud/ \
    && echo 'Build finished.' \
    && docker tag lmscloud-koha-aarch64:latest jpahd/lmscloud-koha-aarch64:latest \
    && echo 'Linking done.' \
    && docker push jpahd/lmscloud-koha-aarch64:latest \
    && echo 'Image published. 👋 Ciao'

