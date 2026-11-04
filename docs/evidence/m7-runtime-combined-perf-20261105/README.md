# 最终组合的有界本机性能证据

完整b4ac6314→a308edbf四个实际变化Lua模块，其他运行时上下文相同；逐模块Git blob、源摘要、Node/Fengari及生成数据摘要见[sources](sources.json)。测量记录、原始毫秒、开始时间、输出摘要和限制见[report](report.json)，另附四个timed和两个profile的JSON记录。

| 原30秒预算的交错次序 | 旧四模块 | 当前四模块 | 当前耗时降低 |
| --- | ---: | ---: | ---: |
| before→after | 21.012s | 19.635s | 6.55% |
| after→before | 20.772s | 19.656s | 5.37% |
| 两次均值，非统计保证 | 20.892s | 19.646s | 5.96% |

每个新VM执行未改动的原Silent入口及两次完整四房回放。原fixture SHA256为`979708a7554d9d6467c34646e089f70dccdaee648f09893366ac5b7eccecf3e5`，六次全部PASS、零超时/失败/重试；profile不混入主样本均值。所有样本的业务输出逐字一致，原夹具的12份完整stateSignature canonical各6464字节、SHA256为`2c9c5170ab97fa9b2edcb5b3562b076d8003aef325567ebf87baf9c52d48d49a`，包含夹具定义的run/combat RNG。

唯一一对profile：capture142→142、累计14.908→13.499秒，占Lua累计72.85%→70.75%；非capture残差5.556→5.581秒。首root均8248表/31521字段，data均4022表/15502字段，未排除目录；只计首个capture，不证明142个时刻的图拓扑逐一相同。

为读取原fixture私有canonical，所有样本用相同table.concat旁观器，返回原值；开销包含在样本内，但未独立校准。旧harness只换Snapshot、旧profile用90秒，均不能冒充最终组合；本次在任何Run导入前lazy preload四份完整Git源，严格30秒。原始驱动、全stdout/stderr、完整前后源保留在本轮`build/runtime-combined-perf`归档。

本工作负载观察到组合净收益，未隔离每片因果；LivingWall事件和全部Colorless分支不是该路径覆盖。Fengari os.clock/JIT/GC不是原生Lua、手机CPU/GPU/内存或FPS证据；不把跨host时长或此两对样本推广成性能保证。实际CI/合后验收见[交付摘要](../m7-runtime-delivery-20261105.json)。
