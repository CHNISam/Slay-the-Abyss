# 两张无色攻击的伤害文字修复

独立基线 `6152bb7c`。先运行专用 `colorless_attack_display.lua`：28例中26例RED。真实出牌伤害正确，但Ritual Dagger的永久misc=31仍显示15；Hand of Greed有4力量时实际伤害24、卡面仍20；两者没有对应的伤害预览条目。

本片只改显示链：Combat.cardPreview为这两个colorless攻击复用既有Actor伤害计算；Colorless.describe把伤害变量与固定金币／成长值分开；CardDisplay.format的两牌专用damage字段委派现有伤害数值格式化，沿用颜色及箭头，不增设全局数字系统。非战斗仍由现有Combat.cardDefinition读取永久misc。没有改实际出牌、金币、成长、Mind Blast或非法effects防护。

同一专用fixture修复后28/28通过，原30秒时限不变：两牌基础／升级版本，永久卡组文字与战斗文字，力量、虚弱、易伤、无实体，预览与真实Combat.play伤害一致；Dagger击杀后misc文字更新且成长仍3／5，Greed击杀金币仍20／25。用例为受控离线战斗，未进行平台导入或实机显示验收。

额外相关检查：既有 `colorless_presentation.lua` 的78版卡面、状态说明及真实UI无实体预览回归通过；Luacheck 1.2.0无新增诊断（111条历史warning原样保留），架构132模块／656边通过。未运行全矩阵、完整Quality或平台。
