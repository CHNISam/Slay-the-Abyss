# 旅行者·岩：源资产与当前评审状态

按稳定 `card_id` 保全三张现行卡图。整备武装原字节与认可保留；星陨剑及重剑斩为2026-10-27新身份修正版，用户认可仅覆盖两新样的源设计、原生重绘、整卡离线预览及岩旅行者身份。**旧重剑仍是身份被否决的设计反例，新认可不作用于旧源或旧原生hash。** 复用 TASK-25.2，不新增台账。

| card_id | 显示名 | 图片 | 蒙版 | 插画控件合计 | 源尺寸 |
|---|---|---:|---:|---:|---|
| `armaments` | 整备武装 | 1834 | 0 | 1834 | 1881×836 |
| `cleave` | 星陨剑 | 2657 | 0 | 2657 | 1881×836 |
| `heavy_blade` | 重剑斩 | 2043 | 0 | 2043 | 1882×836 |

每张含3个原生图库图片控件（106056/106057两种资源）。不含卡框、动态文字、宿主、输入、诊断或整屏其它控件，不能推导FPS或十卡容量。

## 文件契约

- `catalog.json`：`cards` 三个已认可ID及独立的 `candidates` 源候选映射到相对 `asset.json`，`runtime.status=unbound`。不向theme写入虚构图片ID；Cleave原有102012占位图标保持原样。
- `source.png`：实际imagegen输出原字节，非用户上传、非运行时外部PNG。
- `prompt.txt`：实际初始生成提示词。Heavy另有 `prompt-repair.txt`，是针对初稿的真实第二阶段刃缘接触修正；`generation.steps`按输入/输出SHA串接两步，不能只保留修正提示词冒充完整来源。中间源不重复入库。
- `native-art.json` / `.lua`：固定编辑器导出的144×64可编辑场景与真实绘图表。JSON不变；每份Lua仅移除多余的1个末尾LF，保留一个最终LF。`originalExport`记录可还原的原SHA、字节数和移除数；不改drawing、运行时或清理代码。
- `preview-native.png`：真实无快照Lua回读4×预览，576×256，非缩放源图或官方截图。本登记不重绘、不重导出。
- `asset.json`：文件SHA/字节、尺寸、contain、图元、身份载体、来源、认可和未验状态；新认可绑定新文件hash。Heavy的 `supersededRevisions` 保留旧全部文件hash、旧正评和后续否决，原文件从指定Git历史恢复，不在当前树重复上传历史PNG。

源图等比contain进144×64，无裁切或拉伸。Armaments/Cleave偏移0；Heavy保持1882×836原输出，scale=144/1882，纵向居中偏移约0.0170031881原生像素，不强行拉伸为9:4。旧 `../geo-samples/` 144×34候选和控件池保持原样。

## LFS与读取边界

已认可原生资产仍仅六条精确PNG路径使用Git LFS；新源候选另见下节，JSON/Lua/提示词为普通Git文本。已认可六对象合计 **5,983,528字节**：Armaments既有2对象1,780,725字节，Cleave+新Heavy新增4对象 **4,202,803字节**。旧Heavy两对象1,799,624字节只在历史保留，不重传、不扩大include glob。

复用现有 `scripts/ci-reviewed-lfs.mjs`，仅真实资产测试所在分片和Licenses读取；工作流不变，无其它分片下载。LFS指针不是PNG，必须取回后验实际签名、尺寸、SHA；冻结OID及真实总字节预算继续fail closed。

## 当前边界

- 新Cleave身份载体为短圆、低宽分段荒星/环顶/结构性琥珀岩纹；新Heavy为荧连续白蓝腰裙及金色拱腰饰、正常单手直剑的一次刃缘接触，不能退化成通用金色符号。
- 仍是 `IMAGE_PREFAB_ID=0`、正式运行时未接线；不能将图库ID当模板索引。正式界面保持占位回退。本目录不烘焙完整卡面或动态文字。
- 独立插画与整卡1×离线一致。4×严格一致仍 **FAIL**：Armaments25、Cleave11、新Heavy4像素量化差，未抬阈值。新两卡整卡证据使用真实数据commit `ac8cc52454db85939ee131ece85bfd421af7b7bd`，基础/升级1×均0差；旧Heavy历史47像素FAIL不覆盖。
- Heavy升级1×缺图已在独立装配验证中按fail-closed修复，用户看过的4×字节不变；本资产登记不修改装配器，不把该修复当官方显示证据。
- 官方导入、PC、实体Android、真实中文、XYZ/蒙版、进出清理、加载及1/5/10卡性能均未验。普通批量仍B=4、稳定次数0，未恢复队列或批准全卡池。

