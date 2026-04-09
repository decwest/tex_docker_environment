#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_DIR="${ROOT_DIR}/projects"

mkdir -p "${PROJECTS_DIR}"

if ! find "${PROJECTS_DIR}" -mindepth 1 -maxdepth 1 ! -name '.*' -print -quit | grep -q .; then
  printf 'No inputs found in %s\n' "${PROJECTS_DIR}"
  exit 0
fi

printf 'Inputs in %s:\n' "${PROJECTS_DIR}"
find "${PROJECTS_DIR}" -mindepth 1 -maxdepth 1 ! -name '.*' -printf '  %f\n' | sort
