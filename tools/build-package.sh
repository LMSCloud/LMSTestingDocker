#!/bin/bash
set -euo pipefail

# Phase A: Build koha-common .deb locally using koha-builder
# Usage: ./tools/build-package.sh --koha-version <version> --koha-branch <koha-branch>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default values
KOHA_VERSION=""
KOHA_BRANCH=""
BUILDER_IMAGE="${LMS_BUILDER_IMAGE:-ghcr.io/lmscloudpauld/koha-builder:v1.1.0}"
LMSC_SYNC_REPO="${LMSC_SYNC_REPO:-}"
OUTPUT_DIR="${PROJECT_ROOT}/out/debian"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build koha-common .deb package from local Koha-LMSCloud checkout.

Required:
  --koha-version VERSION    Version string for the package (e.g. <X.Y.Z>lmscloud
                            — the 'lmscloud' suffix is stripped from the image tag)
  --koha-branch BRANCH      Git branch in the Koha-LMSCloud checkout to build from

Optional:
  --builder-image IMAGE     Builder image to use (default: ${BUILDER_IMAGE},
                            also overridable via LMS_BUILDER_IMAGE env var)
  --output-dir DIR          Output directory for .deb (default: ${OUTPUT_DIR})
  -h, --help                Show this help

Environment:
  LMSC_SYNC_REPO            Path to Koha-LMSCloud repository (required if not set)
  LMS_BUILDER_IMAGE         Override default builder image (--builder-image takes precedence)

Example:
  ./tools/build-package.sh \\
    --koha-version <version> \\
    --koha-branch <koha-branch>
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
        --builder-image)
            BUILDER_IMAGE="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
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
if [[ -z "${KOHA_VERSION}" || -z "${KOHA_BRANCH}" ]]; then
    echo "Error: --koha-version and --koha-branch are required" >&2
    usage
    exit 1
fi

# Validate LMSC_SYNC_REPO
if [[ -z "${LMSC_SYNC_REPO}" ]]; then
    echo "Error: LMSC_SYNC_REPO environment variable must be set" >&2
    echo "Example: export LMSC_SYNC_REPO=/path/to/Koha-LMSCloud" >&2
    exit 1
fi

if [[ ! -d "${LMSC_SYNC_REPO}/.git" ]]; then
    echo "Error: LMSC_SYNC_REPO (${LMSC_SYNC_REPO}) is not a git repository" >&2
    exit 1
fi

