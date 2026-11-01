# 有限复跑

在本目录的 `runtime/` 下：

```sh
node scripts/build-lua-data.mjs
python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../probe.lua
```

预期 16 passed、0 failed、exit 0。无需安装，不运行全量 npm。

以下是必须失败的隔离反证，不是生产修复：

```sh
CAPABILITY_OVERRIDE=../mutants/old-capability.lua CASE_FILTER=channel python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../probe.lua
LATE_CAPABILITY_OVERRIDE=../mutants/old-capability.lua CASE_FILTER=channel python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../probe.lua
CAPABILITY_OVERRIDE=../mutants/old-capability.lua CASE_FILTER=transform python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../probe.lua
CAPABILITY_OVERRIDE=../mutants/fail-open-capability.lua CASE_FILTER=negative python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../probe.lua
```

预期分别为 2、2、2、9 个失败，全部 exit 1。第三组另外 3 个未知变换负控仍通过。

基线运行不设置以上任何环境变量，既不替换 Capability，也不修改其字段。负控只修改本次测试 Run 的私有数据副本，所有运行源始终对齐 frozen head。
