# Golden Wing 测试候选独立审查

## 结论

**未发现本候选的阻断问题；适合作为 `develop@3ed8bf4b88a950c4736ec2d68e83f141d415c4db` 的独立测试候选交给原执行者接续。** 本轮未发现生产缺陷，也没有生产修复。没有正式开 PR、合并、修改 Backlog、改认领或写远端，不把归档候选称为已合并交付。

对象为作者候选 `tests/lua/golden_wing_boundaries.lua`（124行），SHA256 `87f977139b24e31dea93f839e3bb4b8f0aa4e1b06f6c46ac169c7b39315bf2f8`；补丁 SHA256 `66877cd841dcbf1b694801a9cd21fff99bbc21d09d81ebbedbce079aeb9ac858`。独立目录保留原候选不改。

## 实际验证

- 作者目录只读；先核 AGENTS / REPORT / REPRODUCE / FROZEN，实际调用 Backlog overview 返回 `backlog: command not found`，未安装或手改任务。
- 固定任务快照仍为 TASK-13.1.2 `In Progress` / `@Codex`，全25事件及平台验收未完成。本轮不认领或关闭它。
- 重新计算9项冻结 SHA256、67份运行源/数据/既有测试的 Git blob，并与固定树清单比对；全部匹配。7份固定来源也重新计算 Git blob，全部匹配。见 `evidence/identity-checks.json`。
- 在自己的复制目录重新执行仓库 `node scripts/build-lua-data.mjs`，退出0；native Lua 5.4 实跑新用例16/16、既有 unknown_events 13/13、empty_permanent_deck 8/8，全部通过。新增文件单次约0.19–0.21秒，仅为本环境测量。
- 独立复跑作者8个负控，均以真实 `not ok` 断言失败且退出1，不是语法/加载错误，也不称为生产失败。
- 另设计5个定向负控，分别对准门槛下移至9、Vajra力量计入资格、view重新算资格、合法净化再扣血、无效UID偷偷消费cardRng；五个都在预期断言处被抓到，见 `evidence/independent-probes.json`。
- `git apply --check ../candidate.patch` 在本次固定runtime副本通过。没有执行全量检查、安装npm、Fengari预算、Windows CI或平台操作。

## 覆盖与预期依据

1. **基础单击10门槛与升级**：候选39–48行是固定字面量表，不从 `goldenAttack`、规则配置或卡数据反算 expected。Strike 6/9不合格，Bash 8不合格/升级10合格，Cleave 8不合格/升级11合格。原卡文件构造与upgrade分别固定这些数值；CardHelper 80–92行检查攻击类型且 `baseDamage >= 10`。作者 `>10` 负控和本轮 `>=9` 负控分别抓到两侧边界。
2. **多段不累加**：Twin Strike源码构造 `baseDamage=5`、升级+2，use安排两次伤害；CardHelper只读baseDamage。候选44–45行固定5×2、7×2均不合格；累计多击负控失败于这两行对应用例。AOE并不被排除，Cleave+为独立正例。
3. **动态伤害与力量**：Body Slam构造baseDamage=0、升级只改费用；候选46–47行对普通/升级均判不合格。Vajra用例70–74行保留Strike+基础9，不能因遗物力量进入合格组。本轮只改生产谓词将Vajra+1算入门槛，恰好第11用例失败。该用例验证Vajra边界，不外推所有战斗中临时状态。
4. **入场快照**：GoldenWing.java 63–75行构造时捕获canAttack，130–142行选择分支复用它。候选76–85行明确人工替换永久牌组，双向验证入场不合格→后续牌组可合格，以及入场合格→后续不合格。作者负控抓chooseEvent重算，本轮负控抓view重算。不是自然获取路径证据，但对缓存契约有效。
5. **献血死亡**：GoldenWing.java 66与120–127行支持7点先扣血。候选87–101行以1/6/7HP验证致死后终局、不能净化/取金/离开/重付，永久牌组、UID分配器、金币及四类随机流不额外变化。`phase=defeat`、`complete=true`、`no_pending_node`属于本项目终局/API契约，不冒充原版完整死亡画面与动画行为。
6. **存活与重复选择原子性**：候选103–121行以8HP→1HP进入待净化阶段；换金币、离开、重复献血和错误UID分别整份深比对run/map，拒绝不能附带状态改变。正确UID只移除一次且不再扣血；再次净化拒绝。额外“合法净化再扣血”负控在成功分支HP断言失败，补证作者原负控仅先在无效UID处失败并不意味着成功分支没被测。

完整模块都经真实Run.new/Nodes.enter/Nodes.view/Nodes.chooseEvent/Nodes.purgeWing调用；未替换被测接口。地图只生成一次再深拷贝，组间run也独立，未见共享状态污染。pcall收集失败后文件末尾assert保证进程失败。

## 固定来源身份与证据边界

来源是第三方反编译镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`，不是官方开源、正版目标JAR认证或原作实机。完整链接在 `context/source-metadata.json`；本轮核到字节与记录的blob一致，不声称重新下载或额外认证镜像。

- GoldenWing.java：`4bebe490cacf288ad25bd4042f48575cfb3b9bd2`。
- CardHelper.java：`f1528bfd5c1bf1fc1d5dc04a8718764dc59d449f`。
- Strike_Red / Bash / Cleave / TwinStrike / BodySlam的固定blob见上述清单及 `evidence/identity-checks.json`。
- 仓库 `docs/UNKNOWN_EVENTS_P0.md` 15/23/40行也已有先支付、不换选项、单击门槛、快照和同一镜像的独立书面依据。该文旧受限池描述不覆盖TASK-13.1.2当前25事件范围。

测试没有把待测谓词当oracle，没有凭当前通过反推原版规范；死亡及错误码的来源层次与原版资格数值已分开。

## 非阻断覆盖限制

- 存活献血/合法净化的成功分支只显式比较misc/event流，未显式比较card/treasure流；所有拒绝分支是完整状态比较，死亡分支比较四流。不要把该成功分支称为四流完全守恒证明。
- 所有永久牌组为单卡，不能以此证明多卡场景“选择非首张UID只删那张”；也不认证瓶装牌、特殊移除/获得钩子、复活遗物或完整原卡池。
- 候选顶注未直接列镜像commit/blob，但现有文档有固定镜像，归档中也保留完整来源清单。原执行者接续时宜一并保留本报告/来源账本，避免丢失数值出处。这不构成当前候选逻辑阻断。

结论仅适用固定3ed8基线及本次有限native检查。没有Fengari30秒预算、完整CI、平台编译、写副本、官方导入、自然获得或实机UI结论，不能关闭TASK-13.1.2、M3或平台验收。
