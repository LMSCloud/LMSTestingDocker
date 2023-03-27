#!/bin/bash

cd "${KOHA_TESTING_DOCKER_HOME}" || exit 1

usage() {
  echo "Usage: $0 [-p <docker|ghcr>] [-n <namespace>] [-t <tag>] [-h|--help]" 1>&2
  exit 1
}

while getopts ":p:t:h-" opt; do
  case ${opt} in
    p )
      if [[ "${OPTARG}" != "docker" && "${OPTARG}" != "ghcr" ]]; then
        echo "Invalid option: -p ${OPTARG}" 1>&2
        usage
      fi

      PUSH_REGISTRY=${OPTARG}

      if [[ "${OPTARG}" == "ghcr" ]]; then
        PUSH_REGISTRY="${OPTARG}.io"
      fi
      ;;
    n )
      NAMESPACE=${OPTARG}
      ;;
    t )
      TAG=${OPTARG}
      ;;
    h | --help )
      usage
      ;;
    - )
      if [[ "${OPTARG}" == "help" || "${OPTARG}" == "" ]]; then
        usage
      fi
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

if [[ -z "${PUSH_REGISTRY}" ||  -z "${NAMESPACE}" || -z "${TAG}" ]]; then
  usage
fi

echo "Building image for aarch64 with tag: ${TAG} under namespace: ${NAMESPACE} and pushing to ${PUSH_REGISTRY}"

cp -r files dists/lmscloud/ \
    && cp -r env dists/lmscloud/

docker build --build-arg arch=aarch64 -t lmscloud-koha-aarch64 dists/lmscloud/ \
    && echo 'Build finished.' \
    && docker tag lmscloud-koha-aarch64:latest "${PUSH_REGISTRY}/${NAMESPACE}/lmscloud-koha-aarch64:${TAG}" \
    && echo 'Linking done.' \
    && docker push "${PUSH_REGISTRY}/${NAMESPACE}/lmscloud-koha-aarch64:${TAG}" \
    && echo 'Image published. 👋 Ciao'

