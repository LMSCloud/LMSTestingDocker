#!/bin/bash

cd "${KTD_HOME}" || exit 1

usage() {
  echo "Usage: $0 [-p <docker|ghcr>] [-t <tag>]" 1>&2
  exit 1
}

while getopts ":p:t:" opt; do
  case ${opt} in
    p )
      if [[ "${OPTARG}" != "docker" && "${OPTARG}" != "ghcr" ]]; then
        echo "Invalid option: -p ${OPTARG}" 1>&2
        usage
      fi
      PUSH_REGISTRY=${OPTARG}
      ;;
    t )
      TAG=${OPTARG}
      ;;
    \? )
      echo "Invalid option: -$OPTARG" 1>&2
      usage
      ;;
    : )
      echo "Invalid option: -$OPTARG requires an argument" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND -1))

if [[ -z "${PUSH_REGISTRY}" || -z "${TAG}" ]]; then
  usage
fi

echo "Building image for aarch64 with tag: ${TAG} and pushing to ${PUSH_REGISTRY}"

cp -r files dists/lmscloud/ \
    && cp -r env dists/lmscloud/

docker build --build-arg arch=aarch64 -t lmscloud-koha-aarch64 dists/lmscloud/ \
    && echo 'Build finished.' \
    && docker tag lmscloud-koha-aarch64:latest "${PUSH_REGISTRY}/jpahd/lmscloud-koha-aarch64:${TAG}" \
    && echo 'Linking done.' \
    && docker push "${PUSH_REGISTRY}/jpahd/lmscloud-koha-aarch64:${TAG}" \
    && echo 'Image published. 👋 Ciao'

