#!/bin/bash
set -euo pipefail

# Orchestrator: Build koha-common .deb then build KTD image with it
# Usage: ./tools/build-image.sh --koha-version <version> --koha-branch <koha-branch> --ktd-branch 25.11 --platforms linux/arm64

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
KOHA_VERSION=""
KOHA_BRANCH=""
KTD_BRANCH=""
PLATFORMS="linux/amd64,linux/arm64"
PUSH=""
SKIP_PHASE_A=""

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build LMSCloud Koha Docker image in two phases:
  Phase A: Build koha-common .deb from local Koha-LMSCloud checkout
  Phase B: Build KTD Docker image with the locally-built .deb

Required:
  --koha-version VERSION    Version string (e.g. <X.Y.Z>lmscloud — the
                            'lmscloud' suffix is stripped from the image tag)
  --koha-branch BRANCH      Git branch in the Koha-LMSCloud checkout to build from
  --ktd-branch BRANCH       KTD branch to base image on (e.g., 25.11, 26.05)

Optional:
  --platforms PLATFORMS     Comma-separated platforms (default: ${PLATFORMS})
  --push                    Push image after build
  --skip-phase-a            Skip .deb build (use existing in out/debian/)
  -h, --help                Show this help

Environment:
  LMSC_SYNC_REPO            Path to Koha-LMSCloud repository (required)

Examples:
  # Build and load locally (single arch):
  ./tools/build-image.sh \\
    --koha-version <version> \\
    --koha-branch <koha-branch> \\
    --ktd-branch 25.11 \\
    --platforms linux/arm64

  # Build and push multi-arch:
  ./tools/build-image.sh \\
    --koha-version <version> \\
    --koha-branch <koha-branch> \\
    --ktd-branch 25.11 \\
    --platforms linux/amd64,linux/arm64 \\
    --push

  # Rebuild image using existing .deb:
  ./tools/build-image.sh \\
    --koha-version <version> \\
    --koha-branch <koha-branch> \\
    --ktd-branch 25.11 \\
    --skip-phase-a

Workflow:
  1. Ensure LMSC_SYNC_REPO points to your Koha-LMSCloud checkout
  2. Ensure Koha-LMSCloud has .github/scripts/build-koha.sh
  3. Run this script
  4. Use output image with docker-compose-lmscloud.yml

Post-build usage:
  KOHA_IMAGE=<registry>/lmscloud-koha-aarch64:<version> \\
    docker compose -f docker-compose-lmscloud.yml up
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --koha-version)
            KOHA_VERSION="$2"
            shift 2
            ;;
        --koha-branch)
            KOHA_BRANCH="$2"
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
        --push)
            PUSH="--push"
            shift
            ;;
        --skip-phase-a)
            SKIP_PHASE_A="yes"
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
if [[ -z "${KOHA_VERSION}" || -z "${KOHA_BRANCH}" || -z "${KTD_BRANCH}" ]]; then
    echo "Error: --koha-version, --koha-branch, and --ktd-branch are required" >&2
    usage
    exit 1
fi

# Validate environment
if [[ -z "${LMSC_SYNC_REPO:-}" ]]; then
    echo "Error: LMSC_SYNC_REPO environment variable must be set" >&2
    echo "Example: export LMSC_SYNC_REPO=/path/to/Koha-LMSCloud" >&2
    exit 1
fi

echo "=========================================="
echo "LMSCloud Koha Image Build"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Koha version:  ${KOHA_VERSION}"
echo "  Koha branch:   ${KOHA_BRANCH}"
echo "  KTD branch:    ${KTD_BRANCH}"
echo "  Platforms:     ${PLATFORMS}"
echo "  Push:          ${PUSH:-no}"
echo "  Skip Phase A:  ${SKIP_PHASE_A:-no}"
echo "  Source repo:   ${LMSC_SYNC_REPO}"
echo ""

# Phase A: Build .deb
if [[ -z "${SKIP_PHASE_A}" ]]; then
    echo "=== Running Phase A: Build Package ==="
    "${SCRIPT_DIR}/build-package.sh" \
        --koha-version "${KOHA_VERSION}" \
        --koha-branch "${KOHA_BRANCH}"
    echo ""
else
    echo "=== Skipping Phase A (using existing .deb) ==="
    if ! ls "${SCRIPT_DIR}/../out/debian"/koha-common_*.deb 1>/dev/null 2>&1; then
        echo "Error: No .deb file found in out/debian/" >&2
        echo "Run without --skip-phase-a first, or ensure a .deb exists" >&2
        exit 1
    fi
    echo "Using existing package:"
    ls -la "${SCRIPT_DIR}/../out/debian"/koha-common_*.deb
    echo ""
fi

# Phase B: Build Docker image
echo "=== Running Phase B: Build KTD Image ==="
"${SCRIPT_DIR}/build-ktd-image.sh" \
    --koha-version "${KOHA_VERSION}" \
    --ktd-branch "${KTD_BRANCH}" \
    --platforms "${PLATFORMS}" \
    ${PUSH}

echo ""
echo "=========================================="
echo "Build Complete"
echo "=========================================="
echo "See the Phase B output above for the image name and usage hint."
