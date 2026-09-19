# Contributing

感谢你改进 `dual-model-coding`。本仓库本身就是一个"主模型设计 + worker 实现"的实践样本：
贡献流程同样遵循任务包 → 实现 → 审查 → 验证的顺序。

## 环境准备

```bash
git clone <your-fork-url> dual-model-coding
cd dual-model-coding

# 本地自检需要 bash 与 python3
scripts/validate-plugin.sh
```

想同时运行 Codex 官方校验（`plugin-creator` 与 `skill-creator` 的脚本）时，需要
Python 3 与 PyYAML，并让系统技能目录存在：

```bash
npm install --global @openai/codex
codex app-server   # 首次启动会把官方系统技能写入 ${CODEX_HOME:-$HOME/.codex}/skills/.system
scripts/run-official-validators.sh
```

没有安装 Codex CLI 时，也可以克隆官方技能仓库并通过环境变量指向它：

```bash
git clone --depth 1 https://github.com/openai/skills.git /tmp/openai-skills
CODEX_SYSTEM_SKILLS_DIR=/tmp/openai-skills/skills/.system scripts/run-official-validators.sh
```

## 提交前必跑的验证

```bash
scripts/validate-plugin.sh            # 本地静态校验（不发网络请求）
scripts/run-official-validators.sh    # Codex 官方 plugin/skill 校验（需要系统技能）
for f in scripts/*; do head -n1 "$f" | grep -q '^#!' && bash -n "$f"; done
scripts/package-plugin.sh --out /tmp/dual-model-coding.tar.gz   # 打包冒烟
```

CI 会在 `ubuntu-latest` 上对 `push` 与 `pull_request` 运行同样的检查，
见 `.github/workflows/validate.yml`。CI 不读取任何 secret，也不会调用 DeepSeek worker。

## 贡献流程

1. 先开 issue 或讨论，说明要解决的问题与期望行为；小的文档修正可以直接提 PR。
2. 从 `main` 切分支，例如 `fix/validate-workflow` 或 `docs/readme-release`。
3. 按下面的原则拆分任务，聚焦最小可审查的改动。
4. 本地跑完"提交前必跑的验证"，把命令与结果写进 PR 描述。
5. PR 描述包含：动机、改动文件、验证命令与结果、残留风险。
6. 维护者审查 diff 与测试证据；不符合验收标准时给出具体、可执行的修正意见。

## 任务包与审查原则

如果你用本插件的双模型工作流来完成改动，任务包必须是自包含的（worker 看不到对话历史）：

- **目标**：一句话说明要实现的行为与动机。
- **允许文件范围**：显式列出可改的文件或 glob，以及禁止触碰的路径。
- **约束**：现有风格与依赖、不可改动的公共接口、禁止写入的敏感信息。
- **验收标准**：可观察、可验证的行为与边界条件。
- **聚焦验证**：确切要跑的命令，例如 `bash -n scripts/*.sh`。

审查原则：

- 只接受有证据的结论：diff + 命令输出，而不是"已完成"的自述。
- 一个可写 worker 同一时间只负责互不重叠的文件集合；并行时文件所有权必须互斥。
- 越界修改（改到允许范围之外、删除他人改动）视为失败，先恢复再重试。
- 验收标准逐条对照证据；无法验证的部分明确写成残留风险。

你可以用仓库内置的脚本生成任务包：

```bash
scripts/create-task-packet.sh --template
scripts/create-task-packet.sh --objective "..." --scope "..." --acceptance "..." --verification "..."
```

## 文档与版本约定

- 面向用户的行为变化写入 `CHANGELOG.md`，遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。
- 版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)；`plugin.json` 的 `version` 必须与
  `CHANGELOG.md` 的最新条目一致。
- `.codex-plugin/plugin.json` 只允许官方 schema 接受的字段；没有真实值的可选字段
  （如 `repository`、`homepage`）直接省略，不要写空字符串或未填的占位标记。

## 安全约定

- 不要在任何提交、日志、截图或 issue 里粘贴真实密钥；详见 [SECURITY.md](./SECURITY.md)。
- 贡献者不要在 issue、PR 或聊天中粘贴 `DEEPSEEK_API_KEY` 或其它凭据。
- 发现仓库中已有疑似泄露的凭据时，停止相关改动并私下报告，不要复制或传播该值。

## 许可证

提交即表示你同意以 [MIT](./LICENSE) 许可证发布你的贡献。
