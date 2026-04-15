#!/bin/bash
set -euo pipefail

# Phase B: Build KTD image with local .deb injected
# Usage: ./tools/build-ktd-image.sh --koha-version <version> --ktd-branch 25.11 --platforms linux/arm64

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default values
KOHA_VERSION=""
KTD_BRANCH=""
PLATFORMS="linux/amd64,linux/arm64"
DEB_DIR="${PROJECT_ROOT}/out/debian"
REGISTRY="${LMS_REGISTRY:-ghcr.io/lmscloudpauld}"
PUSH=""

# Map KTD branch to Debian dist
get_dist_for_branch() {
    local branch="$1"
    case "${branch}" in
        25.05|25.11)
            echo "bookworm"
            ;;
        26.05|26.11|master|main)
            echo "trixie"
            ;;
        24.05|24.11)
            echo "bullseye"
            ;;
        *)
            # Default to bookworm for unknown branches
            echo "bookworm"
            ;;
    esac
}

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build KTD Docker image with locally-built koha-common .deb.

Required:
  --koha-version VERSION    Version string (e.g. <X.Y.Z>lmscloud — the
                            'lmscloud' suffix is stripped from the image tag)
  --ktd-branch BRANCH       KTD branch to base image on (e.g., 25.11, 26.05)

Optional:
  --platforms PLATFORMS     Comma-separated platforms (default: ${PLATFORMS})
  --deb-dir DIR             Directory containing .deb file (default: ${DEB_DIR})
  --registry REGISTRY       Image registry prefix (default: ${REGISTRY},
                            also overridable via LMS_REGISTRY env var)
  --push                    Push image after build
  -h, --help                Show this help

Example:
  ./tools/build-ktd-image.sh \\
    --koha-version <version> \\
    --ktd-branch 25.11 \\
    --platforms linux/arm64

  # Build and push multi-arch:
  ./tools/build-ktd-image.sh \\
    --koha-version <version> \\
    --ktd-branch 25.11 \\
    --platforms linux/amd64,linux/arm64 \\
    --push
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --koha-version)
            KOHA_VERSION="$2"
            shift 2
            ;;
        --ktd-branch)
            KTD_BRANCH="$2"
            shift 2
            ;;
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --deb-dir)
            DEB_DIR="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --push)
            PUSH="--push"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Validate required args
if [[ -z "${KOHA_VERSION}" || -z "${KTD_BRANCH}" ]]; then
    echo "Error: --koha-version and --ktd-branch are required" >&2
    usage
    exit 1
fi

# Determine target architecture and image tag
dist=$(get_dist_for_branch "${KTD_BRANCH}")

# Strip the "lmscloud" suffix from the version for the tag — the .deb keeps
# it as its Debian identity, but the image namespace already encodes it.
image_version="${KOHA_VERSION%lmscloud}"

# Image naming convention:
#   multi-arch:  lmscloud-koha:<version>              (no suffix)
#   arm64:       lmscloud-koha-aarch64:<version>
#   amd64:       lmscloud-koha-x86_64:<version>
if [[ "${PLATFORMS}" == *","* ]]; then
    IMAGE_NAME="${REGISTRY}/lmscloud-koha:${image_version}"
else
    case "${PLATFORMS#*/}" in
        arm64) arch_suffix="aarch64" ;;
        amd64) arch_suffix="x86_64" ;;
        *)     arch_suffix="${PLATFORMS#*/}" ;;
    esac
    IMAGE_NAME="${REGISTRY}/lmscloud-koha-${arch_suffix}:${image_version}"
fi

echo "=== Phase B: Building KTD Image ==="
echo "Koha version: ${KOHA_VERSION}"
echo "KTD branch: ${KTD_BRANCH}"
echo "Debian dist: ${dist}"
echo "Platforms: ${PLATFORMS}"
echo "Image: ${IMAGE_NAME}"
echo "Deb dir: ${DEB_DIR}"
echo ""

# Verify .deb exists
deb_files=("${DEB_DIR}"/koha-common_*.deb)
if [[ ! -f "${deb_files[0]}" ]]; then
    echo "Error: No .deb file found in ${DEB_DIR}" >&2
    echo "Run build-package.sh first to build the .deb package" >&2
    exit 1
fi

# Get the exact .deb filename
KOHA_PACKAGE=$(basename "${deb_files[0]}")

# Assert the .deb's version matches the requested KOHA_VERSION. Without
# this, --skip-phase-a happily reuses a stale .deb from a previous build
# and silently bakes the wrong package into the image.
if [[ "${KOHA_PACKAGE}" != koha-common_${KOHA_VERSION}-*.deb ]]; then
    echo "Error: .deb version mismatch in ${DEB_DIR}" >&2
    echo "  Found:    ${KOHA_PACKAGE}" >&2
    echo "  Expected: koha-common_${KOHA_VERSION}-*.deb" >&2
    echo "Run build-package.sh with --koha-version ${KOHA_VERSION} to refresh." >&2
    exit 1
fi
echo "Using package: ${KOHA_PACKAGE}"

# Use a persistent cache of the upstream KTD clone per branch under
# .cache/ktd/<branch> in the project root. On first run, clone fresh.
# On subsequent runs, fetch + reset to upstream HEAD. If the network
# fails and a cache exists, fall back to the cached copy (with a
# warning) so an upstream outage doesn't block local builds.
KTD_CACHE_DIR="${PROJECT_ROOT}/.cache/ktd"
KTD_CACHE="${KTD_CACHE_DIR}/${KTD_BRANCH}"
mkdir -p "${KTD_CACHE_DIR}"

BUILD_CONTEXT=""
cleanup() { rm -rf "${BUILD_CONTEXT:-}"; }
trap cleanup EXIT

