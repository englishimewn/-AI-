# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的结构，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [0.1.3] - 2026-09-19

### 变更

- `README.md` 改为模型无关定位：把契约写在角色（规划/架构/验收/审查与实现/测试修复）
  而不是模型名上，明确模型可替换而职责、任务包格式与验收流程不变。
- `README.md` 新增“定位：模型无关”“当前能力”“未来扩展方向”三节：
  - 当前能力逐条列出本版本已实现的部分（角色分工契约、实现 worker、任务包、单写者约束、
    审查回路、密钥边界、本地校验、打包与 CI）。
  - 未来扩展方向涵盖可选模型/provider、角色配置、路由策略、评测与成本记录，并逐行标注
    “当前”状态，说明尚无自动模型路由、多 provider 调度与用量记录。
  - 明确当前版本仍使用 OpenAI/GPT 系主代理与 DeepSeek V4.1 Flash worker，且这是本版本
    唯一支持的组合。
- `README.md` 正文与英文小节移除对具体版本号（GPT-6）的绑定，改为描述“OpenAI/GPT 系主代理”
  与“DeepSeek V4.1 Flash worker”这一当前实现事实。
- `.codex-plugin/plugin.json` 的 `description`、`interface.shortDescription` 与
  `interface.longDescription` 改为模型无关表述，并说明当前版本的实际模型组合与尚未实现的
  路由/评测能力；`repository` 与 `homepage` 保持指向 canonical 仓库不变。
- `interface.defaultPrompt` 中“交给 DeepSeek worker”改为“交给实现 worker”，避免默认提示词
  绑定具体模型。
- `plugin.json` 版本号提升到 `0.1.3`。

### 说明

- 本次只改动文档与清单，`scripts/`、`skills/`、CI 工作流、许可证与安全策略未变。
- 当前实现事实保持准确：主代理负责需求/架构/验收/审查，DeepSeek V4.1 Flash worker 负责实现。
- 仓库、README 与变更记录中都不含密钥、token 或机器私有路径。

## [0.1.2] - 2026-09-19

### 新增

- 在 `.codex-plugin/plugin.json` 中补充 `repository` 与 `homepage`，两者都指向 canonical
  仓库 `https://github.com/englishimewn/-AI-`；字段属于官方 plugin schema 允许的键，
  并且是绝对 `https://` 地址。
- `README.md` 顶部加入 canonical 仓库地址、CI `validate` 徽章与“快速入口”表格，
  把安装、验证、打包/发布与变更记录的入口集中到一处。
- `README.md` 新增“仓库发布说明”：记录推送 remote、改名/迁移时的同步点，以及
  release 归档附件的上传入口。

### 变更

- `README.md` 明确分工表述为“OpenAI 主代理负责需求、架构、验收标准与最终审查，
  DeepSeek V4.1 Flash worker 负责实现与测试修复”，中英文两节保持一致。
- `README.md` 开源发布与版本发布章节改用真实仓库地址与 `v0.1.2` tag 示例，
  移除了原先需要读者自行替换的 remote 地址与徽章 owner 占位串。
- `plugin.json` 版本号提升到 `0.1.2`，与本次仓库公开发布准备保持一致。

### 说明

- 本次发布准备只改动文档与清单，`scripts/`、`skills/`、CI 工作流、许可证与安全策略未变。
- 仓库、README 与变更记录中都不含密钥、token 或机器私有路径。

## [0.1.1] - 2026-09-19

### 新增

- `.github/workflows/validate.yml`：push / pull_request / 手动触发时在 `ubuntu-latest` 上运行
  Codex 官方 plugin validator、skill `quick_validate`、`bash -n` 与 `scripts/validate-plugin.sh`；
  只读权限，不引用 secret，不调用 DeepSeek worker。
- `CONTRIBUTING.md`：贡献流程、任务包与审查原则、提交前验证命令、文档与安全约定。
- `SECURITY.md`：漏洞报告渠道、密钥处理规则、禁止提交凭据与泄露后的处置顺序。
- `scripts/package-plugin.sh`：校验通过后本地打包 `tar.gz`，可选输出路径，排除
  `.git`/`.codex`/`.agents`/缓存/日志/`dist`，并拒绝覆盖任何已存在的输出文件。
- `scripts/run-official-validators.sh`：用 Codex 系统技能里的官方 `validate_plugin.py` 与
  `quick_validate.py` 校验本插件，找不到官方脚本时给出准备步骤。

### 变更

- `scripts/validate-plugin.sh`：新增 `.github/workflows/*.yml` 基本结构检查（非空、含顶层
  `on:`/`jobs:`、无制表符）与密钥/占位符扫描范围扩展，仍然不依赖 `yq`。
- `README.md`：把 marketplace 说明改为清晰的"个人本地"与"仓库/团队"两条安装路线，
  补充 CI、打包、GitHub 开源发布与版本发布步骤，并明确不要向聊天粘贴密钥。
- `plugin.json` 版本号提升到 `0.1.1`；`repository`/`homepage` 保持省略（无可填地址时不填，
  以维持 schema 合法）。

### 说明

- 官方校验脚本来自 Codex CLI 的系统技能目录，仓库不复制第三方脚本。
- 打包与校验脚本都不发起网络请求，也不读取 `DEEPSEEK_API_KEY`。

## [0.1.0] - 2026-09-19

### 新增

- 插件清单 `.codex-plugin/plugin.json`：名称 `dual-model-coding`，说明双模型职责与安全边界。
- 技能 `skills/dual-model-coding/SKILL.md`：触发条件、主代理与 worker 职责、任务包模板、
  允许文件范围、验收标准、审查与回退、密钥安全规则，以及 worker 不可用时的停止条件与配置命令。
- 启动器 `scripts/codex-deepseek-worker`：加载 `~/.config/codex/deepseek.env`，
  只检查 `DEEPSEEK_API_KEY` 是否非空，以固定 provider/model 启动 `codex exec`，
  支持 `--version` 与 `--help`，失败提示不泄露密钥。
- `scripts/create-task-packet.sh` 与 `scripts/task-packet-template.md`：生成自包含任务包。
- `scripts/validate-plugin.sh`：本地静态校验（manifest、技能文件、启动器、占位符与密钥模式、
  shell 语法、Python JSON 解析），退出码清晰，不发网络请求。
- `README.md`、`LICENSE`（MIT）、`.gitignore`（忽略密钥、缓存与日志）。

### 说明

- 本插件不保存密钥、不自动上传代码、不写入 marketplace 配置。
- 一个可写 worker 同一时间只负责互不重叠的文件集合。
