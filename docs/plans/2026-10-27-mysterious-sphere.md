# 神秘球体组件实施计划

**目标**：固定来源的第三幕事件阶段与战斗请求，公共战斗桥由主线程独占。

**架构**：独立模块只初始化阶段、提供选项、读取真实miscRng并生成请求；不接管构造HP、遗物队列、run.phase和战后奖励。父线程已确认该接口及工作树/文件范围。

**技术**：Lua、固定Node24/Fengari、Python独立整数RNG预期。

1. 读取固定ZIP九个来源成员，记录精确hash与构造/奖励顺序。
2. 在 `tests/lua/mysterious_sphere_event.lua` 与 `tests/mysterious-sphere.test.mjs` 添加六组组件测试，先执行缺模块RED。
3. 新建 `src/lua/abyss_mysterious_sphere_event.lua`，按确认合同实现prepare/options/choose；在协调的30秒时隙执行GREEN。
4. `tests/fixtures/mysterious-sphere-source.json` 锁定源合同与三金币边界；`tests/mysterious-sphere-source.test.mjs` 使用独立Python模型重验完整RNG后续状态。
5. 更新 `docs/rules/ACT3_MYSTERIOUS_SPHERE.md`，审查diff，不改共享文件或Backlog、不提交推送；交回主线程集成与最终验收。

验收分层：本片仅组件与源解释；自然入口、真实事件战斗/遗物/战后组合、架构门禁和平台验收均由主线程补充，不能由本片GREEN替代。
