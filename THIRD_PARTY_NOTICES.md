# 第三方代码与内容声明

本声明是来源及义务记录，不是第三方权利人的新增授权。项目非商用政策不能限制第三方 MIT/Apache/GPL 本来允许的商业使用。源码片段、生成运行时、内容和工具分别核查；LICENSE 文件存在不代表整套游戏已合规。

## 已有明确开放许可的代码

| 来源及固定身份 | 仓库涉及内容 | 许可、版权与证据 |
|---|---|---|
| [Miliastra-toolbox-primitive-shape](https://github.com/1475505/Miliastra-toolbox-primitive-shape/tree/0526509e73d36b359d3c9bee1104718e4a600ed0) | docs/experiments/art-portrait/portrait-64.lua、portrait-256.lua 及其他 primitive.lua 的生成运行时 | MIT，Copyright (c) 2026 LiuL；[原文](docs/experiments/art-portrait/LICENSE-Shaper.txt)。[实验来源](docs/experiments/art-portrait/README.md)记录导出路径与修改；转换器许可不授权角色 IP。 |
| [primitive](https://github.com/fogleman/primitive) | 上述离线拟合工具链；工具二进制不在 Git 中 | MIT，Copyright (C) 2016 Michael Fogleman；[原文](docs/experiments/art-portrait/LICENSE-primitive.txt)。 |
| [Miliastra-image-editor-webui](https://github.com/1475505/Miliastra-image-editor-webui/tree/103025f9095d8089e3f9bf097f4d0c5fe039d546) | art/cards/shared/*.lua、art/processed/ai-samples 的 asset.lua/card.lua、art/spikes/card-editor 与 card-capacity 的 card.lua；GIA 及 JSON 也需判断是否嵌入代码 | 上游 GPL v3 文本；不推定“或后续版本”或特殊输出豁免。[保留原文](art/cards/shared/licenses/EDITOR-GPL-3.0.txt)、[明确承认嵌入运行时的记录](docs/art/CARD_SHARED_ASSETS.md)。Primitive 子运行时 MIT、LiuL，[原文](art/cards/shared/licenses/PRIMITIVE-SHAPE-MIT.txt)、[未跟踪上游文件及哈希](art/spikes/card-capacity/licenses/PRIMITIVE-SHAPE-PROVENANCE.md)。 |
| [libGDX RandomXS128.java](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/RandomXS128.java) | src/lua/abyss_randomxs128.lua；tools/oracles 和 tests/fixtures 的有关 RNG 模型/向量 | Apache-2.0，Copyright 2011 See AUTHORS file；作者 Inferno、davebaol。[许可原文](docs/legal/licenses/Apache-2.0.txt)。Lua 文件声明独立 limb arithmetic 实现，方法/语言均改变；这是来源说明，不是 clean-room 法律结论。未引入完整 libGDX 分发包，不能据此声称已核查包内一切 NOTICE。 |

GPL 风险：运行 GPL 工具不自动使所有输出成为 GPL，但这里已有文件及记录确认导出物包含上游程序代码。须核对输出代码的具体授权及完整 Corresponding Source、修改和构建材料，并判断组合方式。不能对受 GPL 覆盖的组合作品叠加非商用限制；不能以“仅实验”或“附上 LICENSE”替代合规。商用前应取得单独授权或以权利清楚的实现替换并重新核查。此 PR 不删除或重许可这些历史文件，也不宣称已修复分发风险。

## npm 锁定依赖

全部为开发依赖；正式游戏不因此携带 npm 本体。版本及 tarball 完整性以 package-lock.json 为准，[机器清单](docs/legal/dependencies.json)保留所有直接/间接包及声明许可。锁文件元数据是许可线索，不代替实际随包版权原文；重分发这些包时须保留随包 LICENSE/版权。没有给这些包追加非商用条件。

| 包 | 版本 | 声明许可 |
|---|---|---|
| ajv | 8.20.0 | MIT |
| fast-deep-equal | 3.1.3 | MIT |
| fast-uri | 3.1.9 | BSD-3-Clause |
| fengari | 0.1.5 | MIT |
| fengari-node-cli | 0.1.0 | MIT |
| json-schema-traverse | 1.0.0 | MIT |
| luaparse | 0.3.1 | MIT |
| readline-sync | 1.4.10 | MIT |
| require-from-string | 2.0.2 | MIT |
| sprintf-js | 1.1.3 | BSD-3-Clause |
| tmp | 0.2.7 | MIT |

本机 Fengari 许可明确列出 Benoit Giannangeli (2017–2019)、Daurnimator (2017–2025)、Lua.org/PUC-Rio (1994–2017)；CLI 列出 Benoit Giannangeli (2017)、Daurnimator (2018)、Lua.org/PUC-Rio (1994–2017)。其他包的版权人未由锁文件证明，不编造作者名单。SBOM 由 npm 官方工具离线生成，不抓取 registry。

## 字体、音画和平台内容

| 内容/来源 | 证据与状态 |
|---|---|
| Noto Sans SC | docs/design/prototype/index.html 外链 Google Fonts，未提交字体二进制。[OFL 1.1 和 Adobe 版权](docs/legal/licenses/NotoSansSC-OFL.txt)，[上游](https://github.com/google/fonts/blob/main/ofl/notosanssc/OFL.txt)。声明 Reserved Font Name “Source”；不能改成项目非商用许可。外链未固定字体文件版本。 |
| JetBrains Mono | 同一原型外链；[OFL 1.1 和 Copyright 2020 The JetBrains Mono Project Authors](docs/legal/licenses/JetBrainsMono-OFL.txt)，[上游](https://github.com/JetBrains/JetBrainsMono/blob/master/OFL.txt)。 |
| Microsoft YaHei / 系统字体 | 原型回退字体；scripts/art/prepare-card-capacity.py 从 Windows 加载 msyh.ttc 生成预览。未提交字体文件，不授予提取、嵌入或再分发字体软件的权利。需按实际操作系统字体授权核查。 |
| 荧立绘、星陨剑图及派生图元 | 用户提供 AI 图，原图哈希和路径见 [AI_ART_SAMPLES](docs/art/AI_ART_SAMPLES.md)。未见生成服务/模型条款、完整生成记录或游戏 IP 许可，**授权未明**。转换、重绘或几何拟合不自动消除 IP 风险。 |
| 平台图库、3D 模型、BGM、音效 | 现仓使用资源 ID 和图配置，见 docs/art/scene-spike/asset-selection.json、scripts/native-bgm-graph.mjs、docs/SFX_SELECTION.md。仅发现引用和截图，未发现已提交的独立音频/模型文件。平台内可用不等于可在 GitHub 或平台外独立授权、提取或商用。 |
| 实机截图、封面、设计截图、演示图 | docs/evidence、docs/reviews、docs/design/screens 等。作者拥有截图不等于拥有画面内角色/UI/美术；仅作项目证据保留，未给予通用素材许可。 |
| 游戏名、角色名、卡名、剧情和规则数据 | miHoYo/HoYoverse、Mega Crit 及其他相关权利人的内容按各自权利处理。本项目不代表官方；名称改写或数值准确不证明内容权利已清关。 |

## 未明来源及外部工具

- [aeubanks/sts 固定镜像](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)：data/SOURCES.md 明确作为反编译/社区源码依据；涉及卡牌、敌人、事件、结算、随机流等实现及大量证据片段。未找到 Mega Crit 授权该镜像再分发或衍生代码的证据；本次查询固定 ref 的 LICENSE 返回 404，但不把单一路径 404 当成完整的无许可证明。不得默认为 MIT、公共领域或已 clean-room。
- [sts_map_oracle](https://github.com/Ru5ty0ne/sts_map_oracle/tree/ea5200f21fa566de77ec14b6155b3bf3756dccbf)：tests/fixtures/sts1/maps/manifest.json 记录 v1.1.0 的黑盒输出、二进制哈希和“不是代码复用许可”边界。工具不随仓分发；输出和参考算法仍不自动成为项目原创资产，未证明其可商业再分发。
- [OpenJDK HashMap](https://github.com/openjdk/jdk8u/blob/jdk8u472-b08/jdk/src/share/classes/java/util/HashMap.java)：tools/oracles/sts1_card_pools.py 自述独立解释、未复制方法。OpenJDK 来源采用 GPL-2.0 with Classpath Exception，不能简单据此给 Python 模型标同许可，也不能把例外当作复制任意源码的授权；需单独对照核查，暂保留未明边界。
- Luacheck 1.2.0：config/lua-tools.json 固定发布资源和哈希，MIT 项目 [lunarmodules/luacheck](https://github.com/lunarmodules/luacheck/tree/v1.2.0)。下载到忽略的 build，未提交二进制；实际打包运行时/附带组件需另查，不用主项目 MIT 代表整个二进制包。
- Python 环境：art/spikes/card-editor/requirements.lock.txt 的 21 个固定包、CI 的 Pillow 12.3.0、实验环境的 Pillow/OpenCV/NumPy 等仅为工具环境；精确发行包许可及第三方附带库尚未全部核实。常见 MIT/BSD/Apache/Historical Permission Notice 不能替代对这些具体版本的检查。
- Node/npm、Python、Git、GitHub Actions、社区 MCP、官方客户端均为外部执行工具，非本项目代码。docs/TOOLCHAIN.md 关于 MCP 的 MIT 记载尚不构成对当前安装版本及所有输出的独立核验。用户提供的逆向资料包及剧情包也无统一第三方商业授权凭证。

要新增来源，记录具体 URL/ref、权利人、许可原文、取得方式、涉及文件及修改。未知内容须保持 unknown；需要授权或替换的项目见 [审计风险表](docs/legal/LICENSE_AUDIT.md)。