## 离线回归

```sh
node --test --test-concurrency=1 tests/reviewed-traveler-geo-assets.test.mjs tests/ci-reviewed-lfs.test.mjs
```

复用锁定 `luaparse`，移除可选编辑器快照后校验真实字面表、逐图元几何/RGBA/层序、图片/蒙版/图库计数、无文字或PNG嵌入。保留错误ID、路径、hash、尺寸、缺文件、真实literal篡改、CRLF与可逆EOF负控；旧Heavy真实蒙版小型字面证据仍验证启用位/offset不可篡改。新身份、两阶段来源链、严格FAIL及旧批准不可复活另有负控。回归不是平台或性能证明，来源见 [PROVENANCE.md](PROVENANCE.md)。
## 受控原生装配候选（默认关闭）

新增接线仅供 `cleave` / `heavy_blade` 的显式单卡实验，不把离线认可升级成游戏验收。沿用共享 CardDisplay 和 Combat 预览，插画不拥有名称、费用、类型或描述。缺少资源/原生能力时返回原图标；牌库模板暂不增加原生图元池。

从仓库根目录生成候选，`EDITOR` 指向已安装且固定在 `103025f9095d8089e3f9bf097f4d0c5fe039d546` 的现有 Image Editor；不安装、不重新描图。生成文件只能写入本仓库的构建目录，不能覆盖输入：

```sh
mkdir -p build/native-art-review
python - <<'PY'
import hashlib, json
from pathlib import Path
assets = []
for card in ('cleave', 'heavy_blade'):
    entry = {'cardId': card}
    for kind in ('lua', 'json'):
        path = (Path('art/cards/traveler-geo') / card / ('native-art.' + kind)).resolve()
        entry[kind] = str(path)
        entry[kind + 'Sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    assets.append(entry)
Path('build/native-art-review/sources.json').write_text(json.dumps({'schemaVersion': 1, 'assets': assets}, indent=2) + '\n')
PY
python scripts/art/assemble-native-card-samples.py --editor "$EDITOR" \
  --candidate-registry build/native-art-review/sources.json \
  --candidate-output build/native-art-review/literal.json
node scripts/build-ui.mjs build/native-art-review/one \
  --native-card-art-registry=build/native-art-review/literal.json --native-card-art-count=1
ABYSS_NATIVE_ART_SOURCE_REGISTRY=build/native-art-review/sources.json \
ABYSS_NATIVE_ART_LITERAL_REGISTRY=build/native-art-review/literal.json \
  node --test --test-concurrency=1 tests/native-card-art-source-equivalence.test.mjs
```

普通 `build:ui` 仍为零新增；显式档位仅 0/1/5/10，每卡池含2657图形、45组和1根控件，即新增2703/13515/27030。计数包括隐藏预分配，不是FPS、内存或平台上限。实机顺序必须先基线、再单卡，稳定后才能另行评估5/10；不要直接导入十卡高控件候选。正式 native builder 仍会重新生成UI，不能假定先运行 `build:ui` 就会保留到最终GIL。现在须在正式入口显式传入同一份 registry 和卡数（或既有的 `--native-card-art-host=<真实宿主>`）；它复用已有生成器，把布局交给 `scene_add_client_ui`，动态插画资料打包进 `abyss_presentation` 并做原有模块读回、旧脚本清理、结算图复用与BGM参数检查。

正式候选先做同一底图的基线，再做单卡；下例不启动试玩、不操作官方客户端：

```sh
node scripts/build-native-candidate.mjs <clean-base.gil> build/native-art-review/baseline
node scripts/build-native-candidate.mjs <clean-base.gil> build/native-art-review/one \
  --native-card-art-registry=build/native-art-review/literal.json --native-card-art-count=1
```

API 使用 `buildNativeCandidate({baseMap, nativeCardArt: {registry, count: 1}})`，或把 `count` 换成显式 `hosts: ['battlePanel/card1']`。默认不提供该选项、或显式 `count: 0` 时仍为零新增；5/10只是显式实验档位，不是容量或性能批准。正式入口只接受本仓库内有原始Lua/JSON来源的文件registry；不接受无来源内存对象。自定义 `prepare` 与启用原生卡图不能组合，避免静默丢图或绕过原保护。

