#!/usr/bin/env bash
# create-task-packet.sh - 生成自包含的 DeepSeek worker 任务包。
#
# 用法:
#   create-task-packet.sh --objective "..." [--scope "..."] \
#       [--constraints "..."] [--acceptance "..."] \
#       [--verification "cmd"] [--verification "cmd"] \
#       [--context "..."] [--out FILE]
#   create-task-packet.sh --template
#   printf '补充上下文' | create-task-packet.sh --objective "..."
#
# 不使用 eval，也不把参数拼成可执行字符串；所有取值只作为文本写入任务包。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly TEMPLATE_FILE="${SCRIPT_DIR}/task-packet-template.md"

objective=""
scope=""
constraints=""
acceptance=""
context=""
out_file=""
print_template=0
verifications=()

usage() {
  cat >&2 <<'USAGE'
用法:
  create-task-packet.sh --objective "目标" [--scope "允许修改的文件"] \
    [--constraints "约束"] [--acceptance "验收标准"] \
    [--verification "验证命令"]... [--context "补充上下文"] [--out FILE]
  create-task-packet.sh --template
  printf '补充上下文' | create-task-packet.sh --objective "目标"

选项:
  --objective     必填，目标与动机。
  --scope         允许修改的文件或目录，以及禁止修改的范围。
  --constraints   约束、风格要求、不可改动项。
  --acceptance    验收标准（可观察、可验证）。
  --verification  聚焦验证命令，可重复传入。
  --context       额外上下文，与 stdin 内容一并附加。
  --out           把任务包写入文件（默认打印到 stdout）。
  --template      直接打印 scripts/task-packet-template.md。
USAGE
}

# $1 = 选项名，$2 = 剩余参数个数
require_value() {
  if [[ "$2" -lt 2 ]]; then
    printf '错误: 选项 %s 缺少取值。\n' "$1" >&2
    exit 2
  fi
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --objective)
      require_value "$1" "$#"
      objective="$2"
      shift 2
      ;;
    --scope)
      require_value "$1" "$#"
      scope="$2"
      shift 2
      ;;
    --constraints)
      require_value "$1" "$#"
      constraints="$2"
      shift 2
      ;;
    --acceptance)
      require_value "$1" "$#"
      acceptance="$2"
      shift 2
      ;;
    --verification|--verifications)
      require_value "$1" "$#"
      verifications+=("$2")
      shift 2
      ;;
    --context)
      require_value "$1" "$#"
      context="$2"
      shift 2
      ;;
    --out)
      require_value "$1" "$#"
      out_file="$2"
      shift 2
      ;;
    --template)
      print_template=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '错误: 未知选项 %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$print_template" -eq 1 ]]; then
  if [[ -r "$TEMPLATE_FILE" ]]; then
    exec cat -- "$TEMPLATE_FILE"
  fi
  printf '错误: 找不到模板文件 %s\n' "$TEMPLATE_FILE" >&2
  exit 1
fi

if [[ -z "$objective" ]]; then
  printf '错误: --objective 为必填项。\n' >&2
  usage
  exit 2
fi

# stdin 非终端时把内容作为补充上下文，避免交互式挂起。
stdin_context=""
if [[ ! -t 0 ]]; then
  stdin_context="$(cat 2>/dev/null || true)"
fi

emit() {
  printf '%s\n' '# DeepSeek 实现任务包'
  printf '\n## 目标 Objective\n\n%s\n' "$objective"

  printf '\n## 允许文件范围 Allowed file scope\n\n'
  if [[ -n "$scope" ]]; then
    printf '%s\n' "$scope"
  else
    printf '只允许修改: <显式列出路径或 glob>\n'
    printf '禁止修改: <列出用户数据、密钥文件、生成物、无关模块>\n'
  fi

  printf '\n## 约束 Constraints\n\n'
  if [[ -n "$constraints" ]]; then
    printf '%s\n' "$constraints"
  else
    printf -- '- 保持现有代码风格与依赖，不引入新依赖。\n'
    printf -- '- 不修改公共 API、配置格式或数据迁移。\n'
    printf -- '- 不在代码、注释、日志或提交信息中写入任何密钥、token、私有路径。\n'
  fi

  printf '\n## 验收标准 Acceptance criteria\n\n'
  if [[ -n "$acceptance" ]]; then
    printf '%s\n' "$acceptance"
  else
    printf -- '- <可观察、可验证的行为>\n'
    printf -- '- <边界条件与错误路径>\n'
  fi

  printf '\n## 聚焦验证 Verification commands\n\n'
  if [[ "${#verifications[@]}" -gt 0 ]]; then
    verification=""
    for verification in "${verifications[@]}"; do
      printf -- '- %s\n' "$verification"
    done
  else
    printf -- '- <聚焦测试或 lint 命令>\n'
  fi

  printf '\n## 任务边界 Boundary\n\n'
  printf -- '- 你是实现 worker：不要委派其他代理，不要重新设计任务。\n'
  printf -- '- 只修改上面允许的文件；越界改动视为失败。\n'
  printf -- '- 先跑聚焦验证，再汇报；测试失败要如实说明，不要假装通过。\n'

  printf '\n## 交付格式 Deliverable\n\n'
  printf '汇报：改动文件清单、实现的行为、执行的命令与结果、残留风险与未验证部分。\n'

  if [[ -n "$context" || -n "$stdin_context" ]]; then
    printf '\n## 补充上下文 Additional context\n\n'
    if [[ -n "$context" ]]; then
      printf '%s\n' "$context"
    fi
    if [[ -n "$stdin_context" ]]; then
      printf '%s\n' "$stdin_context"
    fi
  fi
}

if [[ -n "$out_file" ]]; then
  emit >"$out_file"
  printf '已写入任务包: %s\n' "$out_file" >&2
else
  emit
fi
