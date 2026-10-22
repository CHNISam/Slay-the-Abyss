# 静态卡牌容量验收样本

TASK-10.1.2；2026-10-23。设计与实现计划经主代理确认：保持已实机通过的上游单卡函数、180×240画布、148×208卡框、scale=1、标题/类型h40与132×92说明框。只绑定模板索引与每槽OFFSET常量，使用同一干净底图分别生成0/1/5/10卡和最长中文单卡五个静态副本。静态网格仅用于容量验收，不代表批准稿的正式扇形手牌实现。

实现步骤：

1. 从固定上游导出器和已通过source生成比较卡；用现有中文表现层渲染器确定最长实际文案，再导出独立长文卡。
2. 生成固定布局、可编辑输入、预览、控件清单和来源哈希；保留独立点击诊断与10秒客户端dt。
3. 提供只写副本准备脚本，逐副本取得真实模板索引；离线检查几何、JSON/Lua回读、VM生命周期与失败清理，目视预览。
4. 提交独立分支/draft PR；MCP、官方导入和实机验收由主代理执行。

同副本运行时切换需要管理多份脚本实例生命周期，会引入额外控制器，因此采用五个静态副本。最小验收顺序是0→1→5→10→longest，每份等待10秒、记录均值/P95、点“点击检查”并截屏。先比较同一底图的前四项，再单独检查长文排版。

文件位于 [`art/spikes/card-capacity/`](../../art/spikes/card-capacity/)。`reference/card.lua`直接保留已通过单卡的导出内容；`longest/`只替换名称、说明、费用（卡牌仍为攻击牌，保留比较卡的几何/颜色）。`*-ui.json`是五种宿主布局，`probe.lua`只管诊断。模板常量保留0，只有准备副本时按返回的真实索引绑定。图库100001/100002/100003仍仅是图片资产ID。

| 场景 | 卡图/原生文字 | 卡宿主 | 固定诊断控件 | 根宿主 | 活动控件总数 |
|---|---:|---:|---:|---:|---:|
| baseline | 0/0 | 0 | 5 | 1 | 6 |
| one | 11/4 | 1 | 5 | 1 | 22 |
| five | 55/20 | 5 | 5 | 1 | 86 |
| ten | 110/40 | 10 | 5 | 1 | 166 |
| longest | 11/4 | 1 | 5 | 1 | 22 |

各副本均另建2个“仅存为模板”的控件，不算活动控件；总数不含干净底图已有的控件/官方系统UI。固定诊断为Status、Plate、Label、Confirm、Metrics。one/longest中心(0,0)；five的x为−360/−180/0/180/360、y=0；ten同样五列，y=130/−130。透明宿主边界在1280×720内，卡片无重叠，不使用缩放或扇形旋转。

最长样本来自`tools/render_traveler_cards.py`既有`render_cards`，逐项比较37卡的基础/升级74份实际中文文本。`reaper`“以战养战”基础/升级文案并列42字符（含空格和标点），稳定选择基础版：

> 对每个敌人造成 4 点伤害，并回复与本次攻击实际造成伤害等量的生命。打出后消耗本牌。

说明仍为132×92、15号、自适应最低14号。**上游Pillow PNG导出器不会模拟原生换行：长文离线预览显示单行裁切，这是已知预览限制，不能据此认定原生文字通过或失败。** JSON/Lua保留完整42字符；官方客户端必须逐字核对换行、裁切、字号与上下边界。十卡离线图已目视核对，图形与诊断控件之间无重叠。

在worktree根重生成与跑离线VM：

```powershell
npm ci --ignore-scripts --no-audit --no-fund
& 'F:/New folder/tools/vendor/image-editor/backend/.venv/Scripts/python.exe' -X utf8 scripts/art/prepare-card-capacity.py --editor 'F:/New folder/tools/vendor/image-editor' --validated-source 'art/spikes/card-capacity/reference/card.source.json'
node node_modules/fengari-node-cli/src/lua-cli.js -e "dofile('build/art-capacity/verify.lua')"
```

初次输入来自主代理已通过的`text-height-compat/card.source.json`；交付已保存相同reference输入，以上命令可独立复现。生成器固定检查上游提交`103025f9095d8089e3f9bf097f4d0c5fe039d546`，复用原JSON/Lua/PNG导出器，未重造转换算法。

主代理准备五个副本（该操作本分支**未实际调用MCP**）：

