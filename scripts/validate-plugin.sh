#!/usr/bin/env bash
# validate-plugin.sh - 本地静态校验，不发起任何网络请求。
#
# 退出码:
#   0  全部通过
#   1  至少一项检查失败
#   2  用法错误
#
# 检查内容:
#   1) .codex-plugin/plugin.json 存在、可被 Python 解析为 JSON、必备字段齐全
#   2) skills/<name>/SKILL.md 存在且带 name/description frontmatter
#   3) scripts/codex-deepseek-worker 存在、可执行、包含固定 provider/model 配置
#   4) 所有 shell 脚本的语法（bash -n）与可执行位
#   5) 文件列表中无占位符标记与常见密钥模式
#   6) .github/workflows 存在时，工作流 YAML 的基本结构（非空、含 on:/jobs:、无制表符）
#
# 注意: 密钥扫描有意跳过本文件，因为本文件包含用于检测的模式文本。
set -uo pipefail

PLUGIN_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PLUGIN_ROOT
readonly MANIFEST="${PLUGIN_ROOT}/.codex-plugin/plugin.json"
readonly WORKER_LAUNCHER="${PLUGIN_ROOT}/scripts/codex-deepseek-worker"

checks=0
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

check() {
  checks=$((checks + 1))
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  printf '用法: scripts/validate-plugin.sh\n'
  printf '本地校验插件结构、技能文件、启动器、占位符与密钥模式；不发起网络请求。\n'
  exit 0
fi

if [[ "$#" -ne 0 ]]; then
  printf '错误: 本脚本不接受参数（收到 %s 个）。\n' "$#" >&2
  exit 2
fi

printf '校验插件: %s\n' "$PLUGIN_ROOT"

# 1) manifest：必须能被 Python 解析为合法 JSON，且必备字段齐全。
check
if [[ ! -f "$MANIFEST" ]]; then
  fail "缺少 .codex-plugin/plugin.json"
elif ! command -v python3 >/dev/null 2>&1; then
  fail "找不到 python3，无法执行 JSON 解析检查"
else
  manifest_report="$(
    python3 - "$MANIFEST" <<'PY' 2>&1
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except json.JSONDecodeError as error:
    print(f"INVALID_JSON: {error}")
    raise SystemExit(1)
except OSError as error:
    print(f"UNREADABLE: {error}")
    raise SystemExit(1)

if not isinstance(data, dict):
    print("NOT_OBJECT: plugin.json must contain a JSON object")
    raise SystemExit(1)

problems = []
if data.get("name") != "dual-model-coding":
    problems.append(f"name must be 'dual-model-coding' (got {data.get('name')!r})")
for field in ("version", "description"):
    value = data.get(field)
    if not isinstance(value, str) or not value.strip():
        problems.append(f"{field} must be a non-empty string")

author = data.get("author")
if not isinstance(author, dict):
    problems.append("author must be an object")
elif not isinstance(author.get("name"), str) or not author.get("name", "").strip():
    problems.append("author.name must be a non-empty string")

interface = data.get("interface")
if not isinstance(interface, dict):
    problems.append("interface must be an object")
else:
    for field in (
        "displayName",
        "shortDescription",
        "longDescription",
        "developerName",
        "category",
    ):
        value = interface.get(field)
        if not isinstance(value, str) or not value.strip():
            problems.append(f"interface.{field} must be a non-empty string")
    if "defaultPrompt" not in interface and "default_prompt" not in interface:
        problems.append("interface.defaultPrompt is required")
    capabilities = interface.get("capabilities")
    if not isinstance(capabilities, list) or not all(
        isinstance(item, str) and item.strip() for item in capabilities
    ):
        problems.append("interface.capabilities must be an array of strings")

if problems:
    for problem in problems:
        print(f"PROBLEM: {problem}")
    raise SystemExit(1)

print(f"name={data['name']} version={data['version']}")
PY
  )"
  manifest_status=$?
  if [[ "$manifest_status" -eq 0 ]]; then
    pass "plugin.json 通过 Python JSON 解析与必备字段检查（${manifest_report}）"
  else
    fail "plugin.json 校验失败"
    printf '%s\n' "$manifest_report" | sed 's/^/       /'
  fi
fi

