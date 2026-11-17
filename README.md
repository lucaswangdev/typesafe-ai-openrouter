# typesafe-ai-openrouter

TypeSafe **Jev**（System One / 判断模型）技能的 **OpenRouter 移植版**。

上游是 TypeSafe 官方 skill [`typesafe-ai/skills`](https://github.com/typesafe-ai/skills/blob/main/skills/typesafe-ai/SKILL.md)（MIT）。
本仓库把它接到 OpenRouter 的 decisions 端点上：**只改了请求路径、Key 获取方式和模型名**，其余设计指南
（真值表、state 设计、问题与 criteria 写法、bundle 提问、阈值、yellow flags、cookbooks）保持上游原文。

> ⚠️ **本仓库不包含任何 API Key。** Key 通过环境变量 `OPENROUTER_API_KEY` 提供，见下方
> [配置 API Key](#配置-api-key必读)。

---

## 目录

- [这个 skill 做什么](#这个-skill-做什么)
- [安装](#安装)
- [配置 API Key（必读）](#配置-api-key必读)
- [快速验证](#快速验证)
- [与 TypeSafe 直连的差异](#与-typesafe-直连的差异)
- [已实测的硬约束](#已实测的硬约束)
- [相对上游改了什么](#相对上游改了什么)
- [License 与归属](#license-与归属)

---

## 这个 skill 做什么

Jev 不做自由对话。你给它**事实（state）** 和**结构化问题（questions）**，它对每个问题返回一个**带概率的
结构化答案**，供代码直接使用：

| 类型 | 用途 | criteria 形态 |
|---|---|---|
| `noul` | 单一是否判定（审核、风险、闸门） | `{"true": "...", "false": "..."}` |
| `choice` | 从互斥选项里选一个（路由、分派、工具选择） | `{"选项": "说明", ...}` |
| `score` | 分级/打分（优先级、相关性、质量） | `["档位0", "档位1", ...]` |
| `box` | 图像区域定位 | `{"标签": "说明", ...}` |

典型用途：意图路由、工具调用 / 权限审批闸门、工单分类分派、RAG 片段重排、回答质量打分、内容审核。
单次调用约 0.2 秒、$1e-05 ~ $5e-05。

## 安装

### 方式 A：装进 Coding Agent 的 skill 目录（Claude Code / Codex / Cursor 等）

```bash
git clone https://github.com/lucaswangdev/typesafe-ai-openrouter.git
mkdir -p ~/.agents/skills/typesafe-ai-openrouter
cp typesafe-ai-openrouter/SKILL.md typesafe-ai-openrouter/LICENSE ~/.agents/skills/typesafe-ai-openrouter/
```

之后 agent 会在「调用 Jev / 设计 state 与问题 / 用类型化判断替代 prompt-and-parse」这类任务上自动加载它。

### 方式 B：上游官方版（直连 TypeSafe，不是 OpenRouter）

```bash
npx skills add typesafe-ai/skills --skill typesafe-ai
```

如果你想像上游那样用 `TYPESAFE_API_KEY` 直连 `api.typesafe.ai`，用这条；想走 OpenRouter，用方式 A。

## 配置 API Key（必读）

Jev 在 OpenRouter 上需要一个 OpenRouter API Key：

1. 到 <https://openrouter.ai/keys> 创建 Key（`sk-or-v1-...`）。上游 TypeSafe 的 `TYPESAFE_API_KEY` 在
   这条路径上**不适用**。
2. 设置环境变量（临时，当前 shell 有效）：

   ```bash
   export OPENROUTER_API_KEY="sk-or-v1-你的key"
   ```

3. 持久化（新开终端仍有效）—— 写进 `~/.zshrc` 或 `~/.bashrc`：

   ```bash
   echo 'export OPENROUTER_API_KEY="sk-or-v1-你的key"' >> ~/.zshrc
   source ~/.zshrc
   ```

   Windows PowerShell 可写进用户环境变量：

   ```powershell
   setx OPENROUTER_API_KEY "sk-or-v1-你的key"
   ```

4. 确认已生效（只看前 8 位，避免泄露完整 Key）：

   ```bash
   echo "${OPENROUTER_API_KEY:0:8}..."
   ```

### 安全约定

- **本仓库不含任何 Key**，也不应包含：`.env`、`*.key`、硬编码字符串都已列入 `.gitignore`。
- 提交前自查：`git grep -nE "sk-or-v1-|ghp_|Bearer [A-Za-z0-9]{20,}"` 应无命中。
- 在任何 Coding Agent 里使用时，Key 只放服务端 / 本机环境变量，不要写进代码、提示词或前端。
- CI 用仓库 Secrets（`${{ secrets.OPENROUTER_API_KEY }}`），不要明文。
- 一旦 Key 泄露立刻在 <https://openrouter.ai/keys> 吊销并重建。

## 快速验证

```bash
export OPENROUTER_API_KEY="sk-or-v1-你的key"

curl https://openrouter.ai/api/alpha/decisions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "typesafe/jev-1.14",
    "state": {"message": "You charged me twice, refund the extra one."},
    "questions": {
      "is_refund_request": {
        "type": "noul",
        "instructions": "Is the sender requesting a refund?",
        "criteria": {"true": "Asks for money back.", "false": "Asks something else."}
      }
    }
  }'
```

预期返回（实测）：

```json
{"model":"typesafe/jev-1.14-20261014",
 "answers":{"is_refund_request":{"type":"noul","noul":0.99}},
 "usage":{"input_tokens":316,"output_tokens":23,"cost":0.000013272},"provider":"TypeSafe"}
```

## 与 TypeSafe 直连的差异

| | 本仓库（OpenRouter） | TypeSafe 直连 |
|---|---|---|
| 端点 | `POST https://openrouter.ai/api/alpha/decisions` | `POST https://api.typesafe.ai/v1/systemone` |
| 模型 | `typesafe/jev-1.14`、`typesafe/jev-1.14-20261014`、`~typesafe/jev-latest` | `jev-latest` 等，无前缀 |
| Key | `OPENROUTER_API_KEY` | `TYPESAFE_API_KEY` |
| SDK | 无，直接用 HTTP | 有 Python / JS SDK |
| 图片 | 直接支持 base64 data URL | 需 `TypeSafe-Danger-Zone-Images: true` 头 |

## 已实测的硬约束

- `POST /api/v1/chat/completions` 对 `typesafe/jev-*` 返回 400，只能用 decisions 端点。
- `typesafe/jev-latest`（无 `~`）不存在；`~typesafe/jev-latest` 才可用。
- 图片只接受 base64 data URL 的 PNG/JPEG；320×240、1×1 会报 `Invalid image dimensions.`，
  640×480 / 512×512 / 800×600 可用。
- `noul` 缺少 `criteria` **不报错**，会静默返回低置信度（约 0.3）—— 一定要写全。
- `score` 可能是小数（实测 1.99、1.54）：先 round，再用 `legend` 反查档位。
- `choice` 的 `confidence` 可能低于 top 概率（实测 top 0.83 / confidence 0.74）——
  按概率而不是 confidence 做闸门。
- 文本多标签判定不要用 `box`（实测坐标无语义、confidence ≈ 0.02），改用多个 `noul` 或一个 `choice`。

## 相对上游改了什么

`SKILL.md` 与上游原文的差异只有 6 处（其余逐字保留）：

1. `name`: `typesafe-ai` → `typesafe-ai-openrouter`
2. `description`: 追加一句 OpenRouter 端点 / Key / 模型名说明
3. Live docs 的 schema & SDK 条目：改为 OpenRouter 的 Jev 文档，并注明 SDK 与 `TypeSafe-Danger-Zone-*` 头不适用
4. 新增 `## Calling it`：可直接复制的 curl 与端点约束
5. `TYPESAFE_API_KEY` → `OPENROUTER_API_KEY`
6. 「network access to the API endpoint」→ 明确为 `openrouter.ai`

上游原始文件保存在 `SKILL.md.orig`，可直接核对：`diff -u SKILL.md.orig SKILL.md`。

## License 与归属

- 上游 skill：[`typesafe-ai/skills`](https://github.com/typesafe-ai/skills)（MIT），`LICENSE` 原样保留。
- 设计指南版权归 TypeSafe 团队；本仓库仅做 OpenRouter 接线与实测约束补充。
- 官方文档（问题语义与套路）：<https://docs.typesafe.ai/llms.txt>；
  OpenRouter 侧：<https://openrouter.ai/docs/guides/community/jev>。
