# 已采用 UI 的原生 Simulator 实现切片

供项目继续接入和测试。此目录依赖 #518 的设计/代码基线，不替代生产入口，不是已完成游戏或官方导入包。

## 已包含

- 菜单：批准的位移/高亮递推、角色横幅 hover/pressed、切页和旧回调失效。
- 商店：保持既有绿布布局与素材 ID；商品及价格一起 1.14 倍缩放、130ms CSS ease 与反向中断、层级复位、余额/售出/重复购买保护、离开导航回调。
- 战斗：实际 Run/Combat 命令，批准红色 7px、12/9 虚线二次曲线；生产 release 所有权、C 模式、carry、牌位缓存及 idle/hover 命中区并集。补回左下角能量数字的连续深红描边，保持原能量球、数字和位置；原生描边不支持 CSS 的 1.2px 精确宽度。反馈仍为局部适配。
- 地图：已批准的节点布局和七种平台图标映射；独立视觉样例，未接实际 Run 地图状态。

布局以 gzip+base64 无损存储（读取时核对展开 SHA），仅含原生控件、文字、坐标与图片 ID，没有嵌入图片、字体或私人缓存。构建复用本仓库 Lua 源及已公开的 art-tech-lab seed，不复制一整份核心模块。

构建只读取声明的两个生成数据模块，并现场生成主题；build/lua 中若有与 src/lua 同名的残留模块会拒绝构建。战斗在更新入口将呈现步长限制到 0–0.1 秒，长帧后继续播放反馈，不为补时重复提交游戏命令；这不是解决实际出牌耗时的性能优化。

## 先运行无素材回归

使用本仓库锁定依赖和原测试入口：

```sh
npm ci --ignore-scripts
npm run build:data
node --test tests/native-ui-preview.test.mjs
node experiments/native-ui-preview/build.mjs battle --check-only
```

测试涵盖菜单、商店、箭头、真实出牌与回滚、战斗接线状态和控件结构。没有派发鼠标、键盘、抢焦点或原生指针事件；不证明真实命中或触屏手感。`npm test` 会发现本次新增的测试 wrapper，未更改 CI 或放松既有门禁。

## 构建真实视觉候选

精准视觉还需原作者提供的对应场景 image-cache，以及获准使用的中文字体。清单/哈希在 `asset-inputs.json`，其中 ID 是隔离缓存别名，不能拿官方同 ID 图片代替。当前再分发权未全部确认，因此本提交不含这些纹理；缺素材会明确失败，绝不回退到错误图像。

```sh
node experiments/native-ui-preview/build.mjs menu --cache /your/private/menu/image-cache --out /your/output/menu.save.json
node experiments/native-ui-preview/build.mjs shop --cache /your/private/shop/image-cache --out /your/output/shop.save.json
node experiments/native-ui-preview/build.mjs battle --cache /your/private/battle/image-cache --out /your/output/battle.save.json
```

四个场景为 menu/shop/battle/map。menu、battle 可加 `--demo` 开启程序语义演示；这仍不注入输入。使用既有 BeyondSimulator 0.5.2，在其只读副本中载入输出；设置 `QXQY_IMAGE_CACHE_DIR` 指向同一缓存、`QXQY_FONT_PATH` 指向已获准字体。不要在没有本轮明确输入窗口时运行 pointer/key/click/自动试玩。

商店 `NewShopController(root,{onNavigate,state})` 在离开前注销旧代际，再请求 `onNavigate('map', snapshot)`。快照有 `fixtureOnly=true`；外层必须实际接导航，不能把打印日志当作完成跳页。独立样例未接生产经济/牌组。

## 已验证与尚未完成

本轮原生 Host 已验证菜单 63 项、商店 62 项及战斗语义/几何回归。商店正常帧与既有定稿切片 PNG 完全相同。公开目录可以重跑代码回归；私人素材像素证据不在 GitHub。

仍未完成：完整生产反馈链、结束回合/药水/奖励/胜负导航、地图实际规则、官方导入、真实鼠标/手机命中、GPU 帧率、用户可访问的私有实时入口。菜单 modal 未完成键盘/手柄焦点隔离；商店亮度过渡有原生 8 位舍入。

Fengari 中单次 Run.play 样本约100–200ms，约95%来自完整回滚快照。未删快照、未改核心规则或采用无稳定收益的优化。离线60Hz轨迹不等于实时60FPS或输入延迟验收。

## 权利与来源

保留根目录 LICENSE、LICENSE-SCOPE.md 和第三方声明。自写适配和测试适用项目许可；布局/ID记录不授予第三方纹理、角色、字体或原始美术的再分发权。未纳入 PNG、SVG、字体、音视频、完整 save/bundle 或缓存；新未验收 full-feedback 实验也未纳入。来源与冻结候选身份见 `provenance.json`。
