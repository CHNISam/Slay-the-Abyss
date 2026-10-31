# TASK-89：正式缓存肖像的失败恢复

2026-10-31，基线 PR432 `89349b1fd3b0b01b5d02203b8a9c7b37d6f3e2a3`。该基线尚不包含独立 PR433 的黄色 placeholder 回退守卫，本切片只修改缓存失败恢复。

## 确证缺陷与最小修复

正式 `build-ui` 写出 `art-render-v2.json`，`writePortraitModule` 据此输出 `runtimeV2=true,cache=true` 的战斗立绘。控制器遇到原生创建或 setter 拒绝时进入 `failed`，隐藏正式宿主并清理其图元。但 cached `pause` 只隐藏宿主，保留 `failed`；下一战 `begin` 拒绝失败状态，正式形象永久无法重建。原有失败恢复用例生成的是未缓存旧版资产，未覆盖正式候选配置。

本轮使用实际生成的 runtimeV2/cache 战斗资产和真实肖像控制器注入单次 `InstantiateClientUIControl=nil` 或尺寸 setter 拒绝。修复前两项都失败于 `cached failure stranded formal portrait in the next battle`；同一战反复刷新不重试，转地图再进入战斗仍失败。

战斗肖像适配器显式启用控制器选项 `retryFailedOnPause=true`，仅该实例在 `pause` 发现 `failed` 或 `release_failed` 时走现有显式 `release`。下一战重新构建；成功、构建中或揭示中的缓存仍保留。选项默认关闭，背景、选择肖像及其它共享控制器保留原有缓存失败策略。不增加逐帧重试，不放宽原生模板或容量合同。另验证正式形象已 ready 后 pose setter 失败，下一战也能恢复；正常缓存下一战不重建。

## 真实组合轨迹与设计边界

新增 `official_portrait_game_lifecycle.lua` 使用真实生成UI/主题/正式4315图元、真实 `GameUI`、`Run`、战斗出牌和敌人死亡反馈：

1. 初战正式肖像 ready，hero/figure 及其原生激活层次可见。
2. 真实打出重击，经过敌人死亡演出；全部正式图元继续存活，图像ID与原有颜色对象不变。
3. 奖励页 `mode=battle`，正式控制器继续 ready，figure 本身继续可见；`renderHudVisibility` 主动隐藏整个 hero 父控件。
4. 前往地图只暂停宿主，不销毁成功缓存。
5. 下一战立即恢复 hero/figure 的最终可见性及激活层次，不重建图元。

奖励页隐藏 hero 不单独判为资源丢失：[UI_DESIGN](../design/UI_DESIGN.md) 约定中间640×460奖励面板，批准原型 `renderReward` 只构建背景、顶栏、遮罩及奖励面板，没有战斗角色。此切片不新增奖励立绘布局。

## 本轮证据与未完成项

- `npm run check:architecture`：通过，316模块、1817依赖边、0错误。
- `node --test --experimental-test-isolation=none tests/official-portraits-lifecycle.test.mjs tests/official-portraits-flags.test.mjs tests/official-portraits-equivalence.test.mjs tests/official-portrait-game-lifecycle.test.mjs`：25/25通过，25.50秒；本树 `build/portrait-lifecycle-tests.tap`。
- 创建失败、setter失败及ready后pose失败的正式缓存恢复；同战不重试；成功缓存不重建；旧版资产与单独旗标；逐图元属性/顺序等价；真实GameUI完整切换均覆盖。构建工具只生成隔离临时夹具；复用本机已有依赖，没有客户端输入。

这证实“正式肖像失败后跨场景不能恢复”的源码缺陷，不证明该故障在用户设备上实际发生，也不解释原报告约90%的复现率。正常真实组合轨迹离线没有复现正式资源丢失。未做全CI、候选写入/读回、官方导入、真实ready或PC/手机复测；TASK-89两项验收继续未完成。需要同候选实机记录 `ABYSS_PORTRAIT battle phase/owned/reason`，连同宿主/hero父级的可见性、激活和alive，才能把原报告与此失败路径关联。

## 2026-11-01：共享控制器回归修正

PR435 完整CI的 Windows rules4 job124592066286 捕获原修复扩大到背景缓存：`official_background_errors.lua:24` 要求失败彩蛋重开不重试，但共用 `controller.pause` 把背景也从 failed 改为 released。先前25项定向验证遗漏背景调用方，不能证明共享控制器变更安全。

在精确干净基线 `690a4a5797a6973985f04bf2c4e8f2136b848f8e` 的独立树先运行原背景flow/errors，复现同一失败及 failed→released→failed 日志。现将恢复限制为默认关闭的控制器选项，仅战斗肖像实例启用。原背景测试与原战斗缓存三项断言均未修改；新增正式缓存选择头像失败重开仍不重试的回归，防止把非战斗适配器误设为恢复策略。

本轮 Node24.18.0 定向组合：`node --test --test-isolation=none tests/official-background-flow.test.mjs tests/official-portraits-lifecycle.test.mjs tests/official-portrait-game-lifecycle.test.mjs`，26/26通过，24.94秒；日志为本树 `build/portrait-retry-scope-tests.log`。`check:architecture`通过，316模块、1820边，diff检查通过。仍无本轮官方地图/ready/设备/发布证据。
