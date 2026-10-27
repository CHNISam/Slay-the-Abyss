# PR259 原覆盖测试进程拆分

失败来源为 Quality run `40554896966`，精确head `b420e8b267bbdbf2d5d7c68bc7d893faa130047c`、base `d16be8db337656f50b1bccabc1436044b00dd4bb`、attempt1。真正失败的是rules(1/8) job `122368790687`；最初提供的rules(5/8) job `122368790834`实际成功。全作业18分30秒，Lua步骤15分08秒；不是作业超时。

原日志290421字节，SHA256 `850995db62eba34a9984096768e1fb59725c9a6a32615c8e35c92dffa8b0e2ce`，保留于执行树`build/pr259-ci-40554896966/rules1-raw.log`。GitHub日志CLI的存储请求返回EOF后，使用同一只读签名地址的有界HTTP1.1下载成功，未修改远端。

日志1997行：held25次完整UI构造的单fixture触及30000ms，实际报告30067ms。2267行：结束回合/卡牌选择奖励回滚六例单fixture触及30000ms，报告30047ms；原日志已有turn/choice的throw/reject及retain/throw共5例PASS，retain/reject未完成。没有业务断言FAIL。随后必要本地覆盖也证明原released25次UI构造会触及30000ms（30099ms、只输出19次fresh setup，完成的内部case数未知），因此一并按相同机制拆分。

held/released分别按原5控件拆为5份，每份仍遍历全部5种变更，总共保留原50场景。每场仍创建完整生成UI和seed42奖励。回滚按turn/choice/retain拆为3份，各保留throw/reject两例；种子42、Cultist52HP、真实牌/药水获得、原命令、完整对象图及引用校验、RNG和重试/控制组比较均不变。

轻量机器守卫通过精确逆转换还原原held/released/helper/rollback四份完整源码SHA；额外反例确保修改seed或移除verify会破坏原hash。原入口分别负责第1个控件或turn，新wrapper负责其余输入；文件自动发现与JS包装均核对全部13份原覆盖恰好一次。每fixture仍为原30000ms，没有修改生产源码、mock、工作流、预算、断言或正文种子。

守卫先真实RED，再通过。最终结果分两次有界执行：首次held5份和rollback3份全部GREEN；保持原released文件时真实超时。完成released5份拆分后只补这5份及两项静态守卫，不重跑已绿8份。具体耗时见结构化证据`docs/evidence/pr259-fixture-budget-40554896966.json`；这不是一次最终完整Quality通过，新SHA完整CI及交付仍由父线程执行。
