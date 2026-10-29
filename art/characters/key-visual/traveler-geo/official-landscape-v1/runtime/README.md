# 专用背景宿主适配

本目录是资产级生命周期组件，不是共享UI改版，也尚未注册到正式构建。数据固定绑定已认可的完整导出SHA，原图元不改。

## 接入合同

在本次候选中将 `background_adapter.lua` 与 `background_data.lua` 注册为独立客户端模块。由UI接入者提供**专用背景容器**和本次生成的图片模板索引；不要挂在现有UI根或把图库100001当模板。

调用形式：`Adapter.new(host, data, { imagePrefabId = actualTemplateIndex, batchSize = 64 })`。

1. `begin()`返回成功及generation；同一host再次请求不会重复实例化，同一ready对象不会重建。
2. 仅启动/选角持有者在更新回调中调用`tick(generation)`；每次最多64条，构建期间宿主隐藏，完成才显示。ready后调用不再逐图元写入。207次tick只是调用数，不代表耗时或FPS；批量64是可配置的保守起点，不是实测最优值。
3. 逻辑480×270的宿主只缩放一次8/3，匹配项目1280×720设计画布；再由现有Viewport处理设备画布。不得二次缩放子图元，也不得把横图拉伸进320×420竖槽。
4. 退出这两个页面、进入战斗或取消加载时调用`release()`，先使generation失效再隐藏/回收；迟到tick不能重新创建或显示。失败不会每帧自动重试，必须显式`retry()`。
5. `release()`目前同步遍历已创建控件；失败销毁的句柄保留在`status()`中供显式重试，不能声称已释放。实际退出卡顿仍需设备测量。
6. 引擎销毁宿主时调用`onEngineDestroy()`，只退休回调和引用，不再对引擎已销毁的子树调用Destroy。该宿主即使alive暂未更新，也不能重新启用。

所有setter/创建/回收的异常和false返回均需保留诊断；不要吞掉失败后把占位状态改成正式通过。此组件不改标题、按钮、输入、Grok共享UI或Dot B资产，也不自动创建设备测试窗口。

## 复验

`node --test tests/official-background-lifecycle.test.mjs` 使用仓库锁定的Fengari和固定编辑器的原始测试VM helper（仅测试夹具，GPL声明位于tests/fixtures）；不需要下载SDK、安装新包或访问客户端。19项覆盖原13201行属性/顺序、每tick上限、取消/重入、创建与setter失败、重复进入、显式重试、销毁失败保留、引擎销毁和单次缩放。

`prepare_data.py --source-lua ../native-art.lua --native-json ../native-art.json --output <新data.lua> --receipt <新receipt.json>`仅提取原字面ROOT/ELEMENTS，先验原文件哈希，不重新拟合/渲染，不覆盖已有输出。已有`background_data.lua`已逐字绑定原表。

Lua图元属性序列参考Primitive MIT/LiuL基础运行时，原许可在上一级目录。项目新增生命周期逻辑与测试中的原创部分依仓库LICENSE；固定编辑器测试夹具的GPL不因此转授项目角色内容。
