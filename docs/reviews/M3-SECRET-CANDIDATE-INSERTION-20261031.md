# Secret Technique / Weapon 候选构造随机消费

基线为已合并 `b4f88a1`，独立树 `/workspace/m3-secret-random-insertion`。两张牌的真实同源缺陷，非测试新增冒充生产RED；没有修改冻结PR437、root工作树、Backlog或远端。

实际重新读取固定 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 SkillFromDeckToHandAction、AttackFromDeckToHandAction、SecretTechnique、SecretWeapon 和 CardGroup 共5文件，SHA256见独立fixture。两个action都按draw group原序遍历同类型牌并调用addToRandomSpot：首张不抽随机，后续按已有size-1的inclusive bound抽索引再插入；这不是把最后候选shuffle一次。两牌升级仅取消消耗，不取消候选构造。

旧实现eligible只收UID，两个以上候选没有任何对应消费；独立公共Run RED在2候选处报`secret candidate construction draws extra 1`。最初夹具曾错误地把默认显式floor1战斗当成experimental replay直接使用runSeed；该initial-stream不符只作为夹具错误记录，修正为独立runSeed+1后才取得上述真正生产RED，不混用。

最小生产改动仅11行：secret初次select调用source random insertion，结果UID序列直接存现有pendingChoice；eligible与choose保持纯成员校验，不在验证/读取时重抽；0候选仍由公开canUse拒绝，1候选不耗随机并自动入手。Purity/Forethought的筛选、选择及费用语义未改。没有改池、RNG原语、旧golden或预算，也没有复制原版方法体。

`sts1_secret_candidate_insertion.py`只复用独立Python XS128 Stream，不导入生产模块/采样器/本地牌定义；构造0/1/2/3/4候选的完整索引序、每次bound/value/双word/counter及前后状态。标准Run.obtainCard/upgradeCard/startCombat/play/chooseCard执行Skill/Attack与base/up四模式；仅将真实战斗副本按受控合法牌堆布置，未造UID/效果。非匹配类型不参与抽样，单张自动选择，多张按源序UID选取；非法UID/错误token/已完成旧token完整可变Run不变且不额外耗流，基础/升级准确消耗/弃置原实例。快照仅共享只读run.data，其余可变图独立复制。

八个薄正向JS入口分担20个公共场景，0–2/3–4两组明确分割；元数据核全部8入口精确注册与0–4完整原表，防漏/重。8/8通过零skip，单case约4.25–6.34秒，合40.69秒。先前单文件5场景约15秒（快照优化后仍10.69秒）明确超10秒整入口规划，因此拆分，而非调预算或删断言；每Lua调用仍30秒。最终hostedWindows时长另验。

另2项元数据/真实Git CRLF + 1精准负控共3/3通过，约1.36秒：原model/input原字节固定LF，实际clone控制文件确为CRLF而认证输入不变，严格再生通过；source key固定POSIX相对路径。精准变异仅临时模块副本省去第二候选的一次random insertion，必须在新`secret candidate construction draws`断言被拒，不接受任意异常。

原colorless_actions（含Purity/Forethought）通过；原39共享双版本78个实际play/选择/队列清空通过。39源身份+PR323+round3 catalog历史源守卫20/20通过；未出现真实历史逆层失败，不新增adapter/不改旧hash。一个额外直接PR323探针对未注册的colorless模块被拒属于原合同不接收该path，并非新漂移失败，未据此放宽它。

固定Luacheck1.2.0零新增，保21条显式历史warning、1138职责测量与原复杂度门槛；diffcheck及独立oracle再生通过。原始输出保存在外部`/workspace/cloud-reports/m3-secret-*.log`，外部报告补精确commit/文件SHA。作者外审查及最终组合完整CI仍需完成。

这是受控公共API与固定反编译镜像方法证据，不是自然取得、原版PC帧回放或官方客户端/设备验收；不宣称全部39依赖/153遗物/所有随机消费者完成。
