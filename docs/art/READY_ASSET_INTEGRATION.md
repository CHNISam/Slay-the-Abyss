# 当前比赛美术接入

## 当前候选约束（2026-10-31 Owner纠正）

卡牌插画暂时废弃，留待后续。源资产及实验能力保留，Alpha和Production交付候选均不得启用。
当前可执行决定以 `data/release/candidate-art-policy.json` 为准；下文历史接入能力和“显式开启”示例不构成本轮许可。
正式工具链入口在读取SDK或写存档前检查最终解析后的开关，旧registry/count/host参数也不能绕过；构建返回及正式负载验证再检查收据。
策略文件包含在候选源码摘要中，缺失或格式错误会失败。重新启用必须先明确改变并审查该产品策略，不能仅传 `--art-cards=true` 或在UI分支改变默认值。
实验 `build-ui` 仍可验证保留资产；实验成功不是交付许可。交付当前关闭配置使用 `--art-cards=false --no-ready-card-art`。

2026-10-30 Owner明确要求将仅有源图的卡也全部接入，覆盖此前00:59只接三张原生卡的临时范围。构图重做与新增生图后置，不改规则、数值或批准布局。

## 实际资源与接线

- 75张旅行者职业牌：3张精修原生数据保持原字节；另外72张复用已提交144×64源预览，经固定算法转换为180873个矩形，逐卡2072～2656。来源、SHA、参数、误差与完整覆盖检查见 `art/cards/traveler-geo/runtime-candidate/`。状态/诅咒14张不在这75张职业牌内，继续既有图标。
- 卡图在实际原生模板索引绑定后延迟加载，按card_id共用战斗、奖励、商店、牌库等卡面路径。名称、费用和描述仍为独立动态文字，规则来源不变。
- 同时最多10个原生卡图池，每池最多2657图形；全局每次更新最多创建64个控件，未完成时保留原图标。关闭、换牌、回收和销毁失败处理均有回归。
- 菜单/选角共用现有13201矩形官方横版背景，480×270等比适配1280×720，不拉伸人物；进入战斗释放。
- 荧选角头像4822图形、战斗形象4315图形，复用原数据，分层组装并共享每次更新64创建预算。战斗位移/缩放沿用现有反馈；不宣称全部逐像素闪色效果已验证。
- 构建与审计保存实际模板索引、输入SHA及资源清单；音频封装保留美术收据。无绑定或创建失败时回退原图标，不让静态源图冒充可导入资源。

## 质量和验收边界

72张转换输入是已提交的小尺寸预览，不是重新下载高分辨率源图。4张STD10候选（iron_wave、disarm、offering、reaper）保留量化/块状降级记录，不能称为逐卡精绘。准确名称以展示数据为准。

源图/离线重建审查、运行时模拟、候选GIL写入读回、官方导入、PC及实体安卓性能分别验收。此次源码接线不改变历史透明度严格比较失败记录，也不替代新候选实机验收。当前没有本轮官方GIL、官方容量读数、真实ready或设备FPS证据。新增控件预算只是代码上界，不是平台承载能力证明。

## 后续操作

按仓库构建入口生成同一候选，审计模板与哈希后，在明确的桌面输入窗口内导入，检查菜单→选角→战斗、手牌/奖励/商店/牌库切换和退出清理。记录同候选PC与实体安卓加载、控件/容量与帧时间；在这些证据完成前，M3与正式美术验收不因CI通过而自动完成。


## 开发/发布侧 feature flags（本次变更设计）

Owner 2026-10-30 06:57 UTC 明确开关由开发/发布人员控制，不给玩家。四项独立布尔值为 `cards`、`menuBackground`、`selectionAvatar`、`battlePortrait`，缺省均为 `false`，使用现有官方图库/原界面回退。该决定覆盖上文 PR361 的历史默认开启行为，已生成资产和来源不删除。

采用已有 Node 构建参数 → 生成 Lua 绑定 → 原生候选/音频收据 → 独立读回的轻量路径；不增加远程配置服务、账户分流、玩家设置或新依赖。配置在候选构建时固定，更改开关需要重新打包/导入；这不是线上即时远程熔断。

配置契约：生成 `abyss_art_features.lua` 返回 `{schemaVersion=1, flags={cards=false,menuBackground=false,selectionAvatar=false,battlePortrait=false}}`。构建 API 使用 `artFeatures` 部分覆盖，CLI 每项显式 true/false；未知项、非布尔值、重复/冲突参数拒绝。保持 `--no-ready-card-art` / count=0 的卡图关闭语义；显式旧静态registry可作为卡图启用路线，但不能越过显式关闭。所有候选记录最终有效开关和配置版本/输入摘要，审计按同一组合重建，错误收据不得借用其它组合。

关闭项不生成大幅绘制数据、不加载对应Lua数据、不创建动态图元；保持现有官方资源可见。背景与两类肖像独立，不能因关闭一项而隐藏另一项或触碰无关宿主。新构建/销毁沿用现有释放机制；补齐旧占位图标所有权修复，禁止旧回调覆盖新资源选择。

验证：默认官方路径；四单项及全部16种组合；合法开启的真实75卡/既有背景/肖像；关闭项数据和创建调用为零；错误配置及参数冲突；音频透传/独立读回/收据篡改拒绝；生命周期与既有P1矩阵。源码/离线验证不替代新GIL、官方容量和PC/实体安卓验收。

### 开发人员选择候选组合

普通 `npm run build:native -- <base.gil> <output-directory>` 不启用自绘。需要测试卡图时追加 `--art-cards=true`；其它三项分别为 `--art-menu-background=true`、`--art-selection-avatar=true`、`--art-battle-portrait=true`。每项也可显式传 `false`，未提供的项仍关闭，同一项重复提供会被拒绝。`alpha-test` 身份本身不启用美术。

