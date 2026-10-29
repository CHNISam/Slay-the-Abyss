# 岩荧 V2：选角头像与战斗全身图

**源设计效果已获 Owner 于2026-10-29 14:20 UTC认可；原生显示、透明度、性能与上传容量没有因此通过。** 只做本批两张，不扩角色。用途标准与原版截图见[REFERENCE-STANDARD.md](REFERENCE-STANDARD.md)。V1方形胸像未获用途批准，已单独保全，不进入本候选。

## 直接看图，不下载包评审

Owner评审只展示少量用途/尺寸对照。此目录给开发者保留源图、实际提示词、可编辑JSON/Lua和验证记录，不把工程ZIP当作用户评审交付。

- `avatar96/source.png`：头部、白花、金发与双眼；1254×1254 RGBA原字节。
- `battle133/source.png`：朝右迎敌的透明底完整持剑站姿；1024×1536 RGBA原字节。它是**全身**，不是胸像；文件夹133只表示候选原生画布尺寸。
- 两份 `prompt.txt` 是此次真实生成提示词。两份都参考既有 `art/source/lumine_geo_portrait.png`，未修改Dot A大插画。Dot A最终主视觉hash仍需核对。
- 原作参考仅用于区分小按钮、大插画与战斗角色用途，不将原作截图/角色资产装入游戏。

## 给 Grok 的绑定合同

本轮选角ID `traveler`、岩元素/开局配置 `ironclad`。小头像由本资产切片交付，Dot A负责大插画；其他角色不得共用荧图。已在PR338交接评论说明此分工与全身方向。

PR338的稳定键 `dot-a.select.bust.traveler.ironclad` 可先保留为旧键，但不代表当前负责人/图的用途；战斗键为 `dot-b.battle.traveler`。**本输出是多图元Lua，不是图库图片ID，不能只填id/status就算完成。**

使用 `native-art.json` 在固定Image Editor编辑；`native-art.lua` 保留原导出；`runtime-no-snapshot.lua` 仅去编辑器快照注释和额外尾LF，代码数据仍是原Lua精确前缀、绘图表一致。模板常量仍为0，必须在独立真实GIL副本建立图片模板后绑定该副本返回的templateIndex。100001是矩形图片资源，不是模板索引或新的荧图号。

导出器会设置自己的宿主尺寸/位置/缩放，只能挂专用空子容器，不可挂hero或共享UI根。图片模板的非交互配置、层级清理/显隐和真实客户端行为均须验证；不能挡住原有状态/出牌等输入。

尺寸更正：ui-layout.mjs初始构建的portrait是117.333，但abyss_battle_unit_view.lua的portraitParts每次刷新会把portrait设为133.333；battle_render_hud.lua传入完整人物尺寸，approved_main_unit.lua也断言133.333。它们是代码逻辑尺寸，不是已测手机物理像素。因此不再推荐固定0.8822055比例：专用宿主的最终尺寸/缩放须由Grok结合动态刷新与实际层级确定。已展示117图只保留为缩小对照，不称真实运行绘图区。选角128×56按钮在该基线没有96头像子控件；本切片未改UI、血条、格挡、状态或规则。

## 离线结果和明确失败

| 项目 | avatar96 | battle133全身 |
|---|---:|---:|
| 图片图元 | 4822 | 4315 |
| 蒙版 | 0 | 0 |
| 去注释runtime字节 | 395396 | 356825 |
| 另需专用宿主/模板定义 | 1 / 1 | 1 / 1 |

源图→RGBA颜色区域是自动底稿，不冒充手工精修完成。只省略alpha恰为0的格子，没有补不透明背景。固定103025编辑器JSON/Lua导出、实际literal属性和VM启停/失败清理通过。

**固定工具原PNG透明度对照失败**：闭区间矩形栅格与source-over导致边界重复覆盖；分别6284/5277像素alpha不同，最大差255。保留原输出和`alpha-verification.json`，不改上游或降低门槛刷绿。

同一几何经固定SVG导出和已有Inkscape离线重放，透明/非透明范围一致，但8bit alpha及四舍五入后的8bit预乘RGB仍有最大1的量化差；低alpha像素的直通RGB差可达126/127，不能概括为所有颜色只差1；它不是零误差通过，更不是官方原生显示。`preview-svg-inkscape-*.png` 只能作为诊断/视觉对照，不能冒充实机截图。JSON/Lua与原PNG失败证据均未被该诊断改写。

图片、JSON、Lua/GIL/上传量不是同一指标，不能相加或相互推算。图元成本仍高；真实基底GIL/完整SDK、官方编译/导入、B0/B1增量、手机表现均未测。首个真平台B0/B1只选avatar96单宿主；**不保证20MB安全，不启用生产，不批准扩大装配。**

## 沿用既有流水线与批次规则

用途参照确认 → 两张标杆源设计/实际尺寸 → 同源图元精修与真实导出 → 源/重绘对照 → 一个B0/B1 → 真机/容量后再扩大。常规B=4、两稳定批翻倍/最多16等原规则不改；当前为用途错误修正后的两张验证，稳定计数0，首次合格率未知。Owner本次肯定只绑定V2源设计/已展示比例，不向V1或尚未验证的原生效果扩展。

`author_scene.py` 只为这两张产生既有editor schema；`adapter/`复用已缓存固定工具，无新依赖或新导出器。适配器README中第一轮角色说明是历史上下文，以本文件和REFERENCE-STANDARD的V2用途为准。

## 复跑用新目录

直接消费已交付JSON/Lua不需要本会话缓存；可用现有固定版本Image Editor导入native-art.json。下面只是有既有同版本缓存时的离线复核。adapter/README中第一轮输出到资产目录的命令是首次生成记录，该目录现在已有成果，不可原样复跑或删除证据来绕过覆盖保护。

```sh
CACHE=/path/to/existing/starfall-offline-export
ASSET=art/characters/traveler-geo/portraits/avatar96
OUT=build/portrait-recheck/avatar96-new
python3 art/characters/traveler-geo/portraits/adapter/export_portrait.py \
  --cache-root "$CACHE" --kind avatar96 --scene "$ASSET/editable.scene.json" \
  --source-image "$ASSET/source.png" --crop 0 0 1254 1254 --output "$OUT"
node art/characters/traveler-geo/portraits/adapter/check_lifecycle.cjs \
  "$CACHE" "$OUT/native-art.lua" "$OUT/native-art.json" "$OUT/vm-report.json"
```

OUT必须全新。当前工具/依赖缺失时如实停止该复核，不自动下载安装或改固定版本。