KTD_REMOTES=(
    https://git.koha-community.org/koha-community/koha-testing-docker.git
    https://gitlab.com/koha-community/koha-testing-docker.git
)

if [[ -d "${KTD_CACHE}/.git" ]]; then
    echo "Refreshing KTD cache at ${KTD_CACHE}..."
    fetched=""
    for remote in "${KTD_REMOTES[@]}"; do
        if git -C "${KTD_CACHE}" fetch --depth 1 "${remote}" "${KTD_BRANCH}" 2>/dev/null; then
            git -C "${KTD_CACHE}" reset --hard FETCH_HEAD
            fetched="yes"
            break
        fi
    done
    if [[ -z "${fetched}" ]]; then
        echo "Warning: could not fetch from any KTD remote, using stale cache" >&2
    fi
else
    echo "Cloning KTD ${KTD_BRANCH} into ${KTD_CACHE}..."
    cloned=""
    for remote in "${KTD_REMOTES[@]}"; do
        if git clone --depth 1 --branch "${KTD_BRANCH}" "${remote}" "${KTD_CACHE}" 2>/dev/null; then
            cloned="yes"
            break
        fi
    done
    if [[ -z "${cloned}" ]]; then
        echo "Error: could not clone KTD from any remote" >&2
        exit 1
    fi
fi

KTD_TMP="${KTD_CACHE}"

# Get the upstream Dockerfile for the dist
UPSTREAM_DOCKERFILE="${KTD_TMP}/dists/${dist}/Dockerfile"
if [[ ! -f "${UPSTREAM_DOCKERFILE}" ]]; then
    echo "Error: Upstream Dockerfile not found: ${UPSTREAM_DOCKERFILE}" >&2
    echo "Available dists:"
    ls -la "${KTD_TMP}/dists/" || true
    exit 1
fi

echo "Found upstream Dockerfile: ${UPSTREAM_DOCKERFILE}"

# Create build context
BUILD_CONTEXT=$(mktemp -d)
echo "Creating build context: ${BUILD_CONTEXT}"

# Copy upstream files
cp "${UPSTREAM_DOCKERFILE}" "${BUILD_CONTEXT}/Dockerfile"

# Copy supporting files from upstream. Layout varies by branch:
# older KTD had files/ and env/ under dists/<dist>/; 25.11+ has them at
# the repo root. Prefer the dist-specific copy, fall back to repo root.
for f in files env; do
    for src in "${KTD_TMP}/dists/${dist}/${f}" "${KTD_TMP}/${f}"; do
        if [[ -e "${src}" ]]; then
            cp -r "${src}" "${BUILD_CONTEXT}/"
            echo "Copied: ${src#${KTD_TMP}/} -> ${f}"
            break
        fi
    done
    if [[ ! -e "${BUILD_CONTEXT}/${f}" ]]; then
        echo "Error: upstream KTD is missing '${f}' for ${KTD_BRANCH}/${dist}" >&2
        exit 1
    fi
done

# Overlay LMSCloud-specific files on top of upstream. The upstream Dockerfile
# does `COPY files/run.sh /kohadevbox`, so replacing files/run.sh in the
# build context means our patched version gets baked into the image — no
# runtime volume-mount needed.
OVERLAY_DIR="${PROJECT_ROOT}/dists/lmscloud/files"
if [[ -d "${OVERLAY_DIR}" ]]; then
    for f in "${OVERLAY_DIR}"/*; do
        name=$(basename "${f}")
        rm -rf "${BUILD_CONTEXT}/files/${name}"
        cp -r "${f}" "${BUILD_CONTEXT}/files/${name}"
        echo "Overlayed: ${name}"
    done
fi

# Copy the .deb into the build context under a fixed name. The Dockerfile
# patch uses `RUN --mount=type=bind,source=koha-common.deb` which doesn't
# accept globs; a stable filename keeps the patch generic across versions.
cp "${DEB_DIR}/${KOHA_PACKAGE}" "${BUILD_CONTEXT}/koha-common.deb"
echo "Copied ${KOHA_PACKAGE} -> build context as koha-common.deb"

# Apply the Dockerfile patch for this (branch, dist) combination. Using a
# real patch file — not sed — so upstream drift fails loudly instead of
# silently producing a broken image.
PATCH_FILE="${SCRIPT_DIR}/patches/${KTD_BRANCH}-${dist}.patch"
if [[ ! -f "${PATCH_FILE}" ]]; then
    echo "Error: no Dockerfile patch for ${KTD_BRANCH}/${dist}: ${PATCH_FILE}" >&2
    exit 1
fi
echo "Applying patch: ${PATCH_FILE}"
( cd "${BUILD_CONTEXT}" && patch -p1 --no-backup-if-mismatch < "${PATCH_FILE}" )

# Determine platform args for docker build
if [[ -n "${PUSH}" ]]; then
    echo ""
    echo "Building and pushing multi-platform image..."
    docker buildx build \
        --platform "${PLATFORMS}" \
        --tag "${IMAGE_NAME}" \
        ${PUSH} \
        "${BUILD_CONTEXT}"
else
    # Single platform local build
    first_platform="${PLATFORMS%%,*}"
    echo ""
    echo "Building for platform: ${first_platform}"
    docker buildx build \
        --platform "${first_platform}" \
        --tag "${IMAGE_NAME}" \
        --load \
        "${BUILD_CONTEXT}"
fi

echo ""
echo "=== Phase B Complete ==="
echo "Image: ${IMAGE_NAME}"
if [[ -z "${PUSH}" ]]; then
    echo ""
    echo "To use with docker-compose:"
    echo "  KOHA_IMAGE=${IMAGE_NAME} docker compose -f docker-compose-lmscloud.yml up"
fi
