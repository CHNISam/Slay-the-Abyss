# 局内菜单的明确参照与适配边界

本轮只处理右上角游戏内菜单与标题“退出游戏”，设置页及设置选项仍不制作。

## 原版参照

- 已实际查看的截图：[Slay the Spire / Game settings](https://interfaceingame.com/screenshots/slay-the-spire-game-settings/)。这是标题设置页截图，证明遮暗背景、左下返回和右下退出的外观，**不是局内截图**；没有把整张截图嵌入原型。
- 行为和位置固定参照：[aeubanks/sts 的 319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。这是第三方 CFR 反编译镜像，**不是 Mega Crit 官方开源发布**。
- [TopPanel.java L530–630](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/panels/TopPanel.java#L530)：齿轮和 Escape 打开设置叠层；保留前一个地图、卡组等场景，而非直接返回标题。
- [SettingsScreen.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/options/SettingsScreen.java)：遮暗、隐藏战斗控制、返回按钮，退出及放弃有不同确认框。
- [ConfirmPopup.java L213–245](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/options/ConfirmPopup.java#L213)：局内 EXIT 返回标题；ABANDON_MID_RUN 结束该局。两者不能合成同一个“关闭游戏”操作。
- [MenuButton.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/mainMenu/MenuButton.java)：标题 QUIT 调用 Gdx.app.exit，退出程序。

## 本轮取用的具体布局

坐标从原版 1920×1080 按 2/3 映射到本原型 1280×720；以可点击区域为准：

- 放弃本局：[AbandonRunButton](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/options/AbandonRunButton.java) 右上，中心原 x=1430、y=OPTION_Y+340，区域 340×70。
- 保存并退出：[ExitGameButton](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/options/ExitGameButton.java) 右下，中心原 x=1540、y=OPTION_Y−375，区域 280×80。
- 返回游戏：[CancelButton](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/buttons/CancelButton.java) 左下，中心原 x=150、y=188，区域 300×100。
- [Settings.java L283](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/Settings.java#L283) 的 OPTION_Y=HEIGHT/2−32×yScale，在标准画布上为 508。

按钮使用 CSS 简化形状，文字使用现有可用字体；不冒称原版火焰位图、字体或完整设置页像素复刻。中央设置区按用户要求留空，不补假开关。

## 当前浏览器行为（2026-11-05）

- 地图、战斗、卡组、起始页共用局内叠层。打开不重建当前场景，底层不可操作，关闭恢复原焦点。取消退出/放弃只回菜单，不改游戏状态。
- 参照原版的右下按钮位置，但按项目实际能力改成“退出本局”，不提供保存或继续。退出/放弃均再次确认，结束当前原型挑战并显示失败结算；取消继续当前场景。
- 地图、战斗、祝福快照仅在当前页面内存保持。刷新、离开后不能恢复，历史 localStorage 进度不再读取。
- 商店、营地、事件、奖励仍是独立样例，不能据此验收正式房间规则。
- 主菜单退出尝试 window.close；页面仍存在时显示手动关闭提示，不伪造“已退出”。[MDN 的窗口关闭限制](https://developer.mozilla.org/en-US/docs/Web/API/Window/close)。
- 正式游戏的结算提交与离开由平台负责；网页只演示入口，不会提交战绩。创作者 Lv.4 存档限制说明沿用项目原文，见 [结算参照](RESULT-REFERENCE.md)。
