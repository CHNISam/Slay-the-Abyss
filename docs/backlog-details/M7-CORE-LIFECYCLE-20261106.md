# M7 核心生命周期切片（本地验证，待集成）

本批承接 TASK-74.20 的六职责出口，源码基线为 `dedb9ed5af52fc595031d64d3e8fd84bc908b2c8`。任务登记、审计及 Owner 指定的“架构→多agent协作→速度”顺序由 PR521 承接。核心切片先在独立树保存为`c48b6a35`并精确独审通过，再通过原入口暂停并读回PR521，将代码线性并入同一批次，减少串行Full与基线前移后的重复验证。旧候选CI保留，不作为新HEAD通过证据。当前尚未交付，不勾任务验收。

## 职责与验证边界

Actor 按状态应用、Power 生命周期和回合收尾分阶段治理；PowerRules 叶模块只提供无外部依赖的校验与堆叠值计算，Actor 仍提交状态和发出事件。Combat 按伤害协调及抽牌跨堆、钩子分阶段治理。保持原公开 API、动态方法读取、状态 owner、表/函数别名、随机流、事件次序、返回与错误、暂停及失败回滚。Combat 仍为2271行，不将本片提取冒充整个依赖环或超千行模块已解决。

实现分为 Actor、Combat 两个源码写入范围；各自冻结完整旧源并使用独立 VM 对照。公共静态门禁、历史来源接线和最终集成统一负责。生成数据只由一个执行者构建；不在每路重复运行完整检查。

## 已取得的本轮证据

- 固定 Luacheck 对原六入口真实报告 CC33/36/35/50/34/33，准确命中新加 CC15 门禁；原始输出为 `build/core-lifecycle-static-red.log`。
- 新增门禁测试先以 `M.status` 未受约束的真实断言失败，接线后与既有职责合同共17项通过。最初沙箱 `spawn EPERM` 单独保留，不计作语义红基线。
- Actor最终独立VM差分、真实函数共享引用/元表/错误对象及6个可解析语义变异通过，最终5项专项在`build/actor-lifecycle/rules-final.log`；先前存活负控及LF/CRLF身份问题已修复并保留原记录。相关Node6项、owner-end8组及native-expiration5组通过。
- Combat完整旧新差分、双旧Actor+Combat→双新owners、对象/函数错误及4个具名解析语义变异通过，最终4项在`build/combat-lifecycle/final-sensitive.log`；原draw/potion各15组、sharp-hide及24项相关JS通过。旧owners前置失败、观察器错误对象/元表漏观测和曾存活变异均保留；最终控制组必须先成功，变异必须命中具名行为断言。
- 六入口当前CC：Actor status/applyPower/addStatus/endTurn为7/9/8/6，Combat damage/draw为4/8。Actor996行、PowerRules62行，完整叶模块全部函数及初始化块受CC15约束；Actor与叶模块1000行门禁及纯叶反向依赖门禁先红后绿，24项门禁专项通过。15条历史告警保持，无新增。
- 主控工程采集329模块、5314/5314测量，架构329模块/1903依赖位置通过；4个关键变异全部被断言杀死。首次原生合同6项因独立树缺生成主题失败，保留`build/core-lifecycle-engineering.log`；生成标准theme/UI/layout后，仅补验失败合同6/6通过，见`build/core-lifecycle-native-contract.log`，未重复其余工程阶段。
- 历史来源适配提升至`preGameUiExtractionSource`公共入口，新增Actor/Combat/PowerRules/config四源新鲜验证及精确配置逆投影；叶模块只作关联证据，不伪造旧源。最终core4、GameUI13、compendium6、reaction3、LivingWall4、architecture格式3、deck3、preparation3、freshness3、pr372 2、pure cache5及composition格式2项均通过。最后一项耗时152.5秒，未视为速度收益。保留旧epoch精确98/30读取断言，新epoch计入四源后严格162/46；布局等价、重复键拒绝、暖漂移及注入reader失败合同保持，旧golden不更新。
- Full会自动发现的三个新增Lua原始入口均在原30秒/1MiB限制下通过。最初Actor完整图输出触及ENOBUFS，失败保留`build/core-lifecycle-raw.log`；raw默认仍执行全部121步及图遍历，只输出25字节结果。JS双VM driver显式开启完整trace，并断言14个完整检查点、函数定义和重复引用；最终raw复核见`build/core-lifecycle-raw-final.log`，差分/传输复核见`build/actor-lifecycle/raw-transport.log`，未提高预算或移除断言。

[机器指标](../evidence/m7-core-lifecycle-20261106.json)绑定全部329份LF源码摘要：CC>30为67→61，CC>15为258→252，最大CC仍75。未治理热点不视为已接受风险。

原始日志及报告归档在根工作区`.artifacts/m7-core-lifecycle-20261106/evidence-546a733e-d841-4ffe-94eb-621966f3c96f.zip`，2639485字节，SHA256为`95b02130cbbeada18e3ea3e62089ea27ba9523af5f9341208d6c11cc193714a6`；不将另一个工作树的生成运行时输入用于本树测试。原始`c48b6a35`分支及PR521集成前Git bundle保持可恢复；精确组合独审与托管Full按最终HEAD另验。

## 仍须完成

最终精确提交独审绑定、托管来源及队列和实际合后Full仍待。任何局部通过均不代替这些要求，TASK-74.19/74.20保持未完成。

本批尚无新官方候选、导入、ready、容量或设备证据，不作性能提升声明。
