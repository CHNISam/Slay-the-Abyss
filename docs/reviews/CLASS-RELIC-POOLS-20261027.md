# 四职业共享遗物队列

固定依据：`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。`AbstractDungeon.initializeRelicList` 以 chosenClass 分别调用 `RelicLibrary.populateRelicPool`，后者先按 shared HashMap 遍历，再按该职业的 HashMap 遍历，最后仍从 relicRng 连续取得5个 randomLong 对五类队列执行 JDK Collections.shuffle。

原差异：四职业 Run 均使用仅含shared+red的同一队列。实际 Silent/Defect/Watcher 都能选中 Champion Belt，同时缺失其职业专属来源；这不是缺少效果定义导致的 unavailable 问题。

实现：仅从固定源读取 green/blue/purple 注册ID、稀有度、顺序和实际3项starter资格事实。复用既有Java oracle，其文件、旧red TSV/目录/向量均不改。运行时Run.new为真实STS职业选择对应完整catalog；历史prepared-profile ABI同样接通。没有声明STS映射的原创V4保留其历史source行为，不因名字猜映射。缺少效果定义的选中原始ID继续 unavailable，不缩池或重抽。

本机JDK21生成前再次核对旧JDK17的全部unshuffled shared+red队列完全相同；新验证锁定40组完整队列（红10+另外三色各10）和每组5次随机消费，额外检查实际Run、旧profile、Shop/Treasure/Elite共享source、starter替换资格与原创四角色兼容。来源字节身份、全量事实和JDK结果见 `tests/fixtures/sts1-class-relic-pool-vectors.json`；Lua向量文件hash与所有生成器/原seed输入文本hash都由Node测试核对（仓库文本统一LF口径）。

3份原Run.new生产副本的真实红例分别输出Red Skull≠Snake Skull、Red Skull≠DataDisk、Red Skull≠Damaru；日志保留独立执行树work/class-relic-red，不当作自然通关或实机证明。

该修复不等于所有职业遗物效果已齐、解锁历史已自然取得或完整四幕实玩通过。来源为社区反编译镜像，未认证授权PC二进制；本轮没有导入、原作或千星实机取证。正常合并仍需最终整合SHA完整Quality及独立复审。

| 源方法文件 | SHA256 |
| --- | --- |
| `helpers/RelicLibrary.java` | `e0fed2c9c4559dcf0bf3a19190a46af09a3300a9741757cc62550fdc5889874c` |
| `dungeons/AbstractDungeon.java` | `8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26` |
