# TASK-38 UPSTREAM 原版实验包

本轮只交原版基线；PORT / INTEGRATED 尚未开始。官方导入、真实 ready、PC 与实体手机均 NOT_TESTED，不宣称修复。

- 上游：8itlab/genshin-miliastra-mcp@eb05fd35075b2635e851a2f58b202ac2eadd187b（MIT，许可证见 upstream/LICENSE）。
- GIL：UPSTREAM-Pairs-eb05fd35.gil
- SHA256：`6f7380d097ca33884fed10ef633ff86882ad7295d73142c2c7ade851c7b05923`
- 上游七个文件逐字节对照 Git blob 通过，见 source-hashes.json；GIL 内 PR_game 独立读回与上游 Lua 完全相同。scene_check_client：0错误、0警告。

## 必要部署差异

沿用 upstream/scripts/dev/mcp_round.mjs 的离线创建顺序：信号→图→Lua（含 seconds 原变量）→模板→UI→生成图源码→write_graphs。build.mjs 仅负责这些调用，没有游戏 UI 算法。

原始 pairs_win.json 的 baseName 在本机不存在，改为已有空白副本：原路径为根 .artifacts/2d-art-benchmark-20261025/single-scene-v2/base.gil，SHA256 `6e82decfb9b113310ba97c0cad5cf541288c0cada5cb52644a0dd8785004a432`。本轮 inspect_map 确认 graphs/signals/prefabTemplates/uiConfigurations 均为空；listInterface 无客户端 UI/模板，只有默认平台控件。未清理或移植正式游戏。底图来源与原始作者底图不同，需视为部署变量，不能声称地图字节与作者相同。

工具使用本机 MCP@7091060417fe9bd1231e812db4f798c97a5c63d1，区别于样例源码版本。图 ID、模板索引由实际调用返回，路径和 outputName 改为独立工作区。没有场景包，跳过 GUI 打开、空场景导入及试玩；无键鼠操作。所有写入仅存档副本，MILIASTRA_ALLOW_LIVE_WRITE=0。完整参数/返回值见 evidence/receipt.json；控件读回见 evidence/ui-readback.json。

初次 git archive 因 Windows 自动换行转换未通过字节核对，已直接读取 Git blob 并重新构建；旧候选保留在本地 build-1793417415792，不交付使用。

## 手机测试

1. 将本 GIL 在官方客户端导入为新的独立测试存档，命名建议 TASK38-UPSTREAM-Pairs；不要覆盖正式游戏。由用户完成导入和设备测试，本轮尚无官方导入成功证据。
2. 先在开场记录 PR_LUA ready cards 12（若取日志），确认屏幕出现“翻牌配对”和开始按钮；点开始，应见12张牌。测试翻牌、暂停、继续，记录卡牌比例和触点命中。
3. 同一手机横屏保存开场、牌局、暂停截图，记录机型、系统、原神版本、方向、截图像素尺寸、左右明显亮度边界的位置和宽度。原图含 UID 仅本地保存，公开图脱敏。
4. 原 dim.opacity=0.72：全屏看到暗化场景是有意透明，重点看左右是否存在未暗化窄条，不能将透景一概记为失败。无法判定则记 INCONCLUSIVE，再另建仅改透明度的诊断包；本包禁止修改。
5. 原版无画布尺寸日志，不为加探针修改 Lua；该字段本轮 unavailable。日志与截图必须关联本 GIL hash，不能借旧候选。反馈原版结果后再决定 PORT 的唯一变量。

离线复现（已有本机工具，需给出空白底图）：`node experiments/task38-upstream/build.mjs <blank.gil>`。每次新建时间戳目录，保留调用收据，不自动启动游戏。

## UPSTREAM-DIAGNOSTIC 不透明背景诊断包

用户提供的原版截图可见十二张牌、计时条与3D场景；画面含PC按键提示，不能据此认证手机覆盖。用户本轮同意另建不透明背景诊断包。

- 文件：`UPSTREAM-DIAGNOSTIC-Pairs-opaque.gil`
- SHA256：`ae528eff0e5da4f8ad92ff458c9fe9505ed24d9b4256833c4bd8a9f6c9f123a1`
- 从已交原版GIL副本只改 PR_ui/dim 颜色中的alpha：184→255（源0.72量化后为184/255），RGB不改。脚本、控件ID、布局及其余存档字节保留；恢复该字段可逐字节还原整个原版GIL。见 evidence/diagnostic-opaque.json。
- `node experiments/task38-upstream/build-diagnostic.mjs` 可复现；目标存在则拒绝覆盖。静态检查0错0警告；官方导入、ready、手机均未验证。

请导入为新的独立诊断存档。手机横屏打开后，看深色背景是否一直覆盖到左右边缘：若仍有天空/草地窄条，截图记录；若完整遮住场景，说明此候选背景在该设备上覆盖了对应区域。原生HUD可能叠在上层，其可见性不直接代表背景露底。只需截图反馈，无需找日志。卡牌比例、点选与暂停另作观察；本包不认证正式游戏修复，也不是PORT。
