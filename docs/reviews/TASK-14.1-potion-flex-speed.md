# Flex与Speed药水的临时能力

基线 `6457b61f9f600178ad8279839243c82f52b772cd`，复用 TASK-14.1 / TASK-13.1 和33瓶目录。本片只实现两瓶基础A0药效，保持 `acquisitionPending=true` 和首发清单 exclusions；不改获取概率、完整原池、地图或卡牌奖励RNG。

固定镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`：SteroidPotion与SpeedPotion均为Common、自用、基础量5。各自先以ApplyPower加正Strength/Dexterity，再单独以ApplyPower加LoseStrength/LoseDexterity减益。Artifact不会挡正增益，可以挡第二次减益施加；若减益已存在后才获得Artifact，回合末实际负Strength/Dexterity施加也能被挡，延迟扣除能力随后移除，不在下回合重扣。

LoseStrength与LoseDexterity没有自设priority；AbstractPower默认priority5，compareTo只比priority。ApplyPowerAction对能力列表做稳定排序，AbstractCreature按此列表派发atEndOfTurn。因此两种延迟扣除必须保留首次加入次序；叠加已有同ID能力不将其移到末尾。晚获的一层Artifact会挡住先加入的一种实际扣除。永久能力的±999封顶不改变已施加的延迟扣除量5。

实现复用现有Flex牌的临时Strength记账，增补同语义的临时Dexterity与不可变首次次序列表；保留两参数raw Strength helper及原有Flex牌调用。库存只增加两种明确的临时stat操作，数据校验为新Dex操作登记相应status约束。战斗和商店说明只补文字映射：增加5、回合末失去5、临时Dex状态说明；不改布局。净stat恰好为零仍展示待扣量，避免隐藏单独存在的延迟减益；状态说明用“回合结束时失去”，不把大于净stat的扣除量误称为其中若干层。来源文件与验证记录见[专项证据](../rules/evidence/sts1-potion-flex-speed.json)。

准备阶段遵守父线CI资源暂停，明确释放串行窄窗口后才执行：两瓶缺定义/真实Run `unknown_potion` 红例2项；加入两瓶pending定义后2项JS绿，底下11组Run药效用例通过。另单独运行新UI2组、既有Artifact19组与Flex牌16组，共48组Lua断言通过，无超时。新UI首次失败为测试误读按钮父控件text，改读既有normal/label后通过；没有为通过改变药效。绿例目标报告耗时合计约14.8秒，全部测试尝试的已报告耗时约19.1秒；不包含CI等待、工具启动或清单门禁，实际CPU时间与费用未知。

没有完整构建：只生成本树data/theme单模块，UI用例复用既有静态布局/模板/展示缓存并登记hash；不是本片平台构建或实机证据。首发清单门禁通过，正常可获药水数仍6。PR197在父线增加的P12独立预期表不在本分支：后续整合必须把`flex_potion`/`speed_potion`的self策略和pending=true加入独立表，不能放松数量守卫；本片未cherry-pick父线新增改动。

保留边界：Sacred Bark翻倍、完整33瓶源选择、未来用药/清除任意减益等遗物组合、平台导入/实机与UI验收均不在本片通过结论中。不能把pending排除带进正式源池跳过/重抽。没有full check、GUI、push、merge或Backlog正文修改。