# Ensure output directory exists, then clear any artifacts from prior runs.
# Phase B globs koha-common_*.deb; leaving older versions around risks
# silently baking the wrong .deb into the image.
mkdir -p "${OUTPUT_DIR}"
rm -f "${OUTPUT_DIR}"/*.deb \
      "${OUTPUT_DIR}"/*.changes \
      "${OUTPUT_DIR}"/*.tar.gz \
      "${OUTPUT_DIR}"/*.dsc

echo "=== Phase A: Building koha-common .deb ==="
echo "Koha version: ${KOHA_VERSION}"
echo "Koha branch: ${KOHA_BRANCH}"
echo "Builder image: ${BUILDER_IMAGE}"
echo "Source repo: ${LMSC_SYNC_REPO}"
echo "Output dir: ${OUTPUT_DIR}"
echo ""

# Pull builder image if needed
echo "Pulling builder image..."
docker pull "${BUILDER_IMAGE}"

# The script that runs inside the builder container. Written as a heredoc
# so we can keep the entire build pipeline in one file; ${PROJECT_ROOT}-side
# variables are passed as positional args, not substituted at heredoc time.
DOCKER_SCRIPT=$(cat <<'INNERSCRIPT'
#!/bin/bash
set -e
[[ "${DEBUG:-}" == "1" ]] && set -x

KOHA_VERSION="$1"
KOHA_BRANCH="$2"

echo "=========================================="
echo "Building version: ${KOHA_VERSION}"
echo "From branch: ${KOHA_BRANCH}"
echo "=========================================="

# Use /tmp for writable workspace (works with any user)
BUILD_DIR=$(mktemp -d)
echo "[1/6] Created build directory: ${BUILD_DIR}"

# Copy repo to writable location in expected structure
echo "[2/6] Copying repository to build directory..."
mkdir -p ${BUILD_DIR}/workspace
cp -r /workspace/. ${BUILD_DIR}/workspace/
cd ${BUILD_DIR}/workspace
echo "    Copied $(du -sh . | cut -f1)"

# Remove untracked + ignored artifacts (e.g. stale yarn-built dist files in
# koha-tmpl/{opac,intranet}-tmpl/.../js/vue/dist). Those get picked up by
# Makefile.PL's $file_map under OPAC_TMPL_DIR; pm_to_blib then locks them
# to mode 0444 in blib/, and the later move_compiled_js cp recipe fails
# with "Permission denied" trying to overwrite. Build from a clean tree.
echo "    Cleaning untracked/ignored files in workspace copy..."
git clean -fdx -q

# Create the /tmp/koha-common symlink that build-koha.sh expects
echo "    Creating expected directory structure..."
ln -s ${BUILD_DIR}/workspace /tmp/koha-common

# Checkout branch FIRST. If the host repo is on a different branch than
# the requested one, doing this after `patch` would let `git checkout`
# overwrite the patched files.
echo "[3/6] Checking out branch ${KOHA_BRANCH}..."
git checkout "${KOHA_BRANCH}" 2>&1 || (git fetch origin "${KOHA_BRANCH}" 2>&1 && git checkout "${KOHA_BRANCH}" 2>&1)
echo "    Now on branch: $(git branch --show-current)"

# Apply the Koha-source patch: forces binary-only dpkg-buildpackage. A
# real patch file (not sed) so upstream drift fails loudly.
echo "    Applying Koha-source patch..."
patch -p1 --no-backup-if-mismatch < /patches/phase-a-koha-source.patch

# Run build
echo "[4/6] Starting package build (this may take several minutes)..."
export KOHA_VERSION="${KOHA_VERSION}"
if [[ -f .github/scripts/build-koha.sh ]]; then
    bash .github/scripts/build-koha.sh 2>&1
else
    echo "Error: .github/scripts/build-koha.sh not found"
    exit 1
fi

# build-koha.sh places artifacts in /tmp/debian.
echo "[5/6] Build complete. Copying outputs from /tmp/debian to /output/..."
if [[ ! -d /tmp/debian ]]; then
    echo "Error: /tmp/debian not found — build-koha.sh did not produce artifacts"
    exit 1
fi
ls -la /tmp/debian/

shopt -s nullglob
artifacts=(/tmp/debian/*.deb /tmp/debian/*.changes /tmp/debian/*.tar.gz /tmp/debian/*.dsc)
shopt -u nullglob
if [[ ${#artifacts[@]} -eq 0 ]]; then
    echo "Error: no build artifacts found in /tmp/debian"
    exit 1
fi
cp "${artifacts[@]}" /output/
echo "    Copied ${#artifacts[@]} artifact(s)"

echo "[6/6] Final output contents:"
ls -la /output/
echo "=========================================="
echo "Build complete"
echo "=========================================="
INNERSCRIPT
)

# Write the script to a file inside the project tree and mount it into the
# container. Piping via stdin (bash -s) is unsafe: child processes like
# dpkg-buildpackage/apt-get can consume remaining script lines from stdin,
# silently truncating execution after build-koha.sh returns. We avoid
# $TMPDIR because on macOS it resolves under /var/folders/... which Docker
# Desktop does not share by default — a bind-mount with a missing source
# silently becomes a directory on the target.
SCRIPT_FILE="${PROJECT_ROOT}/.build-container-script.sh"
trap 'rm -f "${SCRIPT_FILE}"' EXIT
printf '%s\n' "${DOCKER_SCRIPT}" > "${SCRIPT_FILE}"

echo "Starting build container (output may take a moment to appear)..."
docker run --rm \
    -e "PYTHONUNBUFFERED=1" \
    -e "DEBIAN_FRONTEND=noninteractive" \
    -e "DEBUG=${DEBUG:-}" \
    -v "${SCRIPT_FILE}:/run-build.sh:ro" \
    -v "${SCRIPT_DIR}/patches:/patches:ro" \
    -v "${LMSC_SYNC_REPO}:/workspace:ro" \
    -v "${OUTPUT_DIR}:/output" \
    "${BUILDER_IMAGE}" \
    bash /run-build.sh "${KOHA_VERSION}" "${KOHA_BRANCH}" 2>&1

echo ""
echo "=== Phase A Complete ==="
echo "Built packages in: ${OUTPUT_DIR}"
ls -la "${OUTPUT_DIR}/"
