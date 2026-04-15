#!/bin/bash
set -euo pipefail

# Symlink LMSCloud files into the koha-testing-docker checkout so ktd
# picks them up when invoked with `ktd -f docker-compose-lmscloud.yml …`.
# Re-run whenever you add new overlay files here.
#
# Requires: KTD_HOME pointing to the ktd git checkout.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -z "${KTD_HOME:-}" ]]; then
    echo "Error: KTD_HOME must be set to your koha-testing-docker checkout" >&2
    exit 1
fi
if [[ ! -d "${KTD_HOME}" ]]; then
    echo "Error: KTD_HOME does not exist: ${KTD_HOME}" >&2
    exit 1
fi

# Files to symlink (source path is relative to PROJECT_ROOT, target is
# the same path relative to KTD_HOME).
LINKS=(
    docker-compose-lmscloud.yml
)

for rel in "${LINKS[@]}"; do
    src="${PROJECT_ROOT}/${rel}"
    dst="${KTD_HOME}/${rel}"
    if [[ ! -e "${src}" ]]; then
        echo "skip ${rel}: source missing in ${PROJECT_ROOT}"
        continue
    fi
    mkdir -p "$(dirname "${dst}")"
    if [[ -L "${dst}" && "$(readlink "${dst}")" == "${src}" ]]; then
        echo "ok   ${rel} -> already linked"
        continue
    fi
    if [[ -e "${dst}" && ! -L "${dst}" ]]; then
        echo "move ${dst} -> ${dst}.backup (was a real file)"
        mv "${dst}" "${dst}.backup"
    fi
    ln -sfn "${src}" "${dst}"
    echo "link ${rel} -> ${src}"
done
