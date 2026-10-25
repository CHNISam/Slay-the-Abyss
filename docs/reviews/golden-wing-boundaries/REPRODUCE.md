# 重现

本目录全部本地副本和候选固定于 `develop@3ed8bf4b88a950c4736ec2d68e83f141d415c4db`。无需npm安装。

```sh
cd /workspace/shared/sta-next-independent-0047/runtime
node scripts/build-lua-data.mjs
python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../candidate/tests/lua/golden_wing_boundaries.lua
cd ..
python run-review.py
```

第一份测试必须报告 `GOLDEN_WING_BOUNDARIES 16 tests, 0 failed`。完整有限审查脚本必须退出0并报告16个新增用例、8个被捕获负控、21个既有用例；负控的单个进程应退出1且出现 `not ok`，不能只凭进程非零算捕获。

脚本只在 evidence 下生成局部变异副本，并用独立Lua进程加载；runtime/src/lua/abyss_nodes.lua不被覆盖。所有运行都是native Lua5.4，不是Fengari或平台。
