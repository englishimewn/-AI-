#!/usr/bin/env bash
# package-plugin.sh - 本地打包插件；只有校验通过后才生成 tar.gz。
#
# 用法:
#   scripts/package-plugin.sh [--out 输出路径]
#   scripts/package-plugin.sh 输出路径
#
# 行为:
#   * 先运行 scripts/validate-plugin.sh，失败则不做任何打包。
#   * 归档时排除 .git/.codex/.agents、缓存、日志、dist 与已有 tar.gz。
#   * 绝不覆盖已存在的输出文件；目标存在时直接报错退出。
#
# 退出码:
#   0  打包成功
#   1  校验失败或打包失败
#   2  用法错误
set -uo pipefail

PLUGIN_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PLUGIN_ROOT
readonly PLUGIN_NAME="$(basename -- "$PLUGIN_ROOT")"
readonly MANIFEST="${PLUGIN_ROOT}/.codex-plugin/plugin.json"
readonly VALIDATOR="${PLUGIN_ROOT}/scripts/validate-plugin.sh"

usage() {
  cat <<'USAGE'
用法:
  scripts/package-plugin.sh [--out 输出路径]
  scripts/package-plugin.sh 输出路径

选项:
  -o, --out PATH  输出 tar.gz 路径；默认 dist/<插件名>-<版本>.tar.gz
  -h, --help      打印本帮助

说明:
  * 打包前会运行 scripts/validate-plugin.sh，校验失败则不生成任何文件。
  * 已存在的输出文件不会被覆盖，脚本会报错退出。
USAGE
}

script_error() {
  printf '错误: %s\n' "$1" >&2
  exit 1
}

usage_error() {
  printf '错误: %s\n' "$1" >&2
  usage >&2
  exit 2
}

out_path=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o|--out)
      if [[ "$#" -lt 2 ]]; then
        usage_error "选项 $1 缺少输出路径。"
      fi
      out_path="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      if [[ "$#" -gt 1 ]]; then
        usage_error "只接受一个输出路径。"
      fi
      if [[ "$#" -eq 1 ]]; then
        if [[ -n "$out_path" ]]; then
          usage_error "输出路径重复指定。"
        fi
        out_path="$1"
        shift
      fi
      ;;
    -*)
      usage_error "未知选项 $1"
      ;;
    *)
      if [[ -n "$out_path" ]]; then
        usage_error "输出路径重复指定（$out_path）。"
      fi
      out_path="$1"
      shift
      ;;
  esac
done

if [[ ! -f "$MANIFEST" ]]; then
  script_error "缺少 ${MANIFEST}，无法确定插件版本。"
fi

if ! command -v python3 >/dev/null 2>&1; then
  script_error "找不到 python3，无法读取插件版本。"
fi

version="$(
  python3 - "$MANIFEST" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
except (OSError, json.JSONDecodeError, ValueError) as error:
    print(f"ERROR {error}", file=sys.stderr)
    raise SystemExit(1)

version = data.get("version")
if not isinstance(version, str) or not version.strip():
    print("ERROR version must be a non-empty string", file=sys.stderr)
    raise SystemExit(1)

print(version.strip())
PY
)" || script_error "无法从 plugin.json 读取版本号。"

if [[ -z "$out_path" ]]; then
  out_dir="${PLUGIN_ROOT}/dist"
  out_path="${out_dir}/${PLUGIN_NAME}-${version}.tar.gz"
else
  case "$out_path" in
    */) script_error "输出路径不能是目录: ${out_path}" ;;
  esac
  if [[ -d "$out_path" ]]; then
    script_error "输出路径已经是一个目录: ${out_path}"
  fi
  out_dir="$(dirname -- "$out_path")"
fi

# 拒绝覆盖：用户指定的任意已有文件、链接或特殊文件都不动。
if [[ -e "$out_path" || -L "$out_path" ]]; then
  script_error "输出文件已存在，拒绝覆盖: ${out_path}"
fi

# 安全边界：不允许把归档写进 .git 目录。
out_abs="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$out_path" 2>/dev/null || printf '%s' "$out_path")"
case "${out_abs}" in
  "${PLUGIN_ROOT}/.git"|"${PLUGIN_ROOT}/.git/"*)
    script_error "输出路径落在 .git 目录内，请换一个位置: ${out_path}"
    ;;
esac

if ! mkdir -p -- "$out_dir"; then
  script_error "无法创建输出目录: ${out_dir}"
fi

if [[ ! -w "$out_dir" ]]; then
  script_error "输出目录不可写: ${out_dir}"
fi

printf '打包插件: %s (version %s)\n' "$PLUGIN_NAME" "$version"

if [[ ! -x "$VALIDATOR" ]]; then
  script_error "缺少可执行的校验脚本 ${VALIDATOR}，先运行 chmod +x scripts/*.sh。"
fi

if ! "$VALIDATOR"; then
  script_error "校验未通过，未生成任何归档。"
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/package-plugin.XXXXXX")" || script_error "无法创建临时目录。"
tmp_out="${tmp_dir}/${PLUGIN_NAME}-${version}.tar.gz"
cleanup() {
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

parent_dir="$(dirname -- "$PLUGIN_ROOT")"

# 只打包插件目录，排除版本控制、Codex 本地状态、缓存与日志。
tar \
  --exclude="${PLUGIN_NAME}/.git" \
  --exclude="${PLUGIN_NAME}/.git/*" \
  --exclude="${PLUGIN_NAME}/.codex" \
  --exclude="${PLUGIN_NAME}/.codex/*" \
  --exclude="${PLUGIN_NAME}/.agents" \
  --exclude="${PLUGIN_NAME}/.agents/*" \
  --exclude="${PLUGIN_NAME}/cache" \
  --exclude="${PLUGIN_NAME}/cache/*" \
  --exclude="${PLUGIN_NAME}/dist" \
  --exclude="${PLUGIN_NAME}/logs" \
  --exclude="${PLUGIN_NAME}/logs/*" \
  --exclude="${PLUGIN_NAME}/__pycache__" \
  --exclude="${PLUGIN_NAME}/__pycache__/*" \
  --exclude="*.cache" \
  --exclude="*.log" \
  --exclude="*.tar.gz" \
  --exclude="*.tgz" \
  --exclude=".DS_Store" \
  -czf "$tmp_out" \
  -C "$parent_dir" "$PLUGIN_NAME" || script_error "tar 打包失败。"

if ! tar -tzf "$tmp_out" >/dev/null 2>&1; then
  script_error "生成的归档无法读取，已放弃。"
fi

if ! tar -tzf "$tmp_out" | grep -qx "${PLUGIN_NAME}/.codex-plugin/plugin.json"; then
  script_error "归档缺少 ${PLUGIN_NAME}/.codex-plugin/plugin.json。"
fi

# 用 -n 避免竞态覆盖；若目标在此期间出现则保留原文件并报错。
mv -n -- "$tmp_out" "$out_path" || true
if [[ -e "$tmp_out" ]]; then
  script_error "输出文件已存在，拒绝覆盖: ${out_path}"
fi

printf '已生成: %s\n' "$out_path"
printf '归档条目数: %s\n' "$(tar -tzf "$out_path" | wc -l | tr -d '[:space:]')"
printf '重新校验归档: tar -tzf %s | head\n' "$out_path"
