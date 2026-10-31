# 近期集成补验

Owner要求补上近期跳过CI的集成验证，不能把未经验证的组合当作稳定版本。

最近已确认完整Quality成功：`9cfb250bffa495c5cf76d76f9452368a25de9788`，run `41155215527`。
本轮初始审查范围为该提交到`dd295847d8485f53ee078ced125f7be85e284e74`，随后纳入仅修改测试合同的`96411b6c74349f25e3434509dd922e423b47c45f`。
独立只读复审`/root/integration_review`覆盖全部运行时差异，重点检查评分、失败回滚、药水逃跑、卡牌只读预览、地图输入、Beggar和Neow，未确认运行时缺陷；PR417三个测试合同修订也独立复审通过。

## 已复现的阻塞及修复

- 原始官方失败：`af178273`的Quality `41159968538`，`rules (3/13)`，job `124416598131`，`jaw_worm_ai_slice_3.lua`原30000ms超时。
- `96411b6c`本机Node24.18.0独立复现相同失败，30086ms。不是把排队、取消或未执行算作成功。
- 该入口将原组12的16个独立种子、每种子24回合与组13放在一个进程。最初两半实际26888/28366ms，虽通过仍接近上限，因此最终改成四组各4个种子；组13独立。
- 保留原13组全部断言、全部种子和回合，未改生产Lua、runner或30000ms预算。唯一种子循环与原selector逆转后仍核对原始完整SHA256及GitBlob，没有刷新历史oracle。
- 完整raw入口清单与精确wrapper内容相互核对；缺片、漏种子、重复种子和越界负例必须失败。新增入口按现有自动发现进入完整CI；未测新入口沿用现有独占调度。
- 独立复审`/root/integration_review`已检查全部拆片差异，确认未删有效断言、未改历史hash、未放宽预算；组12末尾独立owner检查反而在四片分别执行。

## 本轮验证与边界

`node --test --test-concurrency=1 tests/architecture-composition-format.test.mjs tests/run-governance.test.mjs tests/card-actions-registry.test.mjs tests/lua-runner-output-buffer.test.mjs`：14/14通过，含完整exhaust新旧状态/队列/RNG与超缓冲失败保护。

`node --test tests/jaw-worm-ai-partitions.test.mjs`：2/2通过，包括完整历史字节还原和覆盖负例。
七个raw入口逐项使用`node scripts/test-lua.mjs <入口>`：组1/2–11分别6376/1821ms通过，最终四片组12分别15876/16980/18343/15229ms，组13为1652ms，均在原预算内通过。
`node --test --test-concurrency=1 tests/jaw-worm-data.test.mjs tests/lua-workers.test.mjs`：21/21通过，含未知/长夹具独占、失败不丢与原数据约束。
完整托管CI另由TASK-88续记，不以专项通过预先宣告整体验收。

## 完整主线回归新发现

`96411b6c`的完整Quality `41184409466`实际分片23项成功，两个失败分片逐条核对：`rules (4/13)` job `124489841974`仍是原Jaw Worm单片30039ms超时；`rules (8/13)` job `124489841944`为`deck_pile_view.lua:28`旧断言要求点击层隐藏。最终汇总还须读取，不将失败分片当作通过。

PR413已允许普通牌堆只读详情，PR414在真实点击回调中拒绝拖动与松手位移。旧隐藏点击层断言已过时；本轮先在当前源码复现原失败，再对抽牌堆/弃牌堆/消耗堆验证拖动与松手位移不误开详情、正常点按只读查看、无选牌回调、返回保留原生滚动位置。原精确排序、Frozen Eye反序、费用成长、完整Run/RNG、空牌堆和非法上下文断言保留。原四组raw在26072ms通过，原30秒预算不变。

移除真实生产`scrollClick`保护的内存负对照被新增“dragging must not inspect a pile card”断言捕获，源文件字节核对未变。首次负对照尝试因Fengari不提供`io.open`失败，不作为断言成功；改由Node读取源码并内存预载后完成有效负对照。两次日志均保留。

相关验证另抓到`card_detail_preview.lua`原11组共进程在本地30秒超时，输出仅到第5组；`deck_scroll_detail`同时成功。原11组按1–3、4–6、7–9、10–11机械拆片，完整原始输入绑定`96411b6c`的GitBlob `645e09522a9eb9069aa5d4d6bc764cd865466ead`及SHA256 `06cf6450738fd6744e9eadd8309b5108c906d966cd149206522147e12b3cb11c`，不更新原始oracle。Node桥接逐片核对实际CASE序列，raw自动发现四入口；缺片/遗漏/重复均拒绝。四真实片与两项历史/覆盖合同共6/6成功，分别16342/13227/13786/8409ms，全部仍用原30秒预算。

上述修复仍只涉及测试与证据；生产逻辑没有改动。最终修复HEAD的完整托管CI尚待，不能借原主线23项成功补齐它。

日志保存在本轮隔离树`ci-stability-*.log`；旧完整本地运行在主线合入PR417后主动停止，不能认证最终提交。旧主线取消记录保留。首次冻结的手动Quality `41184511839`在确定超时后主动取消，不作为通过证据。

卡组滚动事件字段已核对官方离线指南`mhtakr07vej4`的CursorEventData声明，接口存在；手机实际滚动后的点击派发仍须最终候选实测。本轮未生成GIL、官方导入、ready、PC/手机实机或官方容量证据，不提升这些验收状态，不发布。
