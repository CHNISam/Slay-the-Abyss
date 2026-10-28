# 旅行者·岩：源资产与当前评审状态

按稳定 `card_id` 保全三张现行卡图。整备武装原字节与认可保留；星陨剑及重剑斩为2026-10-27新身份修正版，用户认可仅覆盖两新样的源设计、原生重绘、整卡离线预览及岩旅行者身份。**旧重剑仍是身份被否决的设计反例，新认可不作用于旧源或旧原生hash。** 复用 TASK-25.2，不新增台账。

| card_id | 显示名 | 图片 | 蒙版 | 插画控件合计 | 源尺寸 |
|---|---|---:|---:|---:|---|
| `armaments` | 整备武装 | 1834 | 0 | 1834 | 1881×836 |
| `cleave` | 星陨剑 | 2657 | 0 | 2657 | 1881×836 |
| `heavy_blade` | 重剑斩 | 2043 | 0 | 2043 | 1882×836 |

每张含3个原生图库图片控件（106056/106057两种资源）。不含卡框、动态文字、宿主、输入、诊断或整屏其它控件，不能推导FPS或十卡容量。

## 文件契约

- `catalog.json`：三个显式ID映射到相对 `asset.json`，`runtime.status=unbound`。不向theme写入虚构图片ID；Cleave原有102012占位图标保持原样。
- `source.png`：实际imagegen输出原字节，非用户上传、非运行时外部PNG。
- `prompt.txt`：实际初始生成提示词。Heavy另有 `prompt-repair.txt`，是针对初稿的真实第二阶段刃缘接触修正；`generation.steps`按输入/输出SHA串接两步，不能只保留修正提示词冒充完整来源。中间源不重复入库。
- `native-art.json` / `.lua`：固定编辑器导出的144×64可编辑场景与真实绘图表。JSON不变；每份Lua仅移除多余的1个末尾LF，保留一个最终LF。`originalExport`记录可还原的原SHA、字节数和移除数；不改drawing、运行时或清理代码。
- `preview-native.png`：真实无快照Lua回读4×预览，576×256，非缩放源图或官方截图。本登记不重绘、不重导出。
- `asset.json`：文件SHA/字节、尺寸、contain、图元、身份载体、来源、认可和未验状态；新认可绑定新文件hash。Heavy的 `supersededRevisions` 保留旧全部文件hash、旧正评和后续否决，原文件从指定Git历史恢复，不在当前树重复上传历史PNG。

源图等比contain进144×64，无裁切或拉伸。Armaments/Cleave偏移0；Heavy保持1882×836原输出，scale=144/1882，纵向居中偏移约0.0170031881原生像素，不强行拉伸为9:4。旧 `../geo-samples/` 144×34候选和控件池保持原样。

## LFS与读取边界

仅六条精确PNG路径使用Git LFS；JSON/Lua/提示词为普通Git文本。当前六对象合计 **5,983,528字节**：Armaments既有2对象1,780,725字节，Cleave+新Heavy新增4对象 **4,202,803字节**。旧Heavy两对象1,799,624字节只在历史保留，不重传、不扩大include glob。

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
