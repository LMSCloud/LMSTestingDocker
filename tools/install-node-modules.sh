#!/bin/bash
set -euo pipefail

# Install a checkout's node_modules with a Linux Node container, so the native
# bindings match the (linux) koha container instead of the host.
#
# Why this exists: mounting a macOS-installed node_modules into the linux koha
# container breaks the boot-time asset build (webpack && rspack) with errors
# like:
#   Cannot find module '@rspack/binding-linux-arm64-gnu'   (wrong platform)
#   /bin/sh: 1: rspack: not found                          (partial install)
# The image's own Node is too old to `yarn install` newer build tooling, so we
# do the install in a matching Linux Node container up front.
#
# Node 18 is the default sweet spot: rspack needs Node >= 16, while some
# transitive deps (e.g. @achrinza/node-ipc) cap the engine at Node 18. The
# resulting N-API bindings stay loadable under the koha container's older Node.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
REPO="${LMSC_SYNC_REPO:-}"
NODE_VERSION="18"
NODE_IMAGE=""

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install node_modules for a Koha checkout inside a Linux Node container, so the
native bindings match the koha container's platform (fixes rspack/webpack build
failures when the host is macOS).

Optional:
  --repo PATH             Koha checkout to install into
                          (default: \$LMSC_SYNC_REPO)
  --node-version VERSION  Node major version for the install image
                          (default: ${NODE_VERSION})
  --image IMAGE           Full Node image to use, overrides --node-version
                          (default: node:${NODE_VERSION}-bullseye)
  -h, --help              Show this help

Environment:
  LMSC_SYNC_REPO          Default checkout path when --repo is omitted

Examples:
  # Install into the checkout pointed at by \$LMSC_SYNC_REPO:
  ./tools/install-node-modules.sh

  # Install into an explicit worktree:
  ./tools/install-node-modules.sh \\
    --repo /path/to/koha-lmscloud-worktree

  # Pin a different Node version:
  ./tools/install-node-modules.sh --node-version 20
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            REPO="$2"
            shift 2 ;;
        --node-version)
            NODE_VERSION="$2"
            shift 2 ;;
        --image)
            NODE_IMAGE="$2"
            shift 2 ;;
        -h|--help)
            usage
            exit 0 ;;
        *)
            echo "Error: unknown argument '$1'" >&2
            echo >&2
            usage >&2
            exit 1 ;;
    esac
done

if [[ -z "${REPO}" ]]; then
    echo "Error: no checkout given (pass --repo or set LMSC_SYNC_REPO)" >&2
    exit 1
fi
if [[ ! -f "${REPO}/package.json" ]]; then
    echo "Error: ${REPO} has no package.json — is it a Koha checkout?" >&2
    exit 1
fi

NODE_IMAGE="${NODE_IMAGE:-node:${NODE_VERSION}-bullseye}"

echo "Installing node_modules in ${REPO}"
echo "  using image: ${NODE_IMAGE}"

# corepack enable picks up the checkout's packageManager / bundled yarn.
docker run --rm \
    -v "${REPO}:/koha" \
    -w /koha \
    "${NODE_IMAGE}" \
    bash -c 'corepack enable && yarn install'

echo "Done. node_modules now carries Linux native bindings."
