# 原生表现适配边界

`prepareNativeScene({call,mapPath,anchor,outputPath})` 只装配离线 GIL 副本。`call` 接受工具名和参数，返回解析后的 structuredContent；模块自身跟随每个 mapPath。默认 anchor 为官方空白底图的 `[0,2000.4,0]`，调用者可替换，必须核实对应底图脚下地面。

使用官方复杂造物和官方动画：遗迹守卫（待机、攻击、重受击）、大型风史莱姆（待机、攻击）、打手丘丘人（待机、无武器攻击）。待机是原生站立状态；未在已读目录找到的受击 clip 返回 unsupported。死亡实验使用 destroyEntity 的原生销毁表现，不宣称有可自由播放的死亡 clip。

官方 API 参考：[复杂造物](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhb8nl0w8cao)、[复杂造物技能](https://act.mihoyo.com/ys/ugc/tutorial/detail/mhftoirpwd46)。本机社区工具的 `examples/brain` 与 `examples/signalparams` 提供状态图和双向信号成熟实现。工具版本和模板哈希由候选回执记录。

本机工具不支持直接由怪物 asset 创建 prefab，通常需要先在编辑器导入实体。本实验通过复制本机官方“复杂造物”教学存档的真实丘丘人元件结构，重新分配无冲突元件 ID、替换已核实的官方模型 ID，删除教学存档旧图、旧巡逻和旧单位状态实例，再用公开工具配置本实验的图、技能和变量。来源存档及元件哈希保存在 provenance。此处属于实验性的结构适配；写入、读回、节点编译不代表官方导入或运行时模型兼容已验收。

全局取消敌对关系，模型与玩家相同阵营并添加无敌，玩家额外禁止移动以稳定固定镜头。默认创建25×25米官方石质地板（20002055、scale 5/1/5），添加显式碰撞；地面在2D和3D模式都保留，不属于比较变量。三个敌人槽沿镜头屏幕横向x分开3米，固定镜头18米、55度视野、22度俯角；其最终构图仍须客户端确认。技能图只在官方动画尾部通知服务器，不创建命中盒、不造成原生伤害。卡牌规则和数值仍由现有 Lua 负责。一次序列号只接受一次；同一角色等待 ready 或动画端点期间拒绝重叠动作。技能端点回执仅证明节点事件执行，完整动画和画面仍须客户端确认。

信号合同：

- LAB3D_COMMAND：command:string、model:integer（1..3）、actor:integer（敌人槽1..3，hide的0表示全部）、seq:integer（全局严格递增）。
- LAB3D_ACK：message:string、seq:integer。
- show/reset 先返回 created:initializing_4.5s，4.5秒后 ready；attack/hit 先 requested:await_skill_event，技能尾部事件后 completed:attack/hit；idle 返回 completed:idle；hide 返回 hidden；death 返回 completed:death。
- actor0 的角色动画返回 unsupported:player_animation；缺少受击 clip 返回 unsupported:hit；技能事件8秒未到达返回 error:animation_timeout。

三个敌人槽独立摆放和切换，hide actor0 真正移除所有原生模型，避免2D模式背后仍运行展示AI。原生模型初始化延迟取自工具既有实测；本候选实际时长和手机性能均待实机。

定向检查：`node --test experiments/native-3d-lab/native-scene.test.mjs`。行为夹具只验证路由、序列、超时和降级，不能证明引擎动画或GPU表现；完整候选构建必须成功执行 write_graphs 并 inspect_map 读回全部8张图。
