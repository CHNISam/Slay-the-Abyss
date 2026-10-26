# 许可证与版权审计

日期：2026-10-26。对象：CHNISam/Slay-the-Abyss，远端 develop **4c75a31fafcd27c204b957cd7dbc75ac6d9f5ab0**（初查 b78fb068，交付前已快进并复核新增源码/配置，素材和锁文件未变化）。这是源码与证据审计，不是权利人出具的许可或商用法律清关意见。用户明确要求禁止第三方商用，并计划自行商用。

## 结论

**整仓不能视为 MIT，也不能宣称已取得全部商用版权。** 基线没有根 LICENSE、README 或 package.json 的 license 字段；已有第三方 MIT/GPL 文本只覆盖对应组件。拟将可授权的项目原创代码以标准 **PolyForm-Noncommercial-1.0.0** 提供，另保留第三方许可、游戏 IP 和未明来源边界。禁止商业使用的代码授权应称为“源码可见/非商用”，不称 OSI 开源。

此选择比 MIT/Apache/GPL 更符合用户的原创代码授权意图，因为后三者都允许商业使用；CC BY-NC 主要面向内容，未选作程序代码许可；本轮不另写一份复杂的自定义软件许可证。PolyForm 的原文另允许列明的个人及慈善、教育、政府等机构用途，不能把摘要写成超出原文的绝对禁止。保留项目权利人对自有代码另行授权的权利，不等于他们拥有第三方代码/IP 的商业权利。[标准条款](https://polyformproject.org/licenses/noncommercial/1.0.0)、[OSI 定义第6条](https://opensource.org/osd)、[实际范围](../../LICENSE-SCOPE.md)。

## 覆盖方法及可追溯范围

核对 Git 跟踪树、所有现有 LICENSE/版权/来源记录、锁文件、脚本导入和下载路径、Lua 头注释、生成器配方、媒体扩展名、字体外链、音频/模型资源 ID、来源目录和 Git 作者历史；抽查上游固定 ref 的源码头和许可。不是只查 npm 或只看根目录。

- 基线共 **2,387 个 Git 跟踪文件**，完整路径及 blob 身份可由 `git ls-tree -r 4c75a31f` 重现。本地忽略的 node_modules、tools/vendor、build、副本及其他工作树不是公众仓库内容，不能据本次审计宣称它们已清关。
- 644 Lua、202 MJS、28 Python、2 Java、3 PowerShell、2 HTML；573 Markdown、385 JSON，以及日志、补丁、压缩证据等。Lua 数量包含测试、导出和证据，不等于全为原创运行时代码。
- 210 PNG、104 JPG、1 SVG、14 GIA；没有发现 Git 跟踪的独立音频、字体二进制或 3D 模型文件。资源引用仍纳入审计，不以“无二进制”消除 IP 义务。
- [逐文件素材/导出运行时清单](assets.json)记录 **436 个**敏感文件及 SHA-256：69 项项目几何稿/输出、19 项 GPL 编辑器混合运行时、51 项用户 AI 游戏 IP 输入及派生物、7 项 MIT Primitive 运行时、282 项截图/平台证据、8 项角色几何实验。分类是来源和复核状态，不是新的许可授予；同一文件可能同时具有工具代码与内容两类权利。
- [依赖与许可文本基线](dependencies.json)记录 11 个 npm 包、版本与声明许可，以及既有版权文本、Python 固定环境和外部 Luacheck 下载配置的指纹。npm SBOM 直接使用锁文件，不下载依赖；无法由锁元数据证明的版权原文明确保留未知。

## 全仓分类与来源证据

| 范围 | 判断及依据 | 授权处理 |
|---|---|---|
| 原创 UI/平台胶水、构建和验证工具、原创测试部分 | Git 历史显示本项目编制；scripts、tests、src/lua 中的平台适配及原生控件部分。没有独立证据证明所有提交者已转让权利，也未对每行做相似性法证。 | 仅许可有权授权的原创贡献；保留署名及第三方边界，不把整个目录打成“已证明原创”。 |
| 游戏规则实现与运行数据 | data/SOURCES.md、docs/RULE_PARITY.md、docs/evidence/warrior75/sources.json、docs/rules/evidence、tools/oracles、tests/fixtures 指向 aeubanks/sts@319009d5 的社区反编译镜像。核心实现、Java 片段、方法行号和派生目录均有此关联。 | **未明**。机械规则、数字、表达性代码和文本需分别判断；参考过源码不等于全部必然侵权，也绝不等于已 clean-room 或有权再许可。 |
| RNG 算法移植/解释 | src/lua/abyss_randomxs128.lua 明列 libGDX@3b1fda1、Apache-2.0、作者；固定上游 RandomXS128.java 头部已读回一致。其他 Python/Java 模型及 fixture 保留来源注记。 | 补 Apache 全文和集中作者说明；保守保留来源义务。并非认证所有模型不含其他游戏源码。 |
| 工具生成的程序代码 | docs/art/CARD_SHARED_ASSETS.md、CARD_EDITOR_SPIKE.md、AI_ART_SAMPLES.md 明确承认 Image Editor 输出含 GPL 适配运行时和 MIT Primitive 代码。固定编辑器 ref 103025f 的 GPL 原文已读回。 | GPL/MIT 继续有效；输出不能默认项目原创或套非商用。实际组合授权及 Corresponding Source 未完成核验。 |
| 画像实验的 MIT 运行时 | docs/experiments/art-portrait/README.md 与两份 LICENSE、固定工具 ref 和二进制身份相互对应。 | 保留 MIT 与两位版权人，不扩大到角色 IP。 |
| 用户提供 AI 图、剧情包和其他资料 | art/source 两张输入及哈希、art/processed/ai-samples、docs/lore/source 与其 README。用户交付证明取得路径，不证明游戏 IP 和生成服务商业权利。 | 未见服务/模型、账号条款、生成记录与第三方商业许可链，保持未明。 |
| 原生模型、UI 图库和音频 ID | docs/art/scene-spike/asset-selection.json、docs/art/production-scene-3d.md、scripts/native-bgm-graph.mjs、scripts/sfx-audition-source.mjs、docs/SFX_SELECTION.md。 | 平台原生内容独立受权利人和平台条款约束；不得赋予 GitHub 使用者通用的素材下载/商用权。 |
| 字体 | 原型加载 Noto Sans SC、JetBrains Mono，补 OFL 原文和版权；原型系统回退及预览脚本使用 YaHei。 | OFL 字体保持 OFL；当前未打包字体文件。YaHei 不另授再分发权，外链字体的实际版本未固定。 |
| 截图、设计原型、压缩日志、patch 与源码证据 | docs/design/screens、docs/evidence、docs/reviews、docs/drafts 等含平台画面、反编译摘录和代码补丁。原型也有游戏卡名/文本。 | 不按代码许可整体开放。保留历史证据，不将其视为可自由复用素材或复制代码授权。压缩/截图中的所有表达未逐字作法律判断。 |
| npm、Python、Actions 及本机工具 | package-lock.json、art/spikes/card-editor/requirements.lock.txt、.github/workflows、config/lua-tools.json、docs/TOOLCHAIN.md；.codebuddy/.cursor 是项目协作配置，不代表工具本体随仓。 | npm 的11项 MIT/BSD 声明明确；Python 精确包、Luacheck 二进制附带组件及 MCP 安装版本未完全核验。工具许可不能自动替代输出/IP 许可。 |
| 管理文档与配置 | backlog、schemas、config、AGENTS/CLAUDE 等；可能含资料摘录和示例。 | 原创文字也不默认纳入程序代码许可；第三方引用保持原边界。 |

## 尚未解决的风险与下一步

| 编号/级别 | 风险 | 商用或进一步分发前需要的证据/动作 |
|---|---|---|
| R1 高 | GPL 编辑器运行时已在公开导出物内，与禁止第三方商用的组合作品政策可能冲突；附许可文件不能证明履行全部 GPL 分发义务。 | 逐份确认导出代码的覆盖范围、Corresponding Source/修改/构建材料及组合方式；取得权利人允许当前分发与商业政策的单独许可，或使用权利清楚的替代实现。本次仅隔离声明，未解决既有分发问题。 |
| R2 高 | 大量游戏代码/数据以反编译镜像为来源；没有 Mega Crit 对镜像及本项目移植/商业发行的明确授权证据。 | 将功能事实与表达性片段逐项分开审查；必要时取得书面许可或采用有记录的独立实现并移除未经许可的表达。不能凭“GitHub公开”“改成Lua”“准确复刻”清关。 |
| R3 高 | 原神角色、截图、平台素材和音频，含用户 AI 图及几何化角色，未见覆盖仓库公开分发及实际商业模式的完整许可。 | 固定适用地区/版本的官方平台、创作者收益、同人及赛事条款，核对具体用途；补 AI 服务/模型生成与商业使用证据。已有游戏收益功能/投稿资格不是平台外 IP 授权。 |
| R4 中 | Git 历史有 Furinya、HongSen Pan、潘洪森等署名，但身份关系、雇佣/委托权利及商业授权未查证；无统一 CLA 记录。 | 项目方确认实际权利人与贡献许可；商业授权须覆盖所有相关原创贡献，不能由本 PR 代签。 |
| R5 中 | Python 21包快照、实际 CI Pillow、Luacheck 打包依赖、其他本机转换/构建工具的精确发行许可不完整。 | 发行前按实际使用版本留存发行包 license/notice 和随附组件清单；工具仅本地使用与向玩家分发的义务分别确认。 |
| R6 中 | 黑盒地图输出、OpenJDK 参考模型、字体外链及多来源资料的再分发边界未完全认证。 | 对照实际复制部分和取得条款；补固定版本/来源材料，必要时替换。不要给不明文件补一个想当然的 SPDX 标签。 |

本次没有删除历史文件、修改游戏行为、重建候选或宣称完成内容清关；未发消息向第三方索取授权。源码公开仓库本身已有分发风险，不只在未来收费时才需处理 R1/R2/R3。

## 轻量检查与维护

`node scripts/check-license.mjs` 使用 npm 原生 `sbom --sbom-format=cyclonedx --package-lock-only --offline --ignore-scripts`；没有新增 npm/Python 依赖，没有 npm ci、联网扫描、客户端或全量游戏回归。新增独立 `.github/workflows/licenses.yml`，只读权限、托管 Ubuntu、2分钟上限，复用现有固定 SHA 的 checkout/setup-node，运行3项聚焦回归和清单检查。原有 Quality/package.json 不动。

依赖集合、版本或许可变化需重新审查；素材、字体、音频、GIA/GIL/模型、art 中生成 Lua/JSON 的增加、修改和删除均核对来源清单。许可原文、Python 锁和 Luacheck 配置的变化也需复核。Lua/JSON/SVG 文本哈希规范 CRLF→LF，二进制素材保留原字节。更新方式是先审阅相应第三方条款及来源记录，再手动更新 assets.json/dependencies.json；没有“一键全部批准”。删除清单项也应与文件删除一起审阅。

**门禁通过不是商业放行。** 它接受已明确记录的 unknown/GPL 风险作为当前基线，不会识别所有新抄入的代码或新增隐藏在任意文本/压缩包里的素材。新增第三方代码、来源方法或外部工具仍须人工更新声明；依赖元数据不保证实际发行包许可准确。没有声称完成了自动版权鉴定或全网相似性检测。

## 分支与交付纪律

GitHub 仓库 API 已核对：仓库公开，**default_branch=develop**；master 只包含早期管理骨架，不是当前游戏授权入口。当前审计分支 feat/license-audit 从该 develop SHA 隔离；root/develop 较旧且有其他在途改动，未覆盖。最初本地 origin/HEAD 指 master 是过期远端符号引用，不能当成 GitHub 默认分支事实。PR 合入 develop 后公众默认页面才会出现新声明；本轮不直接提交 master，也不声称提交 PR 等于已经公开生效。

远端任务迁移 status=paused、externalUnknown=true，另有 TASK-66/68 活动执行权；package.json、Quality 工作流由其他会话持有。用户在本对话**明确授权本次限定范围门禁例外**：仅此独立分支的许可证、声明、审计和独立检查及 PR；不改任务门禁、游戏代码和共享文件，不借用任何其他会话的 receipt。原规则保持，任何现有 ownership 检查失败须如实报告，不能伪造通过或扩大为合并授权。

Backlog 跟踪使用同步最新 develop 后创建的 TASK-69；旧树自动误分配的本地记录不提交、不冒用其他在途任务身份。

## 验证记录

本轮 `node --test scripts/check-license.test.mjs`：3/3 通过（新增/缺失/冲突许可、素材新增/修改/删除、Lua/字体/平台产物及换行边界，含npm10/11输出）。`node scripts/check-license.mjs` 明确输出清单未漂移；独立复跑进程约1秒量级（首次包含磁盘恢复后开销约14秒），不把本地时长当远端CI承诺。`node --check` 通过。保留上游 OFL 原文两处行末空格；本目录 licenses/.gitattributes 只对上游文本关闭行末空格告警，完整差异的 `git diff --check` 仍需通过。未在本地运行游戏全量回归，未修改游戏逻辑；远端CI状态在PR报告，不将未运行或ownership例外视为成功。
