# 无色牌整合后的完整呈现测试耗时

基线：`d2e6b630`，项目便携Node24.18.0。原`tests/lua/character_presentation.lua`保持不变，Windows工作树字节SHA256为`22aaced771b84d2a5650941cbccd1764539038bec518d4ed09ce3fac5dfd154e`。全程保留30秒预算、原16组、全部640基本/升级渲染变体与原门禁；没有拆分、删除断言或跳过内容。

只读探针包装生产边界并执行同一完整fixture。超时前已完成第三职业时，Combat.new调用454次，累计16.598秒；共享copy调用6762次，累计10.739秒；Colorless注册457次，累计4.104秒；真实BattleUI.render454次，累计3.479秒；文本呈现准备仅累计0.155秒。这些计时互相嵌套，不能相加。墙钟运行之间存在波动，因此不把单轮差异归因到某一行代码。

修复限于两个已定位的复制开销：

- 共享graph copy直接传递标量字段，只对table递归；环、共享节点、原table key、外部memo、legacy assert调用和Combat.copy公共函数身份保持原契约。
- Combat.new在Colorless注册返回新私有bundle时直接接管其已深复制的来源池；注册前的源输入、已注册调用者输入以及其他战斗仍相互隔离。新增双输入/双战斗修改回归验证这一点。

结果：插探针的完整运行23.612秒；随后不插探针的原fixture完整通过，20.620秒，输出`CHARACTER_PRESENTATION_PASS 16 rendered_card_variants=640`。运行命令仍是项目既有`node scripts/test-lua.mjs tests/lua/character_presentation.lua`，仅进程级PATH选择项目Node24，不改系统Node。

相关回归：copy_graph、colorless_run及Combat23组通过；Luacheck零新增诊断、architecture与diff检查通过。原测试文件、runner与超时配置均未修改。父线程仍须在最终整合SHA运行完整Quality，本切片不替代平台或实机证据。

本地原始探针/失败/最终日志保存在该独立树`.artifacts/presentation-performance/`，未将机器相关临时输出提交仓库。

## 2026-10-27 整合基线复验

新基线`66b261b3`独立工作树、offline依赖和独立数据/UI构建后，原fixture仍在30秒超时，输出前三组完成。原fixture字节摘要仍与上文相同。当前C.new额外为每个战斗复制/注册第二幕敌人及状态；完整边界探针记录649次C.new累计17.471秒、24674次共享copy累计10.943秒、653次Colorless注册累计4.637秒，而31次呈现文本准备仅0.986秒。计时嵌套，不相加；这证明初始化/复制值得优化，不将超时推断成机器负载问题。

同一进程实际来源图的三轮对照，每轮50次复制且校验环与共享节点：原copy耗时0.5512/0.4884/0.4790秒，等价静态visitor为0.4750/0.4346/0.4308秒。只将这一已验证的改进用于共享copy，保留原keys、memo及legacy API契约。

本轮其余优化只处理可证明的重复初始化：

- Colorless静态来源桶在模块加载时排序一次，每次注册仍深复制私有图；使用共享graph copy代替自身对全部标量递归的复制器。
- C.new只接管本次新注册且尚未逸出的无色牌/状态图。原有调用者定义继续复制；第二幕目录照常保留私有副本。
- Run.new在角色factory已经深复制整个输入后接管其私有结果；默认和未选角的调用者数据仍深复制。

只做Colorless/Run优化的中间轮仍超时，失败日志保留；最终原fixture不插探针完整通过，24.691秒，16组/640变体，30秒预算和全部断言未变。`initialization_isolation.lua`覆盖默认、未选角、四原版与四原创角色共十种模式，以及新注册定义、静态桶、第二幕目录和冻结V4规则/raw数据的跨运行私有性；原copy_graph及来源RNG八组回归均通过。Lua静态零新增诊断，架构检查131模块/649边通过。

本轮未改BattleUI、PotionHealth、Colorless文字token、原fixture、runner、预算或基准配置。character_shop由父线程在包含其正确无色库存断言的整合树复验；本记录不借较早的20.620秒结果认证新整合基线。
