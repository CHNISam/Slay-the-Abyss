# M7 RunCardCatalog 职责切片

基于实际 develop `2ad07111e3d5b5cb52b4229860b3b780941e29a9`。已核开放 PR540–547 与在途 RelicPotion，生产仅修改 `abyss_run_card_catalog.lua`，接续 Owner 的 TASK-74.20 指派，不另认领或改 owner/status/AC。

## 实际职责

- prepareSelected：准备历史工厂所需五类输入；按字段合并生成内容；分别恢复调用方卡牌和 Power 的对象身份。
- prepare：调用方规则/元数据验证、选定内容索引、provider 卡片所有权和事实登记、共享 Power/药水合并、最终共享状态收口。
- 继续使用原公开 Profiles.prepare、Copy.copy、RedContract 动态成员；没有缓存调用方输入、改返回元组或新增 require。私有计数只在成功登记后递增，失败前不对外可见。

## 实测，不计其他 PR 降幅

完整333模块、5386→5401测量（含函数、嵌套和初始化），零缺测。prepareSelected CC37→3；prepare CC59→12；全模块35项最高14，全部纳入原CC15硬门禁。

CC>30为58→56，CC>15为237→235，最大75不变。SCC81/15、全部成员与1920条完整require边逐项相同，循环降幅为0。本片不是架构完成验收。

## 验证与可追溯证据

- 新14/14：8份既有fixture独立旧/新VM，264检查点、每侧48,319,157字节完整图相等，覆盖目录/嵌套别名、环、共享状态、元数据、注册和拒绝路径；全模块及未来嵌套CC15负控，三项真实可解析语义变异检出。
- 19/19：当前CI库存、历史成本来源/字节逆投影和固定300原版注册。其余12份原Lua fixture最新结果全部通过；结合8份回放覆盖本模块全部20份既有fixture。
- 独立深审额外12冷态和2热缓存组，254,469条字段、元表及公开依赖取值轨迹相等；6个故障点保留table异常身份与部分写入图。探针及原始日志完整嵌入机器证据。
- 首轮新文件13/14，仅错误诊断行142→143不同。只对实测完整rushdown错误字符串映射观察副本，逐字核验原/新语句；不改真抛值或其他错误。初期语法修正、缺生成presentation的原始失败和独审初次超时均如实记录。
- 当前静态零新告警，14历史告警未豁免；1804项职责门禁。架构、guidance、Backlog/doctor、diff检查通过。冻结完整旧源、历史oracle/源码包不变。

完整新文件71,326.726364ms仅作为本云容器观测，取71,327ms规划floor，非hosted Windows/Linux测量。原9项floor及129次raise、unknown成本、17/13分片、worker和60秒余量不变；747 JS/1402 Lua全覆盖。预测Windows max+reserve=1,715,406/1,800,000ms，POSIX=1,196,616/1,200,000ms。这不是CI通过证明，整合其他片时须保留各自floor并重算。

机器证据：`docs/evidence/m7-run-catalog-responsibilities-20261107.json`；规划来源：`docs/evidence/run-catalog-planning-20261107.json`。最终独审绑定准确HEAD/base/tree；正常PR Full、原生merge:auto、严格基线及合后Full分别验收。没有重复本地Full、用户设备、官方导入或真实ready证据；未合并。
