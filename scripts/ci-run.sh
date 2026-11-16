#!/usr/bin/env bash
# Run a command in the build environment: inside the AlmaLinux builder
# container on Linux (image built by .github/actions/prepare), directly on
# macOS.  Used by the GitHub workflows.
set -euo pipefail

case "${CI_KIND:?CI_KIND must be linux or macos}" in
    linux)
        exec docker run --rm \
            --user "$(id -u):$(id -g)" \
            -e HOME=/tmp \
            -e JOBS -e GITHUB_RUN_ID -e GITHUB_SERVER_URL -e GITHUB_REPOSITORY \
            -v "$PWD:/work" -w /work \
            qt-builder "$@"
        ;;
    macos)
        exec "$@"
        ;;
    *)
        echo "Unknown CI_KIND $CI_KIND" >&2
        exit 1
        ;;
esac
