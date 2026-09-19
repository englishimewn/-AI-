# dual-model-coding

[![validate](https://github.com/englishimewn/model-agnostic-coding/actions/workflows/validate.yml/badge.svg)](https://github.com/englishimewn/model-agnostic-coding/actions/workflows/validate.yml)

**仓库地址（canonical）：<https://github.com/englishimewn/model-agnostic-coding>** ｜
许可证 MIT ｜ 版本与变更见 [CHANGELOG.md](./CHANGELOG.md)

GitHub 仓库名为 `model-agnostic-coding`（仓库改名后的新地址），插件名与安装命令仍是
`dual-model-coding`，两者不一致是有意为之。

把"规划模型负责需求、架构与验收，实现模型负责改代码与修测试，再由规划模型审查"的
角色分工，打包成一个可复用、可开源的 Codex 插件。

这套分工同时是成本优化策略：把高能力（通常也更高成本）的模型用在需求、架构、验收与
审查这些决定正确性、调用次数少的环节，把编码与测试修复这类迭代量大、单价更敏感的
环节交给成本更低的实现模型，以减少整体模型调用成本。这是设计目标，不是承诺——本插件
不保证具体节省比例，实际取决于 token、上下文、重试与 provider 价格，详见
[成本模型与限制](#成本模型与限制)。

这个定位不绑定任何具体模型、版本或供应商：插件描述的是**角色**与**责任边界**，
而不是某个模型的名字。当前实现中，主代理由 OpenAI/GPT 系模型承担，实现 worker 由
DeepSeek V4.1 Flash 承担；换成其他模型组合时，工作流与边界保持不变。

## 定位：模型无关

- **角色优先**：契约写在角色上——规划/架构/验收/审查，与实现/测试修复——而不是写在
  模型名上。模型可以替换，职责、任务包格式与验收流程不变。
- **当前实现**：本版本仍在 OpenAI/GPT 系主代理下运行，并调用 DeepSeek V4.1 Flash
  作为实现 worker；这是当前唯一的、可用的组合。
- **未来扩展**：为任意"规划 + 实现 + 审查"模型组合留出空间，见
  [未来扩展方向](#未来扩展方向)。这些是方向，不是当前已交付的功能。

## 当前能力

本版本已经实现并可直接使用的能力：

| 能力 | 现状 |
| --- | --- |
| 角色分工契约 | 主代理负责需求、架构、任务拆分、验收标准与最终审查，不写应用代码 |
| 实现 worker | 由 `scripts/codex-deepseek-worker` 以固定 provider/model 拉起 DeepSeek V4.1 Flash，只改任务包允许的文件 |
| 任务包 | `scripts/create-task-packet.sh` 生成自包含任务包（目标、范围、约束、验收、验证命令） |
| 单写者约束 | 一个可写 worker 同一时间只负责互不重叠的文件；并行 worker 必须文件所有权互斥 |
| 审查回路 | 主代理检查 diff 与测试摘要，把具体修正意见发回 worker，不采信 worker 的自述结论 |
| 密钥边界 | 密钥只留在本机凭据文件；任务包、prompt、日志与提交中都不出现 |
| 本地校验 | `scripts/validate-plugin.sh` 与 `scripts/run-official-validators.sh`，不发网络请求 |
| 打包与 CI | `scripts/package-plugin.sh` 先校验后打包；CI 在 push/PR 上跑同一套检查 |

未承诺的能力：本版本**没有**自动模型路由、没有多 provider 调度、没有成本或评测记录。
上述流程由主代理按规则执行，不存在自动择优或自动切换。

## 成本模型与限制

成本优化来自角色分工，而不是绑定某个模型或价格：

- 高能力/高成本模型只做需求分析、架构设计、验收标准与最终审查——这些环节数量少，
  但决定结果正确性，值得用更强的模型。
- 成本更低的实现模型承担编码与测试修复——这类工作迭代次数多、累计 token 可观，
  适合用单价更低的模型完成。
- 主代理不写应用代码，也不把 worker 的自述当作通过证据；实现循环的成本落在 worker
  侧，审查与验收仍由主代理把关。

限制（如实说明）：

- 本插件不承诺任何具体节省比例。实际节省取决于任务规模、token 用量、上下文长度、
  重试与返工次数，以及规划模型与实现模型各自的 provider 价格。
- 实现模型单价更低，并不等于总成本一定更低：如果任务拆分不当、上下文过长或反复返工，
  总成本可能反而上升。
- 当前版本**未采集**任何成本或用量数据：不记录 token、费用、调用次数或返工次数，
  因此本仓库里没有可引用的实测节省数字或基准。
- 角色与模型是分开的：任意"规划 + 实现 + 审查"的模型组合都能套用这套分工，成本特征
  取决于所选模型与 provider，而不是本插件本身。

成本与用量记录属于[未来扩展方向](#未来扩展方向)中的规划内容；在落地之前，本文档不会
声称已经支持成本追踪或给出节省数据。

## 快速入口

| 目标 | 入口 |
| --- | --- |
| 安装插件 | `codex plugin add dual-model-coding@personal`，详见[安装与启用](#安装与启用) |
| 安装启动器 | `install -m 0755 scripts/codex-deepseek-worker ~/.local/bin/codex-deepseek-worker` |
| 本地验证 | `scripts/validate-plugin.sh` 与 `scripts/run-official-validators.sh`，详见[测试与校验](#测试与校验) |
| 打包 / 发布 | `scripts/package-plugin.sh`，详见[打包](#打包)与[开源发布到 GitHub](#开源发布到-github) |
| 变更与版本 | [CHANGELOG.md](./CHANGELOG.md)、[版本发布](#版本发布) |

## 组件

| 路径 | 作用 |
| --- | --- |
| `.codex-plugin/plugin.json` | 插件清单（名称、描述、技能入口、界面文案） |
| `skills/dual-model-coding/SKILL.md` | 工作流：触发条件、角色、任务包模板、验收、回退、安全边界 |
| `scripts/codex-deepseek-worker` | 启动器：以固定 provider/model 拉起 DeepSeek 实现 worker |
| `scripts/create-task-packet.sh` | 生成自包含任务包（参数或 stdin） |
| `scripts/task-packet-template.md` | 任务包空模板 |
| `scripts/validate-plugin.sh` | 本地静态校验（不发网络请求） |
| `scripts/run-official-validators.sh` | 运行 Codex 官方 plugin validator 与 skill quick_validate |
| `scripts/package-plugin.sh` | 校验通过后打包 `tar.gz`，拒绝覆盖已有文件 |
| `.github/workflows/validate.yml` | CI：push/PR 时跑官方校验、`bash -n` 与本地自检 |
| `CONTRIBUTING.md` / `SECURITY.md` | 贡献流程、安全策略与漏洞报告 |

## 未来扩展方向

以下方向与当前角色契约兼容，属于规划内容，尚未实现；实现前不会改变本文档对
"当前能力"的描述。

| 方向 | 设想 | 现状 |
| --- | --- | --- |
| 可选模型 / provider | 实现 worker 的 provider、模型、CLI 启动方式可配置，不写死在启动器里 | 当前固定为 DeepSeek V4.1 Flash |
| 角色配置 | 规划、实现、审查三类角色可各自指定模型与参数，并允许审查角色独立于规划角色 | 当前规划与审查由同一主代理承担 |
| 路由策略 | 由显式策略（或规则文件）决定任务交给哪个模型，策略可审查、可复现 | 当前由主代理按规则人工判断，无自动路由 |
| 评测与成本记录 | 记录每次委派的模型、token/费用、测试结果与返工次数，用于横向比较模型组合 | 当前不采集、不落盘任何用量数据 |

这些方向只在文档中作为演进目标存在；在落地之前，README 与清单都不会声称已经支持。

## 前置条件

- Codex CLI（提供 `codex exec`），已在 `PATH` 中。
- `codex-deepseek-worker` 在 `PATH` 中，例如把本插件的
  `scripts/codex-deepseek-worker` 安装到 `~/.local/bin/`。
- 一个 DeepSeek API key，存放在本机凭据文件中（本插件不保存、不打印、不提交密钥）。
- `bash`；`scripts/validate-plugin.sh` 需要 `python3` 完成 JSON 解析检查。

## 安装与启用

先按用途选一种方式，两条路线互不冲突。

**A. 个人本地使用**（marketplace 文件在 `~/.agents/plugins/marketplace.json`，名称默认 `personal`）

```bash
# 1) 把插件目录放到个人插件目录 ~/plugins/
mkdir -p ~/plugins
cp -R dual-model-coding ~/plugins/dual-model-coding

# 2) 在 ~/.agents/plugins/marketplace.json 的 plugins 数组中加入下面这条条目
#    条目里的 source.path 始终写成 ./plugins/<插件名>（相对 marketplace 根目录）

# 3) 个人 marketplace 会被 Codex 自动发现，直接安装即可
codex plugin add dual-model-coding@personal
```

**B. 仓库 / 团队使用**（marketplace 文件在 `<repo-root>/.agents/plugins/marketplace.json`）

```bash
# 1) 把插件放进仓库的 plugins/ 目录
mkdir -p <repo-root>/plugins
cp -R dual-model-coding <repo-root>/plugins/dual-model-coding

# 2) 在 <repo-root>/.agents/plugins/marketplace.json 中加入同样的条目

# 3) 非默认路径的 marketplace 需要先显式安装，再安装插件
codex plugin marketplace add <repo-root>/.agents/plugins
codex plugin add dual-model-coding@<marketplace-name>
```

两种方式共用的 marketplace 条目（`name` 必须与 `plugin.json` 的 `name` 一致，
`source.path` 相对 marketplace 根目录）：

```json
{
  "name": "dual-model-coding",
  "source": { "source": "local", "path": "./plugins/dual-model-coding" },
  "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL" },
  "category": "Productivity"
}
```

无论选哪种方式，都把启动器单独装进 `PATH`：

```bash
install -m 0755 scripts/codex-deepseek-worker ~/.local/bin/codex-deepseek-worker
```

本插件不会自行写入 marketplace 文件、不修改 `config.toml`、也不上传任何内容；
只有你通过 `codex plugin marketplace add` 指定的目录会被读取。更新本地插件时，
先用官方 `plugin-creator` 技能的 `update_plugin_cachebuster.py` 刷新版本后缀再重装，
然后在新会话里验证。

## 配置密钥

凭据文件默认路径为 `~/.config/codex/deepseek.env`。启动器只在它**存在且可读**时加载，
并且只检查 `DEEPSEEK_API_KEY` 是否非空。

```bash
mkdir -p "${HOME}/.config/codex"
# 用本地编辑器创建并写入一行：DEEPSEEK_API_KEY=<本地密钥值>
# 下面的命令只创建空文件与权限，不会把密钥写进 shell 历史
: > "${HOME}/.config/codex/deepseek.env"
chmod 600 "${HOME}/.config/codex/deepseek.env"
```

把密钥填进该文件后，请勿把文件放进版本库：
`.gitignore` 已忽略 `*.env`、`.env*`、`secrets/` 等路径。

不要把密钥粘贴到聊天、issue、PR 或截图里请求排障；本插件不需要、也不接受以这种方式提供的密钥。

## 快速开始

```bash
# 0) 确认启动器可用（只打印版本，不调用模型）
codex-deepseek-worker --version

# 1) 生成任务包
scripts/create-task-packet.sh \
  --objective "修复 src/parser.ts 在空输入时抛出的 TypeError" \
  --scope "只允许修改 src/parser.ts 与 tests/parser.test.ts" \
  --acceptance "空输入返回空结果；新增用例通过；不改变公共 API" \
  --verification "npm test -- parser.test.ts" \
  --out /tmp/task-packet.md

# 2) 在目标仓库中把任务包交给 worker
#    参数必须恰好一个，整个任务包用一对引号包住
cd /path/to/target-repo
codex-deepseek-worker "$(cat /tmp/task-packet.md)"

# 3) 主代理审查 diff 与测试输出，必要时把修正意见再发回 worker
```

也可以直接使用模板：

```bash
scripts/create-task-packet.sh --template
```

## 责任边界

主代理负责：

- 需求澄清、架构设计、任务拆分、验收标准、风险决策、最终审查。
- 判断任务是否适合委派（纯问答、纯审查、纯文档讨论不委派）。
- 对最终交付负责，不把 worker 的自述当成通过证据。
- worker 不可用时停止实现并给出配置命令，而不是让用户把密钥贴进聊天。

实现 worker 负责：

- 只改任务包允许的文件，不扩大范围、不重新设计、不再委派其他代理。
- 先跑聚焦验证，再如实汇报改动、命令、结果与残留风险。

安全边界：

- 密钥只存在于本机凭据文件中；任务包、prompt、日志、提交信息里都不出现密钥。
- 一个可写 worker 同一时间只负责彼此重叠的文件；并行 worker 必须文件所有权互斥。
- 不写机器私有路径、不自动上传代码、不发起与任务无关的网络请求。

角色与模型是分开的：上面这些边界描述的是职责，不是某个具体模型。
当前版本中，主代理是 OpenAI/GPT 系模型，实现 worker 是 DeepSeek V4.1 Flash；
替换模型不会改变这些边界。

## 故障排查

**未检测到 `DEEPSEEK_API_KEY`**

启动器只在当前进程检查变量是否为空，不会显示它的值。请确认
`~/.config/codex/deepseek.env` 存在、可读、含有一行 `DEEPSEEK_API_KEY=...`，
然后 `source ~/.bashrc` 或打开新终端再试。

**`codex-deepseek-worker: command not found`**

把启动器安装到 `PATH` 中的目录：
`install -m 0755 scripts/codex-deepseek-worker ~/.local/bin/codex-deepseek-worker`。

**worker 很慢或超时**

通常是任务包范围过大。缩小允许修改的文件、删减验收条目，拆成多个小任务包重试。

**worker 改到了允许范围之外**

视为失败：恢复被误改的内容，在任务包中显式写出禁止修改的路径后重试。

**校验脚本报 FAIL**

按输出的 `[FAIL]` 行逐条修复；`[INFO]` 只是提示，不影响退出码。

## 测试与校验

```bash
# 本地静态检查（不发网络请求）
scripts/validate-plugin.sh

# Codex 官方 plugin validator + skill quick_validate
scripts/run-official-validators.sh

bash -n scripts/codex-deepseek-worker
scripts/create-task-packet.sh --template >/dev/null
```

`scripts/validate-plugin.sh` 的退出码：`0` 通过、`1` 存在失败项、`2` 用法错误。
它只做本地检查（manifest、技能文件、启动器、占位符与密钥模式、shell 语法、
`.github/workflows` 基本结构），不发起网络请求。

`scripts/run-official-validators.sh` 使用 Codex CLI 自带的系统技能脚本，需要 Python 3 与
PyYAML，并且系统技能目录存在：

```bash
npm install --global @openai/codex
codex app-server   # 首次启动把官方系统技能写入 ${CODEX_HOME:-$HOME/.codex}/skills/.system
scripts/run-official-validators.sh

# 或指向官方 openai/skills 仓库的克隆
git clone --depth 1 https://github.com/openai/skills.git /tmp/openai-skills
CODEX_SYSTEM_SKILLS_DIR=/tmp/openai-skills/skills/.system scripts/run-official-validators.sh
```

CI 在 `ubuntu-latest` 上对 `push` / `pull_request` 运行同样的检查，见
`.github/workflows/validate.yml`。工作流只读仓库、不引用 secret、不调用 DeepSeek worker。

## 打包

```bash
# 默认输出 dist/dual-model-coding-<版本>.tar.gz
scripts/package-plugin.sh

# 指定输出路径（已存在的文件不会被覆盖）
scripts/package-plugin.sh --out /tmp/dual-model-coding.tar.gz
```

`scripts/package-plugin.sh` 先运行 `scripts/validate-plugin.sh`，校验通过后才生成归档，
并排除 `.git`、`.codex`、`.agents`、缓存、日志与 `dist/`。目标文件已存在、目标是目录，
或输出路径落在 `.git` 内时，脚本都会以安全错误退出，不做任何写入。

## 开源发布到 GitHub

本插件的 canonical 仓库是 <https://github.com/englishimewn/model-agnostic-coding>；`plugin.json` 的
`repository` 与 `homepage` 已指向该地址，CI 徽章也已放在 README 顶部。

1. 确认工作树干净，且 `plugin.json` 的 `version` 与 `CHANGELOG.md` 最新条目一致。
2. 跑完上面"测试与校验"的全部检查，并做一次打包冒烟。
3. 加入远程并推送（仓库已存在时只需 `git push`）：

   ```bash
   git remote add origin https://github.com/englishimewn/model-agnostic-coding.git
   git branch -M main
   git push -u origin main
   ```

4. 若仓库改名或迁移，同步更新 `.codex-plugin/plugin.json` 的 `repository`、`homepage` 与
   README 顶部徽章；不要写空字符串、未填的占位标记或与本插件无关的 URL。
   确实没有可填写的地址时保持省略即可（官方校验只接受合法的字符串或字段缺省）。
5. README 顶部徽章指向本仓库的 `validate` 工作流，无需再手工替换：

   ```markdown
   ![validate](https://github.com/englishimewn/model-agnostic-coding/actions/workflows/validate.yml/badge.svg)
   ```

6. 需要对外分发时，把 `scripts/package-plugin.sh` 生成的 `tar.gz` 作为 release 附件上传。

## 版本发布

- 版本号遵循语义化版本，`plugin.json` 的 `version` 必须与 `CHANGELOG.md` 最新条目一致。
- 发布流程：更新 `CHANGELOG.md` → 同步 `plugin.json` 的 `version` → 跑校验与打包 →
  提交并打 tag（例如 `git tag -a v0.1.5 -m "dual-model-coding 0.1.5"`）→ 推送 tag →
  把归档附到 release。
- 本地迭代时不要靠递增版本号触发重装，改用官方 `plugin-creator` 技能的
  `update_plugin_cachebuster.py` 生成 `+codex.<cachebuster>` 后缀，再重装并在新会话验证。

## 许可证

MIT，见 [LICENSE](./LICENSE)。变更记录见 [CHANGELOG.md](./CHANGELOG.md)。

## English

Canonical repository: <https://github.com/englishimewn/model-agnostic-coding>.

`dual-model-coding` packages a model-agnostic split for Codex: a planning model owns
requirements, architecture, acceptance criteria, and review, while an implementation worker
writes scoped code changes and iterates on focused tests. The contract is defined over roles and
responsibility boundaries, not over model names or versions.

The same split is the cost strategy: keep the high-capability (and typically higher-cost) model
on the few, correctness-deciding steps — requirement analysis, architecture, acceptance criteria,
and review — and route the high-iteration coding and test-fix work to a lower-cost implementation
model, to reduce overall model call cost. This is a design goal, not a guarantee: no specific
savings percentage is promised, and actual savings depend on tokens, context, retries, and
provider prices. See "Cost model and limitations" below.

What this version ships today: the primary agent runs on an OpenAI/GPT model and the
implementation worker runs on DeepSeek V4.1 Flash through `scripts/codex-deepseek-worker`. That
is the only supported combination in this release. There is no automatic model routing, no
multi-provider scheduling, and no cost or evaluation tracking.

Roadmap directions (not yet implemented): configurable models and providers, per-role
configuration for planning, implementation, and review, explicit routing policies, and
evaluation plus cost records for comparing model combinations.

**Cost model and limitations**

- The higher-capability, higher-cost model handles requirement analysis, architecture, acceptance
  criteria, and final review: few calls, but they decide correctness.
- The lower-cost implementation worker owns coding and test-fix iterations: the high-volume work
  where cheaper tokens matter most.
- The primary model never writes application code and never treats the worker's self-report as
  proof, so the implementation loop runs on the worker while review stays with the primary model.
- No specific savings percentage is promised. Actual savings depend on task size, token usage,
  context length, retries and rework, and the provider prices of both the planning and
  implementation models.
- A cheaper implementation model does not guarantee a lower total cost: poor task decomposition,
  oversized context, or repeated rework can raise it.
- This release collects no cost or usage data — no token, spend, call-count, or rework tracking —
  so there are no measured savings figures to cite.
- Roles are separate from models, so any planning + implementation + review combination can use
  this split; the cost profile follows the chosen models and provider, not this plugin.

Cost and usage records remain a roadmap item, not a shipped feature.

- Install the plugin with `codex plugin add dual-model-coding@personal`; install the launcher with
  `install -m 0755 scripts/codex-deepseek-worker ~/.local/bin/codex-deepseek-worker`.
- Store the credential locally at `~/.config/codex/deepseek.env` with a single
  `DEEPSEEK_API_KEY=...` line and `chmod 600`. The launcher only checks that the variable is
  non-empty and never prints it.
- Draft a packet with `scripts/create-task-packet.sh` (objective, scope, constraints, acceptance
  criteria, verification commands) and pass exactly one argument to the launcher.
- Keep one write-capable worker per file set. Require focused tests before the worker reports.
- The primary model reviews the diff and test output, then fixes or re-delegates.
- Run `scripts/validate-plugin.sh` for local static checks and `scripts/run-official-validators.sh`
  for the official Codex plugin and skill validators.
- Build a release archive with `scripts/package-plugin.sh`; it validates first and never overwrites
  an existing output file. CI in `.github/workflows/validate.yml` runs the same checks.
- No network requests, no uploads, and no keys in prompts, logs, or the repository.