每轮独立目录的 `candidate.json.nativeCardArt` 记录源Lua/JSON、派生registry的真实摘要及路径、实际生成布局/动态展示模块的摘要、宿主和控件预算。既有 `payloadDigest` 含义不变；额外来源在MCP连接前、打包结束及UI验收时复核，改源、改registry或改生成物都拒绝沿用。原生音频包装保留并复核该证据，不改变BGM或结算流程；现有音频CLI不隐式开启卡图。保留整个候选目录以便复验，不能只复制GIL后丢弃其生成文件。`--playtest` 仍默认关闭，live write保持0；本入口测试使用 **MCP mock**，不代表官方编译、导入或实机通过。

截至2026-10-27，PR259的 CursorArea 字段修复已随 develop `e0fad45` 进入本候选基线。共享宿主回归在严格mock下直接执行真实源码，不再依赖启动修复的内存替换；覆盖战斗、奖励、牌库和商店，并保留不支持的 CursorArea 字段与缺失根 GameUI 图片枚举转发两项变异负控。此结果仍不是实际游戏ready证明。官方导入、存档写入、PC、实体安卓和真实性能全部待验。原生图库预览缺图须失败退出，不允许把缺失图层当画质降级；已认可源图不因此重绘。

## 2026-10-29 夜间插画候选制作

Owner 新指示为旅行者职业卡面**插画**优先，怪物随后，睡觉期间自主检查并通过 Git/LFS 与 PR 保存；不改卡框、文字、UI 或战斗规则。现有三张离线认可源图保持原字节。职业集合以 `data/reference/warrior75.json` 与当前规则交集的 75 个稳定 ID 为准，不混入状态牌和诅咒；新图列在同一 catalog 的 `candidates`，不混进旧 `cards` 认可集合。

已读项目 Sheet `Docs!A241:E255` ART-00～12 与仓库规范；其中没有逐 card_id 全序。本轮据实际首次游玩顺序，先初始卡组去重（普通攻击、防御、破防斩），再普通、罕见、稀有的当前数据顺序，跳过已有认可图。每批 B=4、实际两路逐张生成/检查；保留真实首过与返工记录，未达到原生/设备闸门前不宣称稳定正式生产批，也不扩到 8/16。

每个源候选保存原始输出、实际提示词/引用 SHA、实际尺寸和 144×64 等比 contain 检查图。模型版本、seed 和费用未由工具提供则记未知。用户允许自主制作不等于用户逐图审美认可；候选均 `productionRuntimeApproved=false`，没有正式接线。源图完成不等于原生精修、完整卡面或真机完成。

首批破防斩与普通攻击初稿构图过近，已保留旧源哈希并另作一次俯视刃缘破甲构图。普通攻击的低成本原生试绘未达已有精修基线：1797 控件仍明显几何化，严格 JSON/去快照 Lua 重放 1×1040、4×9552 像素差；未改容差刷绿，失败底稿已隔离，不装入候选 catalog、不复制给其它卡。继续保留原固定编辑器与正式装配流程；没有新渲染器、运行时 PNG 或原生性能保证。原生精修仍需后续完成。

新源 PNG 采用**精确路径** Git LFS。新法律清单条目显式记录原图 SHA-256、字节数和 `lfs: true`；CI 对未下载的新源仅核对规范 LFS 指针指向该已登记内容，不能据此判断像素、对象可用性或美术质量。本地必须核对真实 PNG 签名、尺寸和原始 SHA；提交前另核 LFS 上传。现有六张已认可 PNG 的真实字节校验、冻结 OID、下载白名单和预算不变，不为每次 CI 下载全部候选源图。

`ruleSource` 保留生成当时的规则快照与数据哈希，不因不影响画面的数值微调回写历史或强迫重画。目标、动作关系或主要机制发生变化时仍须复核插画；文件/稳定ID/等比适配及未启用状态由回归检查。

### 本轮源候选收口

75 个职业 ID 已全部有源资产：保留原 3 张认可图，新增 **72 张源设计候选**（18 个 B4 批次）。新源 LFS payload 合计 **139,831,959 字节**；不是运行时体积或费用保证。全部 72 张已由独立执行者逐张查看真实原尺寸与 144×64 小图，PASS 仅表示源设计自检，逐图理由及精确 SHA 见 [source-design-review.json](source-design-review.json)。覆盖回归绑定每张源图和小预览摘要，不把规范 LFS 指针当作像素审查。

真实历史保留：破防斩、焰铠、净化有各自修正链；踏风踢首次请求被阻止且未产出，另一次独立的无接触预备姿势设计成功，来源不伪称首稿通过。候选不得继承旧三张的 Owner 认可。72 张原生精修、整卡动态文字对照、官方导入、PC/Android 与性能均未完成；TASK-25.2 继续 In Progress，普通正式生产稳定批仍 0。怪物另作后续独立切片，本 PR 不含怪物或原生失败底稿，不启用任何新运行时图。
