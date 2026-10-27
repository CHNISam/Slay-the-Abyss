# 决斗事件

依据：`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 `TheJoust.buttonEffect`、`AbstractPlayer.loseGold/gainGold`、`Random.randomBoolean(float)` 与 `AbstractDungeon.getShrine`。逐文件字节身份见 `tests/fixtures/joust-source-contract.json`。只独立实现行为，不分发上游代码或图片；该镜像不是认证的 PC 二进制运行证据。

现状差异：事件已在原一次性池中，资格限定第二幕且至少50金币，但没有执行器或内容映射。新增 `abyss_joust_event` 保持五个独立页面：靠近、下注、确认开战、显示结果、离开。下注先支付50金币；确认开战才使用 `miscRng` 一次 `randomBoolean(0.3f)`；下一页才支付100或250金币。所有下注方向共享同一胜负概率，不重抽。赔率是奖励总额，已支付的50金币不会再加回。金币获取沿用永久钩子，保留 Ectoplasm 拦截；事件支付不触发商店消费钩子。

资格只在抽取时检查。原按钮在页面上不再按当前资金禁用；若中间资金变化，支付沿用原 `loseGold` 的零下限。模块不修改原池、顺序、资格或默认受限模式。事务由既有 Nodes/Run 包装，失败回滚后从同一页面重试，不重新决定胜者。

定向回归：五屏与非法/重复/UID输入、64个真实种子与下注组合的阈值/流状态、陈旧资金、Maw Bank 不失效、Ectoplasm、发金币后异常的全部状态回滚。正式入口接线由主session负责：Act2Events 的 ids/prepare/options/choose 委派，EventPool 的 `The Joust`→`joust` 内容映射，NodeUI 的显示名与架构 core 分类。尚无官方导入、客户端动画/音效及自然四职业实机证据，不将本切片视作完整事件池验收。