# 2) 技能文件
check
skills_root="${PLUGIN_ROOT}/skills"
if [[ ! -d "$skills_root" ]]; then
  fail "缺少 skills/ 目录"
else
  skill_found=0
  skill_failed=0
  for skill_dir in "$skills_root"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_found=$((skill_found + 1))
    skill_name="$(basename -- "$skill_dir")"
    skill_md="${skill_dir}SKILL.md"
    if [[ ! -f "$skill_md" ]]; then
      fail "技能 ${skill_name} 缺少 SKILL.md"
      skill_failed=1
      continue
    fi
    if [[ "$(head -n 1 -- "$skill_md")" != "---" ]]; then
      fail "技能 ${skill_name} 的 SKILL.md 必须以 YAML frontmatter 开头"
      skill_failed=1
      continue
    fi
    if ! grep -qE '^name:[[:space:]]*[^[:space:]]' -- "$skill_md"; then
      fail "技能 ${skill_name} 缺少 frontmatter name"
      skill_failed=1
    fi
    if ! grep -qE '^description:[[:space:]]*[^[:space:]]' -- "$skill_md"; then
      fail "技能 ${skill_name} 缺少 frontmatter description"
      skill_failed=1
    fi
    if [[ "$skill_name" != "dual-model-coding" ]]; then
      info "技能目录 ${skill_name} 与插件名不同，确认是否有意为之"
    fi
  done
  if [[ "$skill_found" -eq 0 ]]; then
    fail "skills/ 下没有技能目录"
  elif [[ "$skill_failed" -eq 0 ]]; then
    pass "技能文件结构正确（${skill_found} 个技能）"
  fi
fi

# 3) 启动器
check
if [[ ! -f "$WORKER_LAUNCHER" ]]; then
  fail "缺少 scripts/codex-deepseek-worker"
else
  launcher_failed=0
  if [[ ! -x "$WORKER_LAUNCHER" ]]; then
    fail "scripts/codex-deepseek-worker 不可执行（需要 chmod +x）"
    launcher_failed=1
  fi
  if ! grep -q 'model_provider="deepseek"' -- "$WORKER_LAUNCHER"; then
    fail "启动器缺少 model_provider=\"deepseek\" 配置"
    launcher_failed=1
  fi
  if ! grep -q 'model="deepseek-flash"' -- "$WORKER_LAUNCHER"; then
    fail "启动器缺少 model=\"deepseek-flash\" 配置"
    launcher_failed=1
  fi
  if ! grep -q 'DEEPSEEK_API_KEY' -- "$WORKER_LAUNCHER"; then
    fail "启动器未检查 DEEPSEEK_API_KEY 是否可用"
    launcher_failed=1
  fi
  if ! command -v codex >/dev/null 2>&1; then
    info "PATH 中没有 codex；启动器只做静态检查"
  fi
  if [[ "$launcher_failed" -eq 0 ]]; then
    pass "启动器存在、可执行、配置与凭据检查正确"
  fi
fi

