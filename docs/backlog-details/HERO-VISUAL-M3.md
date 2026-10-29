# 首屏与主角视觉交接

本切片只接 UI 槽位和开局路径。Dot A/B 的资产源文件没有改。没有官方导入，没有写入存档，没有本轮真机。不能把占位图当成正式插画通过。

## 玩家路径

正式入口：主菜单 → 角色选择（生产环境打开即显示岩系旅行者，不跳过选角）→ 高塔恩赐（七天神像，对白和选项仍走原有 `abyss_neow.lua`）→ 第一幕地图。已取消的电影镜头和跳过按钮不再播放，序章面板保持隐藏。

显式 full-source 仍保留八个角色入口。未完成角色使用各自槽位，并标明「肖像待补 · 非本次正式角色」，不借用旅行者的图。

商店旧路商人本来就接在 `abyss_merchant.lua`：进店对白、购买、金币不足、离开都还在。本切片没有重做交易。

## 槽位

都在 `data/presentation/ui_theme.json` 的 `icon.heroSlots`。正式资源到位后只改对应 `id` 和 `status`，不要改布局脚本。`status` 仍是 `placeholder` 时，界面会写「肖像待补」。

| 槽位 | 负责人 | 当前编号 | 说明 |
|---|---|---|---|
| `dot-a.menu.traveler` | Dot A | 105301 | 启动页右侧主视觉，与岩系旅行者选角大图共用 |
| `dot-a.select.large.traveler.ironclad` | Dot A | 105301 | 同上 |
| `dot-a.select.large.traveler.anemo` | Dot A | 105302 | 开发入口，未开放 |
| `dot-a.select.large.traveler.electro` | Dot A | 105303 | 开发入口，未开放 |
| `dot-a.select.large.traveler.dendro` | Dot A | 105304 | 开发入口，未开放 |
| `dot-a.select.large.hutao` | Dot A | 105305 | 开发入口，未开放 |
| `dot-a.select.large.arlecchino` | Dot A | 105306 | 开发入口，未开放 |
| `dot-a.select.large.furina` | Dot A | 105307 | 开发入口，未开放 |
| `dot-a.select.large.raiden` | Dot A | 105308 | 开发入口，未开放 |
| `dot-a.select.bust.*` | Dot A | 105311–105317、105291 | 底部小头像，每人一张，不与旅行者岩系大图混用 |
| `dot-b.battle.traveler` | Dot B | 105292 | 战斗胸像。槽位仍约 133×133。不再使用岩元素图标 102005 |

七天神像用现有矩形、圆盘和光晕拼在事件插图位，标题是「七天神像」。它不是旧路商人。商人仍是商店对话框里的兜帽剪影。

## 已跑的检查

- `tests/hero-visual-slots.test.mjs`
- `tests/lua/hero_visual_slots.lua`
- `tests/lua/game_ui_prologue.lua`（10 项：电影镜头不再播放，恩赐可进地图）
- `tests/lua/approved_opening.lua`、`geo_public_entry.lua`、`neow_game_ui.lua`、`formal_campaign_entry.lua`、`full_source_campaign_entry.lua`、`controller_host.lua`、`game_ui_classes.lua`、`competition_roster_ui.lua`、`title_menu_admission.lua`
- 节点布局、主题校验，以及历史界面回放夹具

## 还没做

- Dot A 的启动页/选角正式插画，Dot B 的战斗胸像
- 官方导入、编辑器预览、电脑和手机实机
- 因此 TASK-59.3、TASK-4.9、TASK-25 的整体验收保持未勾
