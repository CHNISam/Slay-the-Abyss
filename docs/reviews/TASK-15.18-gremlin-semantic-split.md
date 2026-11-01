# Gremlin测试按真实入口独立执行

基线 `308c1afa07fabb00f33d909a5a27739d8ec4bbae`。Quality40141217243的原夹具在30秒预算内只打印至第27组；本片只拆分测试，不修改生产、数据、预算、种子、断言或缓存Run/Map结果。

| 独立文件 | 组数 | 原覆盖 |
|---|---:|---|
| `gremlin_gang_selection.lua` | 1 | 原1680路径穷举、独立oracle、首位频数及354种有序队形 |
| `gremlin_gang.lua` | 18 | 5个源字面向量、5个seed/counter字面、独立候选池、4个direct失败/重试、非法请求与真实node、5actor容量、全部17个其他遭遇 |
| `gremlin_gang_normal.lua` | 5 | 真实normal地图frontier及4个原子失败/重试 |
| `gremlin_gang_unknown.lua` | 5 | 真实unknown地图frontier及4个原子失败/重试 |

原header/helper逐字节移到`support/gremlin_gang_fixture.lua`。穷举、vectors/seeded声明和循环、fresh pool、非法入口、容量和17遭遇块均保持原Git字节；normal/unknown的test正文、四种failure内层循环也保留原文。唯一结构变化是把外层entry枚举改为独立入口显式调用：frontier的normal/unknown、失败矩阵的direct/normal/unknown域及四种failure域都完整保留。各夹具检查自身注册数与全部测试成功，1+18+5+5=29。[机读映射及hash](../rules/evidence/sts1-gremlin-gang-semantic-split.json)可对照原Git文本复核。

父线授予独占本地窄窗口后，实际Node v22.22.1先生成唯一必要data模块并核exit，再依次执行四文件，每份仍默认30秒：2146、11289、4929、5629毫秒，四个marker共29组均通过；原`tests/gremlin-gang-data.test.mjs`一次21/21绿，385.466毫秒。成功后立即释放窗口。首轮取证漏建`.artifacts`目录导致Tee-Object写入失败，不能据shell exit0认通过；建目录并加PowerShell错误即停后，仅重跑同一精确目标，保留此错误记录，没有测试超时。

没有完整套件、完整构建、GUI、push、merge或其他特性改动；既有Flex与药水分支保持。此结果只证明拆后窄门禁，完整当前SHA CI及余下fixture审计由父线继续负责；费用和实际CPU时间未知。
