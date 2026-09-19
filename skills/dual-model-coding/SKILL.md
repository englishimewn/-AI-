---
name: dual-model-coding
description: Run a two-model coding workflow where the primary OpenAI model owns requirements, architecture, acceptance criteria, and review, and the DeepSeek V4.1 Flash worker implements scoped code changes and test-fix iterations through the codex-deepseek-worker launcher. Use when a repository code change should be planned and reviewed by the primary model but written by the implementation worker, and when deciding whether that worker is available.
---

# Dual-Model Coding

把编码工作拆成两个角色：主代理（OpenAI/GPT 系模型）负责分析与审查，DeepSeek V4.1 Flash
worker 负责改代码与跑测试。目标是在保持单一责任链的前提下，用更便宜的模型承担实现循环。

Split coding work between a primary architect/reviewer model and a DeepSeek implementation
worker. While a worker is available, the primary model does not write application code.

## 何时使用 / When this applies

适用场景：

- 用户要求对仓库做代码改动、加功能、修 bug、重构，或"让 DeepSeek 实现、你审查"。
- 任务可以拆成"先定范围与验收，再实现，再审查"三段。
- 需要把实现循环（写代码 + 修测试）交给独立 worker 以节省主模型额度。

不适用场景（直接由主代理回答，不要启动 worker）：

- 纯解释、问答、方案讨论的请求。
- 只做代码审查或评审、不需要修改文件的请求。
- 需求还没收敛、主代理还在做架构决策的阶段。

## 角色与职责 / Roles

**主代理（架构 + 验收 + 审查）**

- 澄清需求，确认范围、风险与不可触碰的部分。
- 做架构与接口设计，拆分任务，定义验收标准与聚焦验证命令。
- 生成自包含任务包，通过 `codex-deepseek-worker` 交给 worker（见下方模板）。
- 审查返回的 diff 与测试摘要，必要时把具体修正意见再发回 worker。
- 决定是否回退、是否停止、是否向用户上报阻塞。

**实现 worker（DeepSeek V4.1 Flash）**

- 只执行任务包，不改设计、不扩大范围、不再委派别的代理。
- 只修改任务包允许的文件；重叠文件不得并行交给多个 worker。
- 先改代码，再跑聚焦测试，最后回报：改了哪些文件、实现了什么行为、跑了哪些命令、
  结果如何、还有什么风险。
- 信息不足或发生冲突时停止并说明阻塞，不猜测、不假装测试通过。

**用户可见的边界**

- 主代理对最终结果负责；worker 的输出只是待审查的实现。
- 未经主代理审查的 worker 输出不得直接宣称"已完成"。

## 工作流 / Workflow

1. **需求与设计（主代理）**：确认目标、约束、风险，写下验收标准与要跑的验证命令。
2. **任务包（主代理）**：按模板生成一个自包含任务包，明确允许文件范围。
3. **委派（主代理）**：在目标仓库中执行
   `codex-deepseek-worker '<self-contained task packet>'`
   —— 参数必须恰好一个，整个任务包放在一对引号里。
4. **实现与测试（worker）**：worker 改代码、跑聚焦测试、回报 diff 与测试结果。
5. **审查（主代理）**：检查 diff 是否符合架构与验收标准，测试是否真的覆盖风险点。
6. **修正回路**：不合格就把具体、可执行的修正意见再次发给 worker（同一条命令），
   不要自己动手改应用代码。
7. **收尾**：主代理给出结论、证据（文件、命令、结果）、残留风险与后续建议。

## 任务包模板 / Task packet template

任务包必须是自包含的：worker 看不到你的对话历史。推荐结构：

```text
目标 Objective
  一句话说明要实现的行为与动机。

允许文件范围 Allowed file scope
  只允许修改：<显式路径或 glob>
  禁止修改：<路径>；不得新建未列出的文件。

约束 Constraints
  - 保持现有风格与依赖，不引入新依赖（除非明确允许）。
  - 不修改公共 API、配置格式或数据迁移。
  - 不写日志、注释或提交信息里的任何密钥、token、内部 URL、私有路径。

验收标准 Acceptance criteria
  - <可观察、可验证的行为 1>
  - <边界条件 2>

聚焦验证 Verification commands
  - <测试或 lint 命令 1>
  - <命令 2>

交付格式 Deliverable
  汇报：改动文件、实现行为、执行的命令与结果、残留风险；测试失败要如实说明。
```

