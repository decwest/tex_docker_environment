#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_DIR="${ROOT_DIR}/projects"
WORK_ROOT="${ROOT_DIR}/.work"
OUTPUT_ROOT="${ROOT_DIR}/output"
IMAGE_TAG="${TEX_DOCKER_IMAGE:-tex-docker-environment:ubuntu24.04}"
INPUT_ARG="${1:-}"
TARGET_ARG="${2:-}"
LATEXMK_ARGS="${LATEXMK_ARGS:-}"

mkdir -p "${PROJECTS_DIR}" "${WORK_ROOT}" "${OUTPUT_ROOT}"

abs_path() {
  local path="$1"
  (
    cd "$(dirname "$path")"
    printf '%s/%s\n' "$(pwd)" "$(basename "$path")"
  )
}

resolve_input() {
  local raw="$1"
  local -a entries=()

  if [[ -n "$raw" ]]; then
    if [[ -e "$raw" ]]; then
      abs_path "$raw"
      return
    fi

    if [[ -e "${ROOT_DIR}/${raw}" ]]; then
      abs_path "${ROOT_DIR}/${raw}"
      return
    fi

    if [[ -e "${PROJECTS_DIR}/${raw}" ]]; then
      abs_path "${PROJECTS_DIR}/${raw}"
      return
    fi

    printf 'Input not found: %s\n' "$raw" >&2
    exit 1
  fi

  while IFS= read -r -d '' entry; do
    entries+=("$entry")
  done < <(find "${PROJECTS_DIR}" -mindepth 1 -maxdepth 1 ! -name '.*' -print0 | sort -z)

  if [[ ${#entries[@]} -eq 0 ]]; then
    printf 'No input found in %s\n' "${PROJECTS_DIR}" >&2
    printf 'Put one zip file or one extracted project directory into %s and run task again.\n' "${PROJECTS_DIR}" >&2
    exit 1
  fi

  if [[ ${#entries[@]} -gt 1 ]]; then
    printf 'Multiple inputs found in %s\n' "${PROJECTS_DIR}" >&2
    printf 'Specify one with: task compile INPUT=projects/<name>\n' >&2
    printf '\nCandidates:\n' >&2
    printf '  %s\n' "${entries[@]##*/}" >&2
    exit 1
  fi

  abs_path "${entries[0]}"
}

slugify() {
  local raw="$1"
  raw="${raw%.zip}"
  raw="${raw// /_}"
  printf '%s' "$raw" | tr -cd 'A-Za-z0-9._-'
}

find_project_root() {
  local extracted_dir="$1"
  local -a top_entries=()

  while IFS= read -r -d '' entry; do
    top_entries+=("$entry")
  done < <(find "${extracted_dir}" -mindepth 1 -maxdepth 1 ! -name '__MACOSX' ! -name '.*' -print0 | sort -z)

  if [[ ${#top_entries[@]} -eq 1 && -d "${top_entries[0]}" ]]; then
    printf '%s\n' "${top_entries[0]}"
    return
  fi

  printf '%s\n' "${extracted_dir}"
}

find_tex_candidates() {
  local project_root="$1"
  local rel_path=""

  if command -v rg >/dev/null 2>&1; then
    (
      cd "${project_root}" &&
        rg -l --glob '*.tex' '\\document(class|style)' . |
        sed 's#^\./##' |
        sort
    )
    return
  fi

  while IFS= read -r -d '' file; do
    if grep -Eq '\\document(class|style)' "$file"; then
      rel_path="${file#${project_root}/}"
      printf '%s\n' "${rel_path}"
    fi
  done < <(find "${project_root}" -type f -name '*.tex' -print0 | sort -z)
}

resolve_target() {
  local project_root="$1"
  local requested_target="$2"
  local -a candidates=()
  local -a main_candidates=()
  local -a preferred_candidates=()
  local -a preferred_names=(
    "main.tex"
    "manuscript.tex"
    "paper.tex"
    "article.tex"
    "report.tex"
    "thesis.tex"
    "draft.tex"
  )
  local name candidate

  if [[ -n "$requested_target" ]]; then
    if [[ -f "${project_root}/${requested_target}" ]]; then
      printf '%s\n' "$requested_target"
      return
    fi

    printf 'Requested target not found: %s\n' "$requested_target" >&2
    exit 1
  fi

  mapfile -t candidates < <(
    find_tex_candidates "${project_root}"
  )

  if [[ ${#candidates[@]} -eq 0 ]]; then
    printf 'No standalone TeX entrypoint was found under %s\n' "${project_root}" >&2
    printf 'Specify one explicitly with: task compile INPUT=... TARGET=path/to/file.tex\n' >&2
    exit 1
  fi

  if [[ ${#candidates[@]} -eq 1 ]]; then
    printf '%s\n' "${candidates[0]}"
    return
  fi

  for candidate in "${candidates[@]}"; do
    if [[ "$(basename "$candidate")" == "main.tex" ]]; then
      main_candidates+=("$candidate")
    fi
  done

  if [[ ${#main_candidates[@]} -eq 1 ]]; then
    printf '%s\n' "${main_candidates[0]}"
    return
  fi

  for name in "${preferred_names[@]}"; do
    for candidate in "${candidates[@]}"; do
      if [[ "$(basename "$candidate")" == "$name" ]]; then
        preferred_candidates+=("$candidate")
      fi
    done
  done

  if [[ ${#preferred_candidates[@]} -eq 1 ]]; then
    printf '%s\n' "${preferred_candidates[0]}"
    return
  fi

  printf 'Multiple standalone TeX files were found.\n' >&2
  printf 'Specify the target explicitly with: task compile INPUT=... TARGET=path/to/file.tex\n' >&2
  printf '\nCandidates:\n' >&2
  printf '  %s\n' "${candidates[@]}" >&2
  exit 1
}

copy_outputs() {
  local project_root="$1"
  local target_rel="$2"
  local output_dir="$3"
  local target_dir_rel
  local target_name
  local source_dir
  local destination_dir
  local ext

  target_dir_rel="$(dirname "$target_rel")"
  target_name="$(basename "${target_rel%.tex}")"
  source_dir="${project_root}"
  destination_dir="${output_dir}"

  if [[ "$target_dir_rel" != "." ]]; then
    source_dir="${project_root}/${target_dir_rel}"
    destination_dir="${output_dir}/${target_dir_rel}"
  fi

  mkdir -p "${destination_dir}"

  for ext in pdf log aux bbl blg fdb_latexmk fls out synctex.gz run.xml bcf; do
    if [[ -f "${source_dir}/${target_name}.${ext}" ]]; then
      cp -f "${source_dir}/${target_name}.${ext}" "${destination_dir}/"
    fi
  done
}

INPUT_PATH="$(resolve_input "${INPUT_ARG}")"
INPUT_BASENAME="$(basename "${INPUT_PATH}")"
PROJECT_SLUG="$(slugify "${INPUT_BASENAME}")"
WORK_DIR="${WORK_ROOT}/${PROJECT_SLUG}"
PROJECT_ROOT=""

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

if [[ -d "${INPUT_PATH}" ]]; then
  cp -a "${INPUT_PATH}" "${WORK_DIR}/project"
  PROJECT_ROOT="${WORK_DIR}/project"
elif [[ -f "${INPUT_PATH}" && "${INPUT_PATH}" == *.zip ]]; then
  unzip -q -o "${INPUT_PATH}" -d "${WORK_DIR}/unzipped"
  PROJECT_ROOT="$(find_project_root "${WORK_DIR}/unzipped")"
else
  printf 'Unsupported input type: %s\n' "${INPUT_PATH}" >&2
  printf 'Use a .zip file or a directory.\n' >&2
  exit 1
fi

TARGET_REL="$(resolve_target "${PROJECT_ROOT}" "${TARGET_ARG}")"
OUTPUT_DIR="${OUTPUT_ROOT}/${PROJECT_SLUG}"

printf 'Building Docker image: %s\n' "${IMAGE_TAG}"
docker build -f "${ROOT_DIR}/Dockerfile.tex" -t "${IMAGE_TAG}" "${ROOT_DIR}"

printf 'Compiling project: %s\n' "${INPUT_PATH}"
printf 'TeX target: %s\n' "${TARGET_REL}"
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "${PROJECT_ROOT}:/work" \
  -w /work \
  "${IMAGE_TAG}" \
  bash -lc "latexmk -pdf -file-line-error -interaction=nonstopmode -halt-on-error ${LATEXMK_ARGS} \"${TARGET_REL}\""

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
copy_outputs "${PROJECT_ROOT}" "${TARGET_REL}" "${OUTPUT_DIR}"

printf 'Done: %s\n' "${OUTPUT_DIR}"
printf 'PDF: %s\n' "${OUTPUT_DIR}/${TARGET_REL%.tex}.pdf"
