# 自动化检查与本机 runner

仓库：CHNISam/Slay-the-Abyss。专用 runner：`slay-the-abyss-windows`；
标签：`self-hosted`, `Windows`, `X64`, `slay-the-abyss`。
安装目录：`C:\actions-runner-slay-the-abyss`，工作目录为其 `_work`。
Windows 服务：`actions.runner.CHNISam-Slay-the-Abyss.slay-the-abyss-windows`，
使用 Network Service 账户，自动启动；与其他项目 runner 分开安装。

2026-10-25 实际作业还使用了同标签的 `STA-Sister-Win`（机器 `DESKTOP-39DJ9M2`，该轮Node24.18.0）；本机 `slay-the-abyss-windows`（`DESKTOP-UDICC39`）该轮为Node22.22.1。不能把两台机器的耗时当作同一环境的负载变化。取证按作业记录runner、机器和实际Node版本；相同断言及原预算仍须通过，不以快机器的结果掩盖已发生的超时。

## 每次变更

从 develop 建 feat/* 分支，通过 PR squash 合并回 develop。
PR 标题使用 Conventional Commits；master 仅收 release/hotfix 并打 tag。
Quality / check 在 PR、develop/master 推送时运行，也支持手动执行：

1. 检查本次变更的空白错误和 PR 标题。
2. Node 22 JavaScript 语法检查。
3. Node 自动化测试（串行执行，失败立即阻止通过）。
4. 所有运行数据的结构、枚举、范围、ID 与交叉引用校验。

presentation 作业在 GitHub-hosted Ubuntu 跑文案回归；engineering-posix
实际执行Node文件系统回归，覆盖Windows权限不足时跳过的符号链接用例。
三个作业显式准备Pillow 12.3.0；check与engineering-posix准备固定hash的
Luacheck 1.2.0。合并前同时核对check、presentation、engineering-posix。

本地先 `npm ci --ignore-scripts`、`npm run setup:lua-static`，再 `npm run check`。Lua同源测试使用锁定的
开发依赖Fengari；运行错误、语法错误、缺文件和超时均有非零退出回归。
Windows check作业先安装锁定开发依赖，再按 `npm run check:rules` 的六条命令及相同顺序逐步执行（Node+数据+Lua）；每阶段在作业API中单独可见，前阶段失败仍阻止后续通过。
Lua默认每个独立脚本限30秒；battle/game界面为60秒，遭遇覆盖和三个地图属性矩阵为120秒，准确名单以`scripts/test-lua.mjs`为准，调用方显式超时仍优先。逐脚本记录耗时，保留全部断言、超时失败和整作业上限，不代表游戏性能验收通过。
原生界面的同源中文显示构建使用 Python 3 标准库，默认命令为 `python`，可用
`ABYSS_PYTHON` 指定解释器；构建子进程固定启用 UTF-8。
Python表现测试由Ubuntu presentation作业完整执行。本地总入口仍包含两者。
check 作业直接使用已有 Git 与 Node（最低 22，本机 22.22.1），不下载
checkout/setup-node 组件。Git 精确检出事件提交 SHA，核对后清理 runner
工作目录；认证 header 仅在 fetch 进程环境中使用，随后清除，不写入磁盘配置。
编辑器遵守根目录 `.editorconfig`。格式约定不等于完整静态分析；
后续节点图检查继续加入统一入口；离线Lua测试与真机验证分别报告。
fork PR 使用 GitHub-hosted Ubuntu；仓库内 PR 与推送使用本机专用标签。
工作流只授予 contents:read；presentation 的标准 checkout 也不持久保存 token。

## 维护

```powershell
Get-Service 'actions.runner.CHNISam-Slay-the-Abyss.slay-the-abyss-windows'
gh api repos/CHNISam/Slay-the-Abyss/actions/runners
gh run list --repo CHNISam/Slay-the-Abyss --workflow quality.yml
```

停止服务前先确认 runner busy=false，且没有已分配的作业。
管理员 PowerShell 中可对上述精确服务名执行 Stop-Service / Start-Service。
不要操作其他仓库的服务，不读取或提交 runner 凭据文件。
本机必须开机联网才能接任务；重启后由服务自动恢复。
首次安装复用了本机现有官方 runner 2.337.0 的程序目录，未复制其凭据、
配置和工作目录；本项目使用独立注册令牌，保留官方自动更新机制。
直连下载 Actions 发生超时，因此仅在本 runner 的 `.env` 配置
`http_proxy` / `https_proxy` 为 `http://127.0.0.1:7897`（本机 Clash），
`no_proxy=localhost,127.0.0.1`。代理需保持可用；其他 runner 与全局代理未改动。

CI 只验证仓库逻辑与数据，不代表平台编译、写入存档或游戏内试玩通过。
新增架构/静态/四算子门禁和候选、UI、交付证据合同见[ENGINEERING.md](ENGINEERING.md)。
check上传真实checkout身份，engineering-posix上传依赖图、静态告警/复杂度
与变异报告，保留7天。取证/合并不得复用旧head/base或旧attempt结果。
CD 当前止于可审查的代码集成；正式游戏发布、赛事投稿由人完成。

## 测试文件的执行边界

单文件积累了多个独立场景而接近原时间预算时，先测量重复准备成本；可复用准确同种子、真实入口生成的冷状态，但每个场景必须隔离可变状态并保留内部共享引用。仍过大时按独立场景或不重叠的完整种子范围拆分，不能删案例、删种子或省略原断言来通过。

拆分须保存原文或断言对照证明，并通过真实入口逐文件检查。跨种子的汇总条件也必须保留：本轮问号房的1–110与111–220两段，各自验证四类路由和七种事件，完整覆盖原220个种子；其余13项事件检查不变。意图预览按4/3/5组拆分，原12组及循环逐字保留。各文件沿用原30秒预算，当前提交完整CI仍是合并门禁。

新增暂缓获取的定义时，目标等元数据守卫须同时核对旧项和新增项，不能把“原可获池未变”误写成“总定义数不变”。药水目标测试保留原11组操作断言并按5/4/3组执行，另以独立ID表校验原七瓶与新增五瓶的目标和pending边界；实际获取轨迹仍由原专项检查验证。

CI取证先核对日志字节数、当前SHA、步骤及最终结论。`gh run view --log`为空或遗漏失败步骤时，改取对应作业的`gh api repos/CHNISam/Slay-the-Abyss/actions/jobs/<job-id>/logs`；空日志不是成功证据。耗时记录同时注明实际Node版本，不能跨运行时或负载条件直接断言性能退化原因。

独立Lua夹具出现失败后继续检查其余夹具，最后仍以非零退出；后续通过不能清除先前失败。普通Lua错误和子进程超时均有真实CLI回归，保留每份输出、诊断与耗时，避免每轮只暴露第一处问题。卡牌原93组按92项效果/获取与1项完整奖励覆盖矩阵执行，共用原独立期望表，保留128种子上限、原提前齐全退出和全部领取/下一战断言。

修改测试运行器契约时，必须同时查找并同步既有调用方的行为断言，不能只验证新增回归。本轮旧发现测试仍要求遇错即停，导致新继续执行契约已通过专项测试但完整CI失败；现保留空目录失败、排序、全绿成功，明确验证失败原因、后续文件继续执行及最终非零。五瓶药水原11组再按库存/原子性2组、Swift抽牌5组和状态4组拆分，原用例块、循环及断言逐字保留；真实JS入口要求全部三个标记，获取轨迹专项不变，每份仍为30秒。定向通过不能替代当前提交完整CI。

增加夹具或大矩阵时同时核对整套作业预算。Quality40141217243在本机Node22通过全部JS（1213通过、0失败、119跳过）后，Lua仅执行到207份中的123份就被原20分钟作业上限取消；其中哥布林编组仍有单份30秒超时。整套作业上限调整为45分钟，单份时限、全部夹具、断言及失败状态不变；取消的轮次保留为未完成验证，不能算整套通过。

哥布林编组原29组按穷举1组、直接入口18组、普通房5组、问号房5组拆分，1680条选择路径、完整来源/种子向量、三个入口的四类失败以及另外17种遭遇全部保留。暂停补查时将PASS、FAIL、RUNNING、INTERRUPTED和NOT_EXECUTED分别统计；不能把尚未执行或因资源让出而中断的条目计作断言失败，也不能当作通过。

2026-10-22 实查：GitHub 分支保护 API 返回 403，提示当前私有仓库套餐需
升级 GitHub Pro 才支持该功能。CI 会报告 check 结果，但服务端目前不能强制
阻止绕过检查合并；维护者须遵守先绿灯再合并，未改变套餐或仓库可见性。
