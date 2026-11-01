# 岩系遗迹景片：原生资产最小实验

基线：`develop` / `91ae349`，遵循 PR #19 的岩系、灰蓝石材与少量金色方向。本实验只选择官方场景模型，未将图片拟合为 GIA，也未引入框架或修改游戏逻辑。

## 交付与选型

- [`geo-ruins.scene.json`](geo-ruins.scene.json)：可直接作为 `scene_build_blocks` 参数，7 件静态景物，包含一件原生遗迹门洞建筑。
- [`ruin-gateway.asset.json`](ruin-gateway.asset.json)：同一个门洞的单件原尺寸检查包。与景片分别验证，勿同时导入同一个副本，以免重复。
- [`thumbnails/`](thumbnails/)：从已安装 MCP 的 `scene_asset_images` 原样保存的官方资产缩略图；缩略图统一构图，不能据其判断真实大小，也不是本项目的游戏截图。
- [`asset-selection.json`](asset-selection.json)：所选 ID、原始尺寸、目录来源和缩放后尺寸。

| ID | 资产与用途 | 原尺寸 x/y/z（米） | 景片缩放 | 缩略图 |
|---|---|---|---|---|
| 20003078 | 圆形石质地板，中心留白 | 16.169 / 0.406 / 16.169 | 0.70 | [图](thumbnails/20003078.jpg) |
| 20002899 | 残破石质地板，左前景收边 | 5 / 0.85 / 5 | 0.55 | [图](thumbnails/20002899.jpg) |
| 20002586 | 石质门洞，右后景建筑地标 | 5 / 5.643 / 0.61 | 0.85 | [图](thumbnails/20002586.jpg) |
| 20001711 | 残破石柱，左后景高点 | 2.466 / 5.818 / 2.427 | 0.65 | [图](thumbnails/20001711.jpg) |
| 20002902 | 残破石质墙壁，左后景低点 | 2.242 / 2.923 / 1.395 | 0.75 | [图](thumbnails/20002902.jpg) |
| 20001540 | 石堆，少量金色矿物点缀 | 3.462 / 0.966 / 3.602 | 0.60 | [图](thumbnails/20001540.jpg) |
| 20002083 | 岩石，右侧灰岩配景 | 3.511 / 2.637 / 4.226 | 0.65 | [图](thumbnails/20002083.jpg) |

所有候选都先看过缩略图。未选草顶岩台、红砂岩房屋或民居屋顶，以免改变已批准视觉方向。门洞是真实官方模型引用，建筑单件包不含可交互门机制；金色矿物仅为装饰，不表示已实现采集或奖励。

## 固定镜头、遮挡与碰撞

构图假设：原点是观看中心，y 向上，镜头在 −z 向 +z 看。建议主 Agent 在**工作副本**的有效镜头模板上设置 `distance:18`、`fieldOfView:45`、`fixedView:{yaw:0,pitch:22,ignoreCollision:true}`；这是待实测参数，并未修改存档或创建镜头模板。若现有 UI 隐藏 3D，需使用单独检查场景确认模型，不能据“导入成功”声称战斗 UI 背景可见。

- 中央 `x ∈ [-4,4]、z ∈ [-1,1]` 保留给角色/目标，仅有地板，没有竖向装饰。
- 门洞、石柱、残墙和大石头的摆放原点均在 z≥4.7；旋转后的模型外缘不保证满足此界限，须按实际模型和镜头验收。前景只有地板与高约 0.58 米的碎石。左组高低不齐，右侧留门洞地标，避免等距排成一行。
- **7 件全部显式 `solid:false`**，无额外碰撞、触发器、导航或隐形墙。它们只是景片，不能用来封场；角色承重、出生、复苏由底图已有地面承担。本实验不保证玩家无法走出景片。
- 地板没有已实测的 `standsAt`，y=-0.1 / -0.15 只是首轮构图假设。主 Agent 应先测角色落脚高度和脚部遮挡，再改 y；不可把目录模型厚度当作实际站立高度。
- `ignoreCollision:true` 可避免固定镜头受墙碰撞推近，但不保证物件不会遮住角色。缩略图视角不证明门洞正反方向；如果试玩朝向不合适，先调整门洞 yaw，再决定扩建。
- 所有摆放点位于原点 10 米附近；不改变底图安全边界。构建工具返回的 bounds 忽略旋转，而且 y 按模型中心估算，只可作粗略包围，不能用于精准碰撞验收。

## 预算

