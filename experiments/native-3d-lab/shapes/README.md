# 六焰陶核：24块原生积木样例

复用项目现有 `art/monsters/hexaghost/` 已评阅的六瓣陶质封印、中心透孔和六处小火设计。它是低poly结构候选，不替换正式外观，也不是原版商业游戏的绿色幽灵素材。目前现有怪物图元注册表把hexaghost映射为火无相的近似外观；本例用少量原生积木保存本项目自己的六瓣轮廓。

仅 `hexaghost.mjs` 是集成入口：

```js
import {prepareShapeSample} from './shapes/hexaghost.mjs';
const result = await prepareShapeSample({call, mapPath, anchor:[0,0.4,0]});
```

`call` 返回解析后的工具数据并可自动跟随mapPath。`scene_add_shape_prefab` 必须路由到固定上游 `f32c8b05415b64e3c2698535c1aee45b105f3304` 的真实schema与工具函数；父实验的 `upstream-shapes.mjs` 已提供隔离适配。其他调用继续用已安装旧版MCP，不修改D盘安装、不启动新版daemon、不改变PowerShell执行策略。新版daemon曾因本机签名策略无法启动，因此这里直接复用同一工具实现，不以安装或UI手工配置作为依赖。

维护内容为一个六次循环生成的形状配置、一张服务器节点图、两个元件：24个装饰物属于同一个可见元件，另一个空模型仅作移动锚点。六个陶片、六个暗环段、六个火槽、六处小火；无自制贴图、无骨骼、部件碰撞全关。隐藏锚点的原生运动器驱动整体漂浮、短前移和后退，可见形状元件只使用原生follow。这样避开上游paimon实测记录的“直接给形状元件加基础运动器会破坏出生朝向/follow偏移”问题；此锚点组合的最终平滑度仍须官方客户端确认。

菜单hook无需新UI协议层：

- 发送 `SHAPE3D_COMMAND`：`command:string`、`seq:integer`，严格递增。
- 监听 `SHAPE3D_ACK`：`message:string`、`seq:integer`。
- `show` → `ready:whole_object_not_rigged`；`hide` → `hidden`。
- `move`（兼容 `idle`）→ `completed:idle_native_bob`。
- `attack` / `hit` → `requested:whole_object_motion`，0.6秒后 `completed:timed_whole_motion_requires_visual_check`。这是定时器回执，只证明动作命令流程，不证明画面运动完成。
- `turn`（兼容 `rotate`）→ `completed:rotation_by_recreation_not_rotation_motor`：整模以新的90度出生朝向替换，保持移动锚；不声称连续旋转器已工作。
- `death` → `completed:death_whole_object`：销毁整体、移除锚点，不是死亡clip/碎裂骨骼动画。

所有动作无原生伤害节点，Lua仍是卡牌伤害唯一结算来源。该样例是表现菜单，不自动写入正式规则或怪物注册表。

`preview/` 的front/side/top/angle四图实际由固定上游 `scene_preview_shapes` 的schema和工具方法生成，已逐一视觉查看：正面能数出六瓣、六火与中心孔；侧面有厚度；斜视结构仍连贯。陶片轮廓偏棱角、近似六角陶印，不能当精修火焰曲面。预览是工具离线平色草图，不是官方游戏渲染。`preview/receipt.json` 保存工具来源与PNG哈希。

本机可复现：

```powershell
$env:MILIASTRA_MCP_ROOT=(Resolve-Path .artifacts/miliastra-upstream).Path
node experiments/native-3d-lab/shapes/probe.mjs
node experiments/native-3d-lab/shapes/hexaghost.test.mjs
```

局部构建回执和GIL保存在忽略提交的 `.local/`；不发布、不修改官方存档。真实构建已将新图编译写入副本并读回元件。UI菜单由父实验整合。

成本结论：当前近似火无相2D样例JSON有478个UI图元，本例为24个原生装饰物、1可见实体+1隐藏锚、1节点图。这是维护对象数量对照，不能换算为官方容量或运行时资源消耗。尚无本候选官方容量、原生实际负载、手机FPS/帧时间、GPU成本或功耗证据。本轮保留低成本整体漂浮样例；局部火焰/陶片独立动画和连续旋转暂不做，若这种分体动画成为必需则本方案不适合替代完整骨骼表现。
