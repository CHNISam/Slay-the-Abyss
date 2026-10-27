# 手柄支持实施计划

> 按已确认方案 1 执行；使用 executing-plans 技能逐项实施，主线程串行完成。

**Goal:** 复用千星奇域原生导航，尽可能让手柄操作完整主流程，无设备时保留明确实测边界。

**Architecture:** 使用平台已有的 Focus/Confirm/Cancel 导航事件和焦点 API，接入现有命令入口。焦点只在当前有效页面和弹窗内活动。对照初代固定反编译镜像的手柄交互，迁移离散选择、取消和焦点恢复规则；平台接口适配单独记录。

**Tech Stack:** Lua 5.3、千星奇域客户端控件、Node 原生测试、Fengari。

## 1. 来源与能力

- 核对官方 `mhtakr07vej4`、`mhbgxf0nynww` 和 `mhjobxrdykym` 的导航事件、焦点及隔离规则。
- 读取固定镜像的 `AbstractPlayer`、`CardRewardScreen` 和地图输入，记录方法、内容 hash 与移植边界。
- 不更改战斗规则，不引入其他引擎的设备驱动。

## 2. 原生适配

- 新增 `src/lua/abyss_controller.lua`，提供当前页面注册、确认取消、默认/恢复焦点及导航路径。
- 在 `abyss_ui.lua` 提供真实导航枚举与焦点 API；在各 UI 模块绑定既有业务动作，保留指针所有权防护。
- 在布局生成器隔离弹窗，复用共享主题显示导航提示。

## 3. 行为验证

- 先增加 `tests/lua/controller.lua`，验证菜单、地图、战斗选牌选敌、奖励、营地商店事件、弹窗返回、禁用/隐藏及重复事件。
- 增加必要的布局契约测试，核对所有目标与原生控件容量。
- 运行 `npm run build:ui`、相关 Node/Lua 测试和 `npm run check`；失败先定位，不降低断言或提高时限。

## 4. 交付

- 在 `docs/backlog-details/TASK-40.md` 记录实际实现、复用来源、测试与缺失实机证据。
- Backlog CLI 更新原任务，保留真实手柄验收未勾选；核对 diff，提交功能分支及 PR。
- 未取得本轮输入时间窗口，不启动官方客户端、导入或自动试玩。