这些参数仅属于开发构建工具，不能从玩家设置、存档内容或游戏内按钮覆盖。每次候选检查其 `artFeatures` 收据与生成的 `abyss_art_features.lua` 是否一致；关闭某类后应同时检查对应数据、模板/宿主和创建调用，不只查看画面是否隐藏。要回退已导入候选，重新构建关闭组合并按原流程导入；不宣称有远程实时开关。

### 试玩收尾（2026-10-30）

本轮交付改用已安装官方图库的十个现成图片编号，分别用于启程、选角及不同幕/普通战斗/Boss，直接作为原生 Image 显示。它们不经过运行时像素重建，也不是原版风景宣传画。用户实测 V13 后确认当前底图约 60 分、足够发版；本轮停止替换与美术实验。该反馈只认可底图可用，不代表全屏 UI 或实体安卓验收通过。

原自制插画及减量实验源全部保留。`menuBackground` 开关继续默认关闭；开启后仅在胜利自有结算页面点击“查看彩蛋”才加载，配文“感谢您的游玩~！”，退出彩蛋暂停并缓存，普通入口不创建。选择肖像启用时在启程页预加载，先构造选角主图，再构造头像；战斗原图数据保留。卡面插画继续默认关闭，不阻塞出牌。

本轮还修复选角页退出弹窗的输入拦截，并使正式装配批量写脚本、只复用来源及模板完全匹配的 UI，最终全量静态检查和源码读回保留。V13 是合并前冻结源的已交付试玩包，不能当作合入最新 develop 后重新构建的候选。

### 低多边形选角精装外观（2026-10-31，Owner 认可突破实验 GIF）

复用突破实验（`feat/art-breakthrough-experiment@72f13f2`）已生成的面片数据，不新增开关、玩家设置或远程配置；数据固化在 `art/lowpoly-select/select-lowpoly.json`（`extract.mjs` 从实验 pack 抽取，丢弃占位文字行）。

| 开关 | 开启后 | 关闭（默认） |
|---|---|---|
| `--art-selection-avatar=true` | 选角主图改用低多边形荧（`lowpolyHero`，2011 面，官方图元 100003 + rotX/rotY 压扁） | 原官方/回退立绘，不生成该数据 |
| `--art-cards=true` | 选角详情下方五张精装金框卡扇（`lowpolyCardFan`，框+插画共 1585 控件，复用官方角花/宝石/名牌精灵），模板用已绑定的 ready-card 图片/容器模板 | 原官方卡面，不生成、不加载、不创建 |

两份数据只写入既有 `abyss_traveler_portrait_assets` 生成模块，并由既有肖像 owner 分批创建（每次更新共享 64 创建预算，离开选角暂停缓存）。范围边界：战斗/奖励/商店手牌的逐卡精装框与逐卡插画尚未接入，卡扇为选角展示且暂不含卡名/费用文字；收据 `officialPortraits` 清单仍按 selection133 计数，未单列低多边形控件。模拟器/源码测试通过不等于官方 PC/安卓验收：rotX+rotY 混合压扁、约 3.6k 控件性能与 GIA 导入均需正式客户端确认。

#### 2026-10-31 追加：卡面金框 + 候选默认开启

- `--art-cards=true` 同时把战斗手牌、奖励、商店、牌库共用的 `abyss_card_skin` 原生卡框改为突破实验金框调色（`ui_theme.json` → `cardSkin.premium`），只重新着色既有控件，名称/费用/描述文字不变；插画仍走已有 75 张自制卡图运行时。关闭时 `configure(nil)` 回到官方配色。角花/宝石等额外装饰精灵需新增布局宿主，暂缓。
- Owner 要求本次交付候选默认看到新美术：`npm run build:native` 与 `build-native-candidate.mjs` CLI 未指定时默认 `cards=true`、`selectionAvatar=true`；`--art-cards=false --art-selection-avatar=false` 立即回到官方素材。`build:ui`/API 默认仍全关；旧 `--no-ready-card-art` / `--native-card-art-*` 继续决定 cards。
- 未做：战斗/选角自定义低多边形场景背景（需在 battlePanel/characterPanel 底层新增宿主，与候选宿主屏蔽审计及并行 HUD/层级切片相关）；选角卡扇文字（无文字模板）。

### 2026-10-31 low-poly scene backgrounds (`--art-menu-background`)

- Source: breakthrough `land` group (362 triangles, 1587×1026) extracted into `art/lowpoly-select/select-lowpoly.json` → generated `lowpolyLand`.
- Layout: `attachLowpolyScenes` adds a hidden `lowpolyScene` container (1280×720) as the first drawn child of `battlePanel` and just under `characterPanel.border` (above veils). Not created when the flag is off; candidate audit blocks the host name then.
- Runtime: `abyss_traveler_portraits` builds `selectScene`/`battleScene` controllers (cached, budgeted); select hides official `border`/`face` only once the land is ready; battle draws behind every hand/monster/HUD control (no z-order change).
- Candidate default: ON (with `cards`, `selectionAvatar`); `--art-menu-background=false` returns to official. Scenes need bound image/container templates (portrait module binding, also bound for cards/menuBackground-only builds).
- Deferred: corner ornaments/gems on card faces (need new card-face layout hosts), select fan rank text.

2026-10-31 Pan 覆盖：候选/真机构建（build:native、build-native-candidate）默认开启 `cards`、`menuBackground`（低多边形选人+战斗场景背景，`lowpolyScene` 为战斗面板首个子节点、位于角色之下）、`selectionAvatar`、`battlePortrait`；`monsters` 仍需 `--art-monsters=true`。API/build-ui 仍默认全关；显式 `--art-<类>=false` 恢复官方。
