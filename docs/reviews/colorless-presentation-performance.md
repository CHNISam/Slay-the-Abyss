# 无色牌整合后的完整呈现测试耗时

基线：`d2e6b630`，项目便携Node24.18.0。原`tests/lua/character_presentation.lua`保持不变，Windows工作树字节SHA256为`22aaced771b84d2a5650941cbccd1764539038bec518d4ed09ce3fac5dfd154e`。全程保留30秒预算、原16组、全部640基本/升级渲染变体与原门禁；没有拆分、删除断言或跳过内容。

只读探针包装生产边界并执行同一完整fixture。超时前已完成第三职业时，Combat.new调用454次，累计16.598秒；共享copy调用6762次，累计10.739秒；Colorless注册457次，累计4.104秒；真实BattleUI.render454次，累计3.479秒；文本呈现准备仅累计0.155秒。这些计时互相嵌套，不能相加。墙钟运行之间存在波动，因此不把单轮差异归因到某一行代码。

修复限于两个已定位的复制开销：

- 共享graph copy直接传递标量字段，只对table递归；环、共享节点、原table key、外部memo、legacy assert调用和Combat.copy公共函数身份保持原契约。
- Combat.new在Colorless注册返回新私有bundle时直接接管其已深复制的来源池；注册前的源输入、已注册调用者输入以及其他战斗仍相互隔离。新增双输入/双战斗修改回归验证这一点。

结果：插探针的完整运行23.612秒；随后不插探针的原fixture完整通过，20.620秒，输出`CHARACTER_PRESENTATION_PASS 16 rendered_card_variants=640`。运行命令仍是项目既有`node scripts/test-lua.mjs tests/lua/character_presentation.lua`，仅进程级PATH选择项目Node24，不改系统Node。

相关回归：copy_graph、colorless_run及Combat23组通过；Luacheck零新增诊断、architecture与diff检查通过。原测试文件、runner与超时配置均未修改。父线程仍须在最终整合SHA运行完整Quality，本切片不替代平台或实机证据。

本地原始探针/失败/最终日志保存在该独立树`.artifacts/presentation-performance/`，未将机器相关临时输出提交仓库。
