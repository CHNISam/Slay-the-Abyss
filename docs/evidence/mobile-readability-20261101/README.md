# 手机字体与渲染写入修复证据

基线：develop `2d06741de47f2a65eb2772705e33064c16ccdce3`。最终代码切片：`04e3a75e406341b78db0205864535173c526915f`；后续说明与Backlog提交不改变该代码。任务为TASK-4.20（High）与TASK-4.21（Medium），状态保留In Progress。

## 结果

默认正文24、标签22、提示20、HUD与完整阅读28设计单位；面板标题34、主页44。文本框、分页与必要的底部间距随之调整，关键字不再自动缩回14。小卡面保留14/15，已有完整阅读入口另用28。重要不透明按钮文字296组独立对比检查均不低于4.5；这不是完整WCAG AA认证。

最终整合的300次离线更新：地图尺寸15000→1200次，保留呼吸变化；战斗意图文字、图片重复提交各300→0。写入失败、跨地图或控制器共用原生控件的两项审查拒绝已修复，原报告和RED保留。调用数不是手机FPS、P95或加载时间。覆盖页actor重建、真实冷载及玩家卡顿的完整原因仍未确定。

Root相关组合53/53、末尾奖励标题增量22/22通过，存在重叠复跑，不合称75项独立测试；最终缓存10+3场景、工程检查、四项断言变异、原生UI替身合同、语法、普通平台负载与任务检查通过。静态保留21条历史Luacheck诊断，没有新增豁免。正式候选容量、官方导入、ready与设备验收均未执行。

## 文件

- 字体根因、实施、兼容性与非作者审查：`mobile-font-*.json`。主报告最终绑定04e3；31项验证属于parent66db，最后2项属于child04e3，未重标来源。
- 性能调查、修复与非作者审查：`mobile-loading-*.json`。作者12e与1cb的changes_requested历史及全部原始脚本/日志在`raw-diagnostics.tar.gz`，清单逐文件记录原始字节与SHA256。
- `author-sources.json.gz`保存原作者提交对象和patch；根整合使用线性cherry-pick，源码身份没有改写为候选或实机结果。
- `render/before`、`render/intermediate`、`render/final`保留真实Host替身状态和浏览器文本检查。中间66db奖励标题裁切、一次挪位草案触发原悬停碰撞断言的失败日志均保留。最终采用面板title34与48高框，原卡牌位置、面板位置、遗物栏及悬停间距不变。
- `map-before-after.png`为离线缩放对照；最终9个场景均无浏览器裁切标记。图库以原型字形替代、字体为系统Noto，844×390是模拟画布，不能称实体手机截图或实际pt/dp。
- `manifest.json`认证本目录实际文件字节；`.gitattributes`保留跨平台原字节。日志中旧预览器不兼容新actor绑定/选角序列的失败没有冒充产品运行失败或成功，外置驱动使用当前正式选角命令后捕获Host。

## 验收边界

字体任务仅AC1、3、4有本轮证据；AC2的999压力覆盖不能证明所有合法自然最大值，整条未勾。AC5真实设备、阅读距离、字体单位、200%放大与完整标准达标均未证实，未增加独立200%设置。性能任务AC1、2有离线证据，AC3实机不勾。

背景、美术映射、声效、动效、卡牌与战斗规则均不改变。High队列保持5项：原TASK-16.1仅剩实际游戏记录，按用户新增优先级移至Medium并保留全部旧验收和说明。当前普通PR通过不构成发布许可。

依据：[游戏无障碍默认字号](https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/)、[WCAG文字对比度](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)、[WCAG文字放大](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html)。
