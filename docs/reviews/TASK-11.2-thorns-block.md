# TASK-11.2：纠正荆棘绕过格挡

## 规则与范围

荆棘先消耗攻击者格挡，不足部分才扣血：20血/5格挡受3荆棘后为20血/2格挡；20血/2格挡则为19血/0格挡。仅修正这一规则，不改强度数值、生产JSON、999封顶、UI或平台实现。

TASK-11历史说明及旧测试把荆棘视为直扣血，该契约需纠正；原验收条款并未要求绕挡。历史说明保留，真实平台显示仍由TASK-11.1负责。

## 来源及限制

两份标注V2.3.4的第三方反编译镜像一致显示THORNS经过格挡，仅HP_LOSS绕过。它们不是MegaCrit官方源码，也未通过官方JAR认证；不能声称独立来源已获官方确认。未复制或执行镜像实现代码。

- [镜像A：荆棘伤害标记THORNS](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java#L44-L50)；[格挡仅排除HP_LOSS](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java#L158-L185)。
- [玩家扣挡入口](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1369-L1381)；[怪物扣挡入口](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java#L608-L625)。
- [镜像B：格挡仅排除HP_LOSS](https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/core/AbstractCreature.java#L164-L165)；[荆棘标记THORNS](https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/powers/ThornsPower.java#L41-L45)。

## 实现与验证

仅在Actor荆棘分支扣挡，再调用原directDamage处理剩余扣血。不重入攻击API，避免递归、攻击修饰及死亡防御者反伤被跳过。毒及directDamage本体未改。当前M1无独立HP成本API，不作该API的验证声明。

事件保持status_damage/status=thorns，amount仍是实际HP损失，全挡为0，不加字段。保留原攻击全挡/致死仍反伤、每击一次、无修饰、不递归、零伤害不触发、死亡中止及双方同死处理。

基于develop1217abb：
- 旧Actor下，纠正断言及4个新增组共5组失败；修复后31状态组通过。
- 系统Lua5.4共11文件、165组通过，已含14原子出牌组和31状态组；初次179统计重复计入14原子组，已按日志纠正。
- Python13项通过；JS语法、数据验证、数据/UI/主题生成及空白检查通过。
- 实际执行npm run check：JS123通过、7项因缺fengari-node-cli失败。受阻项为UTF8往返、六表Lua加载、Lua runner错误/超时、Lua套件发现/失败中止、主题Lua加载、真实game入口、map控制器导航。待具备依赖的正式CI验证。
- 无Fengari、官方编辑器、导入、真实屏幕或游戏实测通过声明。快照运行代码/测试与develop blob核对一致；未获取不参与测试的美术资产。

独立审查及远端CI完成后再集成；不覆盖平台布局和主题导出作者文件。

独立审查通过：2430个独立断言在候选全绿，旧Actor负对照459失败；另复跑状态31、战斗23、原子14、库存10组通过。TASK-11.2本地AC已勾，保持In Progress，等待正式CI和集成。