仓库内置的两个辅助入口：

- `scripts/create-task-packet.sh`：按参数或 stdin 生成上述任务包。
- `scripts/task-packet-template.md`：空模板，可复制后手填。

## 允许文件范围与并行 / File scope and parallelism

- 一个可写 worker 同一时间只负责彼此重叠的文件集合。
- 需要并行时，必须做到文件所有权互斥：worker A 与 worker B 的允许范围不能相交，
  并在任务包里互相说明"其他代理正在改动哪些文件，不要回退它们的改动"。
- 任务包必须显式列出禁止修改的目录（例如用户数据、密钥文件、生成物）。
- worker 只能修改任务包允许的文件；越界改动视为失败，主代理应要求恢复原状后重试。

## 验收标准 / Acceptance criteria

主代理在放行前必须自己确认：

- 验收标准逐条有对应证据（测试输出、命令结果、可复现步骤），而不是 worker 的口头结论。
- 聚焦测试真的运行过，且覆盖本次改动的主要风险点；"未运行"必须写明原因。
- diff 中不包含密钥、私有路径、无关格式化、被误删的用户改动。
- 无法验证的部分被明确标注为残留风险，而不是被静默忽略。

## 审查与回退 / Review and fallback

- 主代理先读 diff，再读测试摘要；两者不一致时以实际命令输出为准。
- 需要修改就回发给 worker，附上具体文件和期望行为，避免"再改改"这类模糊指令。
- 回退场景：
  - worker 反复无法通过同一测试且原因不明：停止该路线，向用户说明并重新设计任务包。
  - worker 越界修改或删除用户已有改动：立即停止，恢复被误改的内容，再重新界定范围。
  - 仅当 `codex-deepseek-worker` 或凭据不可用时，主代理才可以在**用户明确同意**后，
    以 OpenAI 模型身份直接实现，并在汇报中说明这是一次例外回退。

## 密钥与安全 / Secrets and safety

必须遵守：

- 绝不把 API key、token、cookie 写进任务包、prompt、日志、提交信息或仓库文件。
- 不在任务包里粘贴 `.env`、凭证文件或私有数据集的内容；只给名称和用途。
- 发现仓库里已有疑似密钥时，停止相关改动，提示用户轮换，而不是复制或传播该值。
- 不发起与任务无关的网络请求，不上传代码或数据到第三方服务。
- 任务包只写用户指定的仓库路径，不写机器私有路径。

## worker 不可用 / When the worker is unavailable

出现以下任一情况时，停止实现工作并向用户报告阻塞（不要假装完成）：

- `codex-deepseek-worker` 不在 `PATH` 中。
- 环境中 `DEEPSEEK_API_KEY` 为空或未加载。
- 用户所在登录态或通道不支持 `deepseek-flash`。

给用户的修复步骤（不要要求把密钥贴到聊天里）：

```bash
install -m 0755 scripts/codex-deepseek-worker ~/.local/bin/codex-deepseek-worker
mkdir -p "${HOME}/.config/codex"
# 在本地编辑器中创建该文件，写入一行：DEEPSEEK_API_KEY=<本地密钥值>
chmod 600 "${HOME}/.config/codex/deepseek.env"
codex-deepseek-worker --version
```

最后一步只用于确认启动器可用；若仍未生效，说明 `PATH` 或凭据文件路径需要用户确认。
本插件自身不保存密钥，也不要接受用户在聊天中粘贴的密钥。

## 校验 / Validation

改动本插件后运行：

```bash
scripts/validate-plugin.sh
```

它只做本地静态检查（manifest、技能文件、启动器可执行性、占位符与密钥模式、shell 语法、
Python JSON 解析），不发起任何网络请求。

English summary: define acceptance criteria first, hand one self-contained packet to
`codex-deepseek-worker`, keep one writer per file set, require focused tests before the worker
reports, review the diff yourself, and stop with setup instructions instead of guessing when the
worker or its credential is missing. Never put credentials in prompts, logs, or the repository.
