#!/usr/bin/env bash
# run-official-validators.sh - 用 Codex 官方校验脚本检查本插件。
#
# 官方校验脚本随 Codex CLI 的“系统技能”一起分发，默认位于：
#   ${CODEX_HOME:-$HOME/.codex}/skills/.system/plugin-creator/scripts/validate_plugin.py
#   ${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/quick_validate.py
#
# 本脚本只读取这些本地文件并运行，不发起网络请求，也不写任何密钥。
#
# 用法:
#   scripts/run-official-validators.sh
#
# 环境变量:
#   CODEX_SYSTEM_SKILLS_DIR  覆盖系统技能目录（默认按 CODEX_HOME 推导）
#   PYTHON                   指定 Python 解释器（默认 python3）
#
# 退出码:
#   0  官方校验全部通过
#   1  校验失败，或找不到官方脚本 / PyYAML
#   2  用法错误
#
# 缺少官方脚本时的准备步骤（任选其一）:
#   npm install --global @openai/codex && codex app-server   # 首次启动写入系统技能
#   git clone --depth 1 https://github.com/openai/skills.git
#   export CODEX_SYSTEM_SKILLS_DIR=/path/to/skills/skills/.system
set -uo pipefail

PLUGIN_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PLUGIN_ROOT
readonly SKILLS_ROOT="${PLUGIN_ROOT}/skills"

python_bin="${PYTHON:-python3}"
system_skills="${CODEX_SYSTEM_SKILLS_DIR:-${CODEX_HOME:-$HOME/.codex}/skills/.system}"
readonly PLUGIN_VALIDATOR="${system_skills}/plugin-creator/scripts/validate_plugin.py"
readonly SKILL_VALIDATOR="${system_skills}/skill-creator/scripts/quick_validate.py"

failures=0

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  failures=$((failures + 1))
}

info() {
  printf '[INFO] %s\n' "$1"
}

usage() {
  printf '用法: scripts/run-official-validators.sh\n'
  printf '用 Codex 官方系统技能里的 plugin validator 与 quick_validate 校验本插件。\n'
  printf '只读取本地文件，不发起网络请求。\n'
  printf '\n环境变量:\n'
  printf '  CODEX_SYSTEM_SKILLS_DIR  系统技能目录（默认 ${CODEX_HOME:-$HOME/.codex}/skills/.system）\n'
  printf '  PYTHON                   Python 解释器（默认 python3）\n'
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 0 ]]; then
  printf '错误: 本脚本不接受参数（收到 %s 个）。\n' "$#" >&2
  exit 2
fi

if ! command -v "$python_bin" >/dev/null 2>&1; then
  printf '错误: 找不到 Python 解释器 %s（可用 PYTHON 覆盖）。\n' "$python_bin" >&2
  exit 1
fi

missing=0
for required in "$PLUGIN_VALIDATOR" "$SKILL_VALIDATOR"; do
  if [[ ! -f "$required" ]]; then
    fail "缺少官方校验脚本: $required"
    missing=1
  fi
done
if [[ "$missing" -eq 1 ]]; then
  printf '\n官方校验脚本来自 Codex 系统技能目录: %s\n' "$system_skills" >&2
  printf '准备方式（任选其一）:\n' >&2
  printf '  1) npm install --global @openai/codex && codex app-server\n' >&2
  printf '  2) git clone --depth 1 https://github.com/openai/skills.git，然后设置 CODEX_SYSTEM_SKILLS_DIR\n' >&2
  exit 1
fi

if ! "$python_bin" -c 'import yaml' >/dev/null 2>&1; then
  printf '错误: 官方校验脚本依赖 PyYAML，请先安装（例如 python3 -m pip install pyyaml）。\n' >&2
  exit 1
fi

printf '官方 plugin validator: %s\n' "$PLUGIN_VALIDATOR"
if "$python_bin" "$PLUGIN_VALIDATOR" "$PLUGIN_ROOT"; then
  pass "官方 plugin validator 通过（${PLUGIN_ROOT}）"
else
  fail "官方 plugin validator 未通过"
fi

printf '官方 skill quick_validate: %s\n' "$SKILL_VALIDATOR"
skill_count=0
skill_failed=0
for skill_dir in "$SKILLS_ROOT"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_count=$((skill_count + 1))
  if "$python_bin" "$SKILL_VALIDATOR" "$skill_dir"; then
    info "技能 $(basename -- "$skill_dir") 通过 quick_validate"
  else
    fail "技能 $(basename -- "$skill_dir") 未通过 quick_validate"
    skill_failed=$((skill_failed + 1))
  fi
done

if [[ "$skill_count" -eq 0 ]]; then
  fail "skills/ 下没有可校验的技能目录"
elif [[ "$skill_failed" -eq 0 ]]; then
  pass "官方 quick_validate 通过（${skill_count} 个技能）"
fi

if [[ "$failures" -eq 0 ]]; then
  printf '结果: 官方校验通过\n'
  exit 0
fi

printf '结果: 官方校验失败（%s 项）\n' "$failures" >&2
exit 1