| 项目 | 7 件景片 | 独立建筑检查包 |
|---|---:|---:|
| 静态实例 / 不同模型 | 7 / 7 | 1 / 1 |
| 动态单位 / 怪物 | 0 | 0 |
| 显式启用碰撞 / 触发器 | 0 / 0 | 0 / 0 |
| 新增灯 / 特效 / 音源 | 0 / 0 / 0 | 0 / 0 / 0 |
| Lua / 节点图 / 轮询 | 0 / 0 / 0 | 0 / 0 / 0 |

目录未提供面数、纹理显存或平台性能消耗，不能推导真实渲染预算。硬限制本轮不超过 8 个静态实例；主 Agent 通过手机画面与性能检查后才批产。主题颜色只用于选型依据，未给原生模型强行染色，也没有自行增加天空或灯光配置。

## 复用现有流水线

已安装路径：`D:\MiliastraTools\genshin-miliastra-mcp\scripts\dev\mcp_cli.mjs`。工具顺序沿用 `docs/TOOLCHAIN.md`：先读 workflow/platform-rules → 资产目录和缩略图 → 构建 → 主 Agent GUI 导入 → 从副本读回真实实体 GUID → 固定镜头试玩。此分支只做到构建。

在本 worktree 中运行（PowerShell）：

```powershell
$env:MILIASTRA_WORKSPACE = Join-Path $PWD 'build/miliastra'
$env:MILIASTRA_ALLOW_LIVE_WRITE = '0'
$env:MILIASTRA_PYTHON = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python312\python.exe'
node D:/MiliastraTools/genshin-miliastra-mcp/scripts/dev/mcp_cli.mjs call scene_build_blocks docs/art/scene-spike/geo-ruins.scene.json build/art-scene-spike
node D:/MiliastraTools/genshin-miliastra-mcp/scripts/dev/mcp_cli.mjs call scene_build_blocks docs/art/scene-spike/ruin-gateway.asset.json build/art-scene-spike
```

两个 JSON 都固化 `install:false`；输出仅在本 worktree 的 `build/miliastra`，不写官方导入目录。主 Agent 若要导入，需将构建产物按现有导入流程安装后再操作 GUI；不要通过在其他 Agent 的工作区重建来覆盖其产物。`scene_import_assets` 的前提是包已安装，它不会直接读取本地任意 GIA。每导入一次都会新增实体，重复检查前应换干净副本或按 `ARTS_` / `ARTB_` 前缀清理副本。

## 证据与待验证

离线输入回归：在仓库根目录运行 `python scripts/art/verify-scene-spike.py`，测试运行 `python -m unittest discover -s tests/art -p 'test_scene_spike.py'`。此检查只读取 JSON，核对实例预算、变换、模型选型、离线 ID 范围与记录一致性；按目录尺寸和 yaw 估计 XZ 包围盒，并检查非地板装饰是否侵入中央保留矩形。单建筑检查包不套用七件景片的中央留白条件，两包仍须分别导入干净副本。检查不读取 GIA 二进制，不验证记录的 GIA 哈希，不证明真实 GUID、碰撞、落脚高度、可见性或性能；这些仍待下列实机验证。目录中心与实际模型轴心可能不同，旋转包围盒也只作预检。

| 层 | 状态 |
|---|---|
| 目录查询 / 缩略图人工查看 | 完成，官方模型 ID 与尺寸已记录 |
| `scene_build_blocks` 构建 | 结果见 `build-result.json`、`building-build-result.json`；不是节点图编译 |
| 官方资产导入目录安装 | 未做，`install:false` |
| 写入存档副本 / 读回 GUID | 未做 |
| 游戏里显示 / 固定镜头 / 遮挡 / 脚高 / 性能 | 未做；由主 Agent 独占 GUI 验证 |
| 原始用户存档修改 / 发布 | 未做 |

继续验证使用用户存档的**副本**，不直接打开修改原档。先导入 1 件建筑包，确认它是原生 3D 模型与朝向；再在另一份干净副本导入 7 件景片，验证固定镜头、角色轮廓、地板高度以及 UI 是否遮盖背景。任一项不合格即调整本 JSON，不扩大资产数量。

缩略图取自本机已装 MCP 的只读资产目录，模型属于原神官方资产。目录元数据来源：`hang-ZYM/qianxing-format-docs`，CC BY 4.0；工具内 `src/scene/asset-catalog.json` / `src/scene/assets.mjs`。缩略图仅作为选型证据，未包含其他创作者的资产或存档。