# 4) shell 语法与可执行位
check
syntax_failed=0
script_count=0
for script in "$PLUGIN_ROOT"/scripts/*; do
  [[ -f "$script" ]] || continue
  if [[ "$(head -n 1 -- "$script")" != '#!'* ]]; then
    continue
  fi
  script_count=$((script_count + 1))
  if [[ ! -x "$script" ]]; then
    fail "脚本不可执行: ${script#"$PLUGIN_ROOT"/}（需要 chmod +x）"
    syntax_failed=1
  fi
  if ! bash -n -- "$script" 2>/dev/null; then
    fail "shell 语法错误: ${script#"$PLUGIN_ROOT"/}"
    bash -n -- "$script" || true
    syntax_failed=1
  fi
done
if [[ "$script_count" -eq 0 ]]; then
  fail "scripts/ 下没有可检查的 shell 脚本"
elif [[ "$syntax_failed" -eq 0 ]]; then
  pass "shell 语法与可执行位检查通过（${script_count} 个脚本）"
fi

# 5) 占位符与密钥模式
check
TODO_RE='\[TODO'
OPENAI_KEY_RE='sk-[A-Za-z0-9_-]{20,}'
ENV_KEY_RE='DEEPSEEK_API_KEY["'"'"']?[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9_-]{16,}'
API_KEY_RE='[Aa][Pp][Ii][_-]?[Kk][Ee][Yy]["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_-]{20,}'
PEM_RE='-----BEGIN [A-Z ]*PRIVATE KEY-----'

scan_targets() {
  local candidate
  for candidate in \
    "$PLUGIN_ROOT/README.md" \
    "$PLUGIN_ROOT/CONTRIBUTING.md" \
    "$PLUGIN_ROOT/SECURITY.md" \
    "$PLUGIN_ROOT/CHANGELOG.md" \
    "$PLUGIN_ROOT/LICENSE" \
    "$PLUGIN_ROOT/.gitignore" \
    "$MANIFEST"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\0' "$candidate"
    fi
  done
  if [[ -d "$PLUGIN_ROOT/skills" ]]; then
    find "$PLUGIN_ROOT/skills" -type f -print0
  fi
  if [[ -d "$PLUGIN_ROOT/scripts" ]]; then
    # 跳过本文件自身：它包含用于检测的模式文本。
    find "$PLUGIN_ROOT/scripts" -type f ! -name 'validate-plugin.sh' -print0
  fi
  if [[ -d "$PLUGIN_ROOT/.github" ]]; then
    find "$PLUGIN_ROOT/.github" -type f -print0
  fi
}

scan_hits=0
scanned=0

scan_pattern() {
  local label="$1" pattern="$2" file="$3"
  if grep -nE -- "$pattern" "$file" >/dev/null 2>&1; then
    fail "${label}: ${file#"$PLUGIN_ROOT"/}"
    grep -nE -- "$pattern" "$file" 2>/dev/null | head -n 3 | sed 's/^/       /'
    scan_hits=1
  fi
}

while IFS= read -r -d '' file; do
  scanned=$((scanned + 1))
  scan_pattern "占位符标记" "$TODO_RE" "$file"
  scan_pattern "疑似 OpenAI 风格密钥" "$OPENAI_KEY_RE" "$file"
  scan_pattern "疑似密钥赋值" "$ENV_KEY_RE" "$file"
  scan_pattern "疑似 API key 赋值" "$API_KEY_RE" "$file"
  scan_pattern "私钥文件内容" "$PEM_RE" "$file"
done < <(scan_targets)

if [[ "$scan_hits" -eq 0 ]]; then
  pass "无占位符标记与常见密钥模式（扫描 ${scanned} 个文件）"
fi

# 6) .github workflow：存在时做不依赖 yq 的基本 YAML 检查。
check
workflow_dir="${PLUGIN_ROOT}/.github/workflows"
if [[ ! -d "$workflow_dir" ]]; then
  info "未找到 .github/workflows/，跳过 CI 工作流检查"
else
  workflow_count=0
  workflow_failed=0
  for workflow in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
    [[ -f "$workflow" ]] || continue
    workflow_count=$((workflow_count + 1))
    workflow_rel="${workflow#"$PLUGIN_ROOT"/}"
    if [[ ! -s "$workflow" ]]; then
      fail "CI 工作流为空文件: ${workflow_rel}"
      workflow_failed=1
      continue
    fi
    if grep -q $'\t' -- "$workflow"; then
      fail "CI 工作流含制表符（YAML 缩进必须用空格）: ${workflow_rel}"
      workflow_failed=1
    fi
    if ! grep -qE '^on[[:space:]]*:' -- "$workflow"; then
      fail "CI 工作流缺少顶层 on: 触发器: ${workflow_rel}"
      workflow_failed=1
    fi
    if ! grep -qE '^jobs[[:space:]]*:' -- "$workflow"; then
      fail "CI 工作流缺少顶层 jobs: ${workflow_rel}"
      workflow_failed=1
    fi
  done
  if [[ "$workflow_count" -eq 0 ]]; then
    fail ".github/workflows/ 下没有工作流文件"
  elif [[ "$workflow_failed" -eq 0 ]]; then
    pass "CI 工作流 YAML 基本检查通过（${workflow_count} 个文件）"
  fi
fi

printf '\n检查项: %s，失败: %s\n' "$checks" "$failures"
if [[ "$failures" -eq 0 ]]; then
  printf '结果: 通过\n'
  exit 0
fi
printf '结果: 失败（退出码 1）\n'
exit 1
