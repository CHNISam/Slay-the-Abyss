# 第三方代码与内容声明

本项目原创代码采用非商用许可，项目权利人保留自有代码的商业使用和单独授权权利。以下第三方组件保留各自许可；平台内容用于原神官方支持的千星奇域创作场景，不由本仓库向外转授 IP。

## 已有明确开放许可的代码

| 来源及固定身份 | 仓库涉及内容 | 许可、版权与证据 |
|---|---|---|
| [Miliastra-toolbox-primitive-shape](https://github.com/1475505/Miliastra-toolbox-primitive-shape/tree/0526509e73d36b359d3c9bee1104718e4a600ed0) | docs/experiments/art-portrait/portrait-64.lua、portrait-256.lua 及其他 primitive.lua 的生成运行时 | MIT，Copyright (c) 2026 LiuL；[原文](docs/experiments/art-portrait/LICENSE-Shaper.txt)。[实验来源](docs/experiments/art-portrait/README.md)记录导出路径与修改；转换器许可不授权角色 IP。 |
| [primitive](https://github.com/fogleman/primitive) | 上述离线拟合工具链；工具二进制不在 Git 中 | MIT，Copyright (C) 2016 Michael Fogleman；[原文](docs/experiments/art-portrait/LICENSE-primitive.txt)。 |
| [Miliastra-image-editor-webui](https://github.com/1475505/Miliastra-image-editor-webui/tree/103025f9095d8089e3f9bf097f4d0c5fe039d546) | 16份包含文字框或蒙版适配模板的导出 Lua，精确路径见下方；其余输出不因使用该编辑器而自动适用 GPL | 上游 GPL v3 文本；不推定“或后续版本”或特殊输出豁免。[保留原文](art/cards/shared/licenses/EDITOR-GPL-3.0.txt)、[明确承认嵌入运行时的记录](docs/art/CARD_SHARED_ASSETS.md)。Primitive 子运行时 MIT、LiuL，[原文](art/cards/shared/licenses/PRIMITIVE-SHAPE-MIT.txt)、[未跟踪上游文件及哈希](art/spikes/card-capacity/licenses/PRIMITIVE-SHAPE-PROVENANCE.md)。 |
| [libGDX RandomXS128.java](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/RandomXS128.java) | src/lua/abyss_randomxs128.lua；tools/oracles 和 tests/fixtures 的有关 RNG 模型/向量 | Apache-2.0，Copyright 2011 See AUTHORS file；作者 Inferno、davebaol。[许可原文](docs/legal/licenses/Apache-2.0.txt)。Lua 文件声明独立 limb arithmetic 实现，方法/语言均改变；这是来源说明，不是 clean-room 法律结论。未引入完整 libGDX 分发包，不能据此声称已核查包内一切 NOTICE。 |

使用 GPL 工具不自动使输出或整个游戏成为 GPL。固定编辑器的 `backend/app/lua_scene.py` 分为两个输出路径：基础形状调用 MIT 的 `primitive_shape/gia_lua.py`；文字框/蒙版路径另外把 `_TEXTBOX_RUNTIME` 或 `lua_mask.py::RUNTIME` 写入输出。此次按具体输出内容分类，不按工具名称推断整仓许可。GNU 的[输出说明](https://www.gnu.org/licenses/gpl-faq.en.html#GPLOutput)也区分工具使用和输出中实际包含的程序代码。

包含上述适配模板的16份 Lua：`art/cards/shared/frame-{basic,common,rare,uncommon}.lua`（4份）；`art/processed/ai-samples/lumine/{B,B2}/asset.lua`（2份）；`art/processed/ai-samples/starfall/B/{asset,card}.lua`（2份）；`art/spikes/card-capacity/{reference,longest}/card.lua`（2份）；`art/spikes/card-editor/card.lua` 与 `text-height-compat/card.lua`（2份）；`art/cards/geo-samples/{heavy_blade,bloodletting,iron_wave,shockwave}/native-art.lua`（4份，实验审阅候选，仍含上游蒙版运行时）。需针对其中的具体模板代码核对适用许可和输出豁免；在此之前保留已有GPL/MIT文本，不向这些第三方部分追加本项目非商用限制。对当前生产产物的影响取决于实际是否装配这些实验文件及装配方式，不能由实验文件存在就认定整个游戏必须GPL开放。

纯图形输出的 `card-back.lua`、三个 `type-*.lua`、`lumine/A/asset.lua` 和 `starfall/A/asset.lua` 使用 MIT 基础运行时；`art/spikes/card-capacity/verify.lua` 是项目验证脚本，出现模板名不等于嵌入上游模板。原“19份全部混合运行时”的分类已纠正。

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
| 荧立绘、星陨剑图及派生图元 | 项目方提供的 AI 生成素材，原图哈希和路径见 [AI_ART_SAMPLES](docs/art/AI_ART_SAMPLES.md)，用于本平台项目。原神 IP 归原权利人，本仓库不转授这些形象的独立素材使用权；生成服务的具体条款记录与游戏IP应分别核查。 |
| 平台图库、3D 模型、BGM、音效 | 现仓使用资源 ID 和图配置，见 docs/art/scene-spike/asset-selection.json、scripts/native-bgm-graph.mjs、docs/SFX_SELECTION.md。仅发现引用和截图，未发现已提交的独立音频/模型文件。平台内创作及收益遵循适用官方条款；本仓库不另授平台外提取或独立素材使用权。 |
| 实机截图、封面、设计截图、演示图 | docs/evidence、docs/reviews、docs/design/screens 等。作者拥有截图不等于拥有画面内角色/UI/美术；仅作项目证据保留，未给予通用素材许可。 |
| 游戏名、角色名、卡名、剧情和规则数据 | miHoYo/HoYoverse、Mega Crit 及其他相关权利人的内容按各自权利处理。本项目不代表官方；名称改写或数值准确不证明内容权利已清关。 |

## 规则参考资料与外部工具

- 游戏规则参考资料：data/SOURCES.md 及现有行为证据记录了 [aeubanks/sts 固定 ref](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。参考规则、算法或测试行为不能单独证明复制了第三方受保护代码；本轮未建立逐段代码比对或侵权认定结论。原创实现适用本项目代码许可；如实际复制具体代码/文案，则单独按该部分来源处理，不把整个Lua核心归为第三方代码。
- [sts_map_oracle](https://github.com/Ru5ty0ne/sts_map_oracle/tree/ea5200f21fa566de77ec14b6155b3bf3756dccbf)：tests/fixtures/sts1/maps/manifest.json 记录 v1.1.0 的黑盒输出、二进制哈希和“不是代码复用许可”边界。工具不随仓分发，所记录的是黑盒测试输出；这些参考数据不等于复制了工具源代码。
- [OpenJDK HashMap](https://github.com/openjdk/jdk8u/blob/jdk8u472-b08/jdk/src/share/classes/java/util/HashMap.java)：tools/oracles/sts1_card_pools.py 自述独立解释、未复制方法。OpenJDK 来源采用 GPL-2.0 with Classpath Exception，不能仅凭参考该算法给 Python 模型标为 GPL；仅在实际采用第三方代码时核对对应许可。
- Luacheck 1.2.0：config/lua-tools.json 固定发布资源和哈希，MIT 项目 [lunarmodules/luacheck](https://github.com/lunarmodules/luacheck/tree/v1.2.0)。下载到忽略的 build，未提交二进制；实际打包运行时/附带组件需另查，不用主项目 MIT 代表整个二进制包。
- Python 环境：art/spikes/card-editor/requirements.lock.txt 的 21 个固定包、CI 的 Pillow 12.3.0、实验环境的 Pillow/OpenCV/NumPy 等仅为工具环境；精确发行包许可及第三方附带库尚未全部核实。常见 MIT/BSD/Apache/Historical Permission Notice 不能替代对这些具体版本的检查。
- Node/npm、Python、Git、GitHub Actions、社区 MCP、官方客户端均为外部执行工具，非本项目代码。docs/TOOLCHAIN.md 关于 MCP 的 MIT 记载尚不构成对当前安装版本及所有输出的独立核验。用户提供的资料包和剧情包保留各自取得记录，不把资料用途说明当作对具体代码复制的认定。

要新增来源，记录具体 URL/ref、权利人、许可原文、取得方式、涉及文件及修改。不能确认的具体条目继续记录待核实，不将记录缺失写成已经认定无权使用。范围与复核依据见 [审计记录](docs/legal/LICENSE_AUDIT.md)。
