# M3 当前界面静帧验收 · 2026-10-31

源码身份：`e8eb72360d1a1e9eef015948e3b63bf09661f372`，独立 detached 工作树；未修改生产 UI、主题或素材。工具：`beyond-simulator-mcp@0.5.2`，Node v24.19.0。实际 `tools/list` 保存为 `simulator-tools.json`。

## 证据与结论

以下五张均为本轮真实 Simulator Host PNG，已逐张通过 view_image 实看。不是 HTML 伪截图，也不是无关实验样品。运行的是生产 GameUI 的 fixture，先导出解析后控件树，再由现成 sim.mjs 转成无脚本静态 save 渲染。每张回执均为 manual / frame 0 / time 0，画布 pc-16-9 1600×900；不能据此证明动效、手机触控、官方导入/ready、GPU FPS 或发布验收。

| 截图 | 本轮可确认 | 未完成/限制 |
| --- | --- | --- |
| [select.sim.png](select.sim.png) | competition-two-act 仅旅行者，显示岩、余烬之心、10张初始牌组与开始冒险；文字和操作区无裁切 | 右侧为“肖像待补”，但本fixture没有装配platform.portraits及官方Avatar/BattlePortrait模板；只证明fallback布局，不能判断当前已批准候选肖像是否完成 |
| [select-deck.sim.png](select-deck.sim.png) | 10张卡完整排入两行，费用、名称、类型、效果和返回入口均可读 | 卡图/部分装饰纹理缺失，红框为模拟器缺素材占位 |
| [owned-relic-detail.sim.png](owned-relic-detail.sim.png) | 持有遗物1件、效果“战斗结束时，回复6点生命。”与关闭按钮可读 | 生产树含“余烬之心”名称，PNG未绘出；需区分模拟器文字框渲染问题和官方实际表现，不能认定此项视觉通过；图标缺失 |
| [card-detail.sim.png](card-detail.sim.png) | 普通攻击当前费用/效果、“打击类”关键词说明、翻页/返回说明与升级预览入口可读，无正文裁切 | 该样例未显示显式来源行，不能证明所有来源信息已完成；背景部分纹理缺失 |
| [exit-confirmation.sim.png](exit-confirmation.sim.png) | 退出后进度无法恢复、平台结算及继续/退出按钮清楚，无正文裁切 | 底部4级存档说明为灰字，当前可读性较弱；未据此改主题 |

PNG 缺纹理不是无警告成功：完整 `assetWarnings` 保留在各 `*.sim.receipt.json` 和 `metadata.json`。当前OSS纹理域名经环境代理的 CONNECT 返回 **403 Forbidden**（`oss-policy.txt`），模拟器回执报 `fetch failed`；没有绕代理、伪造图片或删除警告。该限制导致红色缺素材框，无法验收最终美术质量。

持有遗物名称诊断：解析树 `relicPanel/row1/name` 可见，文本“余烬之心”，24px，框290×32，位置(-30,+26)，颜色#F5D79A；效果为14px。未在无官方截图的条件下猜测性修改生产布局。

## 装配边界核查

`F.GameUI.new` 的包装只补充 `withMonsterActors`；本入口显式platform只有campaign/profile/seed/imageSource/color，没有 `portraits`。`abyss_character_select_view.lua:141` 仅在 `platform.portraits:status().selection` 为真时认为原生肖像就绪。因此“肖像待补”是本次fallback装配结果，不是正式候选缺肖像的证据。未运行生产bootstrap和可选官方Avatar/BattlePortrait模板。背景和卡面也按本次解析树/纹理警告判断，不能外推为全部正式美术装配验收。

## 复现

仓库根目录执行：

```sh
npm run build:data
npm run build:ui
node docs/evidence/m3-visual-20261031/capture.mjs
ART_LAB_MCP_ENTRY=/workspace/cloud-tools/m3-sim-runtime/node_modules/beyond-simulator-mcp/dist/index.js node experiments/ui-polish-sim/sim.mjs docs/evidence/m3-visual-20261031 select select-deck owned-relic-detail card-detail exit-confirmation
```

`capture.lua` 复用 `experiments/ui-polish-sim/select-capture.lua` 的真实控件遍历，增加实际选择旅行者、查看/关闭初始牌组、确认开局、打开持有遗物、点击卡牌详情与退出确认命令；无伪造Run状态。所有树、转换save、回执、PNG与入口哈希见 `metadata.json`；`host.log` 是本轮运行的解析树输出，`simulator.log` 是实际截图入口输出。模拟器安装在工具目录，未改项目依赖。未启动GUI、官方导入或发布，未跑重Lua测试，未操作Backlog。

结论：取得选角及两类详情等五张可对照真实模拟器静帧。文字布局部分有证据，但本导出未装配可选肖像模板、遗物名称未绘出、纹理策略阻断与官方设备证据缺失仍须保留为未验收，不能将TASK-59.3.1/4.7/4.8因此全部标完成。

## 后续诊断与日志格式

本轮“余烬之心”未绘出已定位为离线capture/simulator适配丢失autoSize，非生产布局改动；受控重绘及修正见`../m3-relic-name-20261031/README.md`。本目录原PNG/tree/save保留为修前证据。

为通过diff whitespace检查，host.log及oss-policy.txt仅规范LF、行尾空白与末尾单换行；全部原始字节另存对应`*.raw.gz`，metadata记录原文/规范文本/归档哈希。403 Forbidden及fetch failed证据完整保留，没有清除网络失败。
