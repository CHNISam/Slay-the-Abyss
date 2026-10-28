# 正式开局与角色选择

本轮只负责主菜单至确认冒险，不改卡牌数值、战斗核心或章节开放规则。任务状态以 Backlog CLI 为准。

## 原版依据

固定阅读版本：[aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。这是用户指定的反编译研究镜像，不作为第三方代码或美术的复制来源。

| 阅读文件 | 迁移的行为 |
| --- | --- |
| screens/mainMenu/MainMenuScreen.java | 主菜单与选角页的独立输入范围；转场清除点击；手柄左右角色导航 |
| screens/mainMenu/MenuButton.java | 启程只打开下一页；隐藏菜单清除悬停；手柄确认消费本次输入 |
| screens/mainMenu/MenuPanelScreen.java | 正常冒险进入角色选择；返回恢复上一页 |
| screens/mainMenu/MainMenuPanelButton.java | PLAY_NORMAL 只打开选角，不创建游戏；本作省略未实现的每日与自定义模式页 |
| screens/charSelect/CharacterSelectScreen.java | 未选中不能确认；返回清除选择；最终确认先禁用重复输入，再初始化开局 |
| screens/charSelect/CharacterOption.java | 点击只改变单选、高亮、肖像和详情；手柄聚焦可改变选择 |
| screens/CharSelectInfo.java | 初始信息来自真实 loadout；同种初始牌按数量归并 |

独立实现保留本项目原生按钮、主题、输入代次和 Controller 适配，没有复制 Java 实现或原版美术。因为这里只有正常冒险，启程直接进入选角，返回直接回主菜单。

## 数据与状态

- 五个入口：胡桃、阿蕾奇诺、芙宁娜、雷电将军、旅行者·荧。旧 experimentalCharacters/originalCharacters 参数不能再使两组入口互斥。
- 四原创角色的初始信息读取 abyss_original_v4_profiles.prepare 适配后的真实数据，底层仍为 data/original_v4/rules_v4.json。
- 旅行者默认岩，不改变当前正式默认 Run 的数据路径；风、雷、草复用 abyss_run_card_catalog.prepareSelected。内部实验兼容参数只用于既有职业工厂，不显示给玩家。
- abyss_character_select 只有选择和只读预览，不依赖 Run/Map 或种子。生命、金币、遗物与初始牌数量均来自现有数据和中文展示适配。
- abyss_game_ui.start 只打开选角；selectCharacter/selectElement 只更新选择；confirmCharacter 才进入唯一的 Run.new 路径。确认前设置重入闩，成功后关闭选择页，重复确认失效。
- 返回清空选择；选择、切换元素、关闭、重开和缩放均使旧按钮手势代次失效。保留 click-only 平台备用；原生指针采用既有 Down/Up/Click 与触点身份，手柄采用已消费确认和独立作用域。
- abyss_ui 不再读取实验角色开关决定入口。正式构建总是带 characterPanel 和 choicePanel，旧自制序章不装入布局、不创建运行时控制器、不播放；历史模块/文案仅保留作溯源和退役负例。
- 既有 Neow 历史未知时明确显示不可用原因，再走既有合法地图入口；本轮不伪造历史、祝福、职业完成或章节权限。

## 美术与平台边界

布局全部从共享 ui_theme 读取，保持 1280×720、安全区、深岩灰蓝与琥珀金。角色详情、五个主入口和四元素行分层，初始牌组以名称与数量呈现，不另做卡框。角色肖像使用可替换的 icon.characterPortraits 注册项，当前明确写「肖像待补」，不把元素标记当作已完成正式肖像。

已有回归需要即时进入地图时，显式调用测试辅助 start/confirmStart，辅助只执行真实的打开、选择、元素、确认命令；正式开局与输入测试直接操作原生控件。原有战斗、地图、结算和负例断言仍保留。废弃序章的默认播放断言改为退役断言。

## 当前证据与待验

- 八种选择、真实初始数据对照、无提前建局、确认单次创建、全部原生入口和旧输入失效：12 项专项通过。
- 既有 Neow 5 项、错误恢复 6 项、结果手势 20 项及职业选牌/手柄专项已通过。
- 新增 Lua 静态检查无新增诊断，84 条历史警告保留；架构登记了两个 UI 模块。工程原生能力正负例通过。
- Node24.18.0 下 12 项呈现合同通过，原 79,475 条写入的值与全局顺序全部保留，新增 1,703 条逐项绑定；7 项冻结原文/原生控件门禁复验通过。旧哈希、原预算、全部原用例与负例保留，只精确逆转已声明的开局步骤迁移。
- 三组真实战败重开手势共 28 项通过，旧出牌、结束回合与药水输入不能作用于新局。快速 CI 已通过；完整 CI 曾实际发现旧用例迁移及冻结原文绑定问题，修复保留在同一个 PR，不把旧头失败改成成功。
- 完整回归、最新 develop/PR267 集成和原生副本读回仍在执行，未据局部通过宣称完成。PR267 最新已读头为 9bab0cfd，未修改其分支或声称其完整 Quality 已通过。
- 本轮未取得桌面占用窗口，没有官方导入、当轮 ready/日志或鼠标/手机/手柄实机证据；不借用历史候选认证本次界面。

免费模型已有明确限额反馈且重置窗口未知，本轮未启动 OpenCode 或子代理。所有实现与验收由主执行者完成，未声称测得额度节省。