```powershell
./scripts/art/prepare-card-capacity.ps1 -BaseMap '<干净底图绝对路径.gil>'
# 若只需一项：追加 -Scenario baseline|one|five|ten|longest
```

脚本在任何MCP读取/复制前先将总索引和所有选中场景标为`preparing`并清空旧路径，再读workflow/platform-rules，对同一原始底图逐项复制→建模板→绑定真实templateIndex与slot OFFSET→挂脚本/静态UI→client check，保持`MILIASTRA_ALLOW_LIVE_WRITE=0`。每项输出`build/art-capacity/<场景>/candidate.json`，总索引`build/art-capacity/candidates.json`为`{state,runId,scenarios,candidates}`对象；只有整轮成功，总索引才为`prepared`并包含本轮候选数组。使用前检查总/单项`state=prepared`且`runId`相同。它不操作GUI、不导入官方编辑器、不发布。不要把前一候选作下一项的底图。失败时总索引保持`preparing`且候选数组为空，不能当作已准备成功。

最小失败注入：`./art/spikes/card-capacity/verify-preparation.ps1`。该命令只用本地隔离mock CLI，会覆写当前worktree的`build/art-capacity/`测试报告；先种入旧prepared，再验证资源read失败、中途ten脚本工具失败均使总索引失效、所有选中场景不残留旧runId/路径，最后验证正常成功发布5项同轮候选。它不读取真实MCP资源或创建游戏存档。

离线证据：生成器通过参考Lua一致性、参考/长文JSON-Lua双向元素回读、函数体相同、宿主几何/无重叠、74文案最长选择；Fengari通过0/1/5/10动态计数、未绑模板拒绝创建、OFFSET、重复启动/销毁、部分创建失败回收，以及诊断点击、10秒dt、重新采样和旧回调失效。PowerShell语法解析通过；用隔离mock CLI跑完五项、确认两端slot绑定及原底图不变，**mock不是MCP检查结果**。`manifest.json`记录来源/输出SHA256（文本统一UTF-8/LF；PNG按原始字节），不提交账号截图或GIL。

| 官方运行时验收项 | baseline | one | five | ten | longest |
|---|---|---|---|---|---|
| MCP静态客户端检查 | 0错/0警告 | 0错/0警告 | 0错/0警告 | 0错/0警告 | 0错/0警告 |
| 官方编译日志 | | | | | |
| 写入副本并由官方编辑器导入 | | | | | |
| 完整中文/图形与独立点击 | | | | | |
| 10秒dt均值/P95 ms | | | | | |
| 首次可见耗时/可见卡顿 | | | | | |
| 连续进入退出3次/清理 | | | | | |
| 手机/主机 | | | | | |

表格空白表示未测。10秒客户端`OnUpdate(dt)`统计不等于GPU耗时；比较时记录设备、客户端版本、底图、画布和同屏总控件。已有单卡33.3/P95 34.0ms记录缺少基线，不能移填本表。

主 Agent集成后于2026-10-23实际运行上述准备脚本，五份副本全部生成；同轮runId为03a6a22c-83f2-4651-9506-a9fed8c1acac，底图SHA与各副本哈希记录在 [evidence/2026-10-23.json](evidence/2026-10-23.json)。这是实际MCP静态检查，区别于先前Agent的隔离mock。本机便于人工验收的等字节副本位于 `build/art-acceptance/01-baseline.gil`、`02-ten.gil`、`03-longest.gil`；先基线→十卡比较，必要时补单卡/五卡定位，长文另查。原始五项仍可按完整顺序验收。尚未官方导入/试玩，截图证据不能移用旧单卡。

来源与许可：卡框/几何由本项目批准主题及上游已通过小样生成，中文/数值来自项目`data/`，未使用其他创作者美术/存档。上游[Image Editor](https://github.com/1475505/Miliastra-image-editor-webui/tree/103025f9095d8089e3f9bf097f4d0c5fe039d546)仓库声明GPL-3.0；primitive-shape运行时源自LiuL、MIT。随本小样保存[`licenses/EDITOR-GPL-3.0.txt`](../../art/spikes/card-capacity/licenses/EDITOR-GPL-3.0.txt)、[`licenses/PRIMITIVE-SHAPE-MIT.txt`](../../art/spikes/card-capacity/licenses/PRIMITIVE-SHAPE-MIT.txt)与原始来源说明；导出Lua含上游运行时及适配代码，不应视为无来源代码。
