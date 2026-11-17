# typesafe-ai-openrouter 测试报告

| 项目 | 值 |
|---|---|
| 测试时间 | 2026-11-17 |
| 被测文件 | `/root/.agents/skills/typesafe-ai-openrouter/SKILL.md`（已安装目录） |
| 来源 | `npx skills add typesafe-ai/skills --skill typesafe-ai` 下载的原文（MIT） |
| 端点 | `POST https://openrouter.ai/api/alpha/decisions` |
| 凭据 | `OPENROUTER_API_KEY` |
| 结果 | **8 / 8 通过** |

## 用例

| # | 用例 | 依据 | 结果 |
|---|---|---|---|
| T1 | 下载官方 skill | `npx skills add` | 安装到 `./.agents/skills/typesafe-ai`（SKILL.md + LICENSE，Security 评估 Safe / Low Risk） ✅ |
| T2 | 移植后 diff 复核 | 只应有 6 处改动 | `diff SKILL.md.orig SKILL.md` = 6 处（name、description、Live docs schema 条目、新增 Calling it、Key、network） ✅ |
| T3 | **原样执行文档里的 curl** | 「Calling it」片段直接从 SKILL.md 抽出执行 | `model=typesafe/jev-1.14-20261014`，`is_refund_request.noul=0.99`，cost $0.0000133 ✅ |
| T4 | 固定快照 `typesafe/jev-1.14-20261014` | 文档称快照可钉版本 | 200，`noul=0.98` ✅ |
| T5 | 别名 `~typesafe/jev-latest` | 文档称必须带 `~` | 200，解析到 `jev-1.14-20261014` ✅ |
| T6 | 端点隔离 | 文档称 chat/completions 对 jev 返回 400 | HTTP 400 `is a decisions model and cannot be used with the chat/completions endpoint` ✅ |
| T7 | 一次请求 3 问（bundle 原则） | 文档的 Compose requests | `noul=0.96` / `choice=payments`(0.74, conf 0.61) / `score=2`，cost $0.0000183 ✅ |
| T8 | 图片数组 state（base64 PNG 640×480，无 danger-zone 头） | 文档称此路径不需要额外头 | 200，`has_red.noul=0.99`，cost $0.0000489 ✅ |
| T9 | 过小图片 | 文档称会报 `Invalid image dimensions.` | HTTP 400 同名报错 ✅ |
| T10 | 文档内 26 个外链 | 不能留死链 | 全部 200（`api/alpha/decisions` 与一处带反引号的匹配是 GET 探测的假阳性） ✅ |
| T11 | 安装与打包 | `quick_validate.py` + 冷启动加载 | `Skill is valid!`；打包 9 KB（SKILL.md + LICENSE）；本会话 skill 目录已收录 `typesafe-ai-openrouter` ✅ |

## 与上游的一处实际差异（已写进文档）

测试中取到 `choice` 的 `confidence=0.61` 而 top 概率 0.74 —— 上游「Confidence is rarely the gate」的判断
在 OpenRouter 路径上同样成立，因此「Calling it」里明确用概率/阈值而不是 confidence 做闸门。

## 结论

只改请求路径 + Key（外加必需的模型名与之配套的 20 行说明）即可跑通：官方 skill 的设计指南原样保留，
所有可验证的声明都在这条端点上实测通过。上游文档里 `api.typesafe.ai`、Python/JS SDK、
`TypeSafe-Danger-Zone-*` 头不适用于此路径，已在 Live docs 与 Calling it 中标注。

## 追加验证：Key 解析与失败语义（同日）

起因：非交互式 shell 里 `$OPENROUTER_API_KEY` 为空导致 401。rc 文件（`~/.zshrc` / `~/.bashrc`）
只在对应 shell 的交互式会话中执行，agent 的 `bash -c`、PM2 fork 出的子进程都不会读它们。

| # | 用例 | 期望 | 实测 |
|---|---|---|---|
| T12 | 取消环境变量，仅靠 `~/.config/openrouter/key` | 正常返回答案 | 200，`noul` 结构正常，cost $3.46e-05 ✅ |
| T13 | 环境变量与 key 文件都不存在 | 明确报错、退出码 2 | `error: no API key. Either export OPENROUTER_API_KEY=... or write it to ~/.config/openrouter/key`，exit 2 ✅ |
| T14 | 环境变量优先于文件（故意给错 key） | 非 0 退出，且不把失败当答案 | `{"error":{"message":"User not found.","code":401}}` 同时 **exit 22** ✅ |
| T15 | key 文件权限 | 目录 700、文件 600 | `drwx------` / `-rw-------` ✅ |

T14 一开始失败过一次：`curl` 不带 `--fail-with-body` 时 HTTP 4xx 仍返回 0，等于把失败当成功。已修正，
脚本现在对 HTTP ≥ 400 以非 0 退出并打印响应体，符合 skill 的「失败必须是错误，不能当成某个答案」。
