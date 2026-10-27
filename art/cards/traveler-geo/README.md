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
