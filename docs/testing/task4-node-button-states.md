# TASK-4 节点按钮 hover / pressed 离线验证

基线：`origin/develop ed39f46`。分支：`feat/task4-node-button-states`。

节点框式按钮保留既有 `border / normal / disabled / selected / label / hit` 直属路径，增加隐藏的 `hover / pressed` 面层。次按钮悬停色取批准原型 `.btn:hover #353949`；主按钮悬停变亮金。按下金暗底、白字，整个容器含文字/图标/命中区按主题缩至 `0.96`，抬起恢复 `1`。现有选中结果和禁用状态优先，卡牌选择、宝箱图片仍沿用原点击流程。

路径兼容适配：没有把动态文字/图标搬进原生 preset 四态子树，因为这会改变现有 `GetChild` 路径；沿用 `cursorArea`，通过官方文档列出的事件及变换 API 控制整块按钮。此选择不表示平台 preset 控件不支持子控件缩放。

API 依据为本机官方文档 `D:/MiliastraTools/genshin-miliastra-mcp/knowledge/official/guide/mhtakr07vej4.md`：

- `Enum.CursorEventType.CursorEnter / CursorExit / CursorDown / CursorUp / CursorEndDrag`。
- `ClientUICursorEventAreaControl.AddCursorEventListener(eventType, callback)`。
- `ClientUIBaseControl.SetLocalScale(x, y, z)`、`visible` 与 `parent`。

Down / Up / Enter / Exit / EndDrag 回调不发任何业务命令，只有原有 `CursorClick` 执行 `self:press`。每种事件仅绑定一次。丢失完整指针事件能力时保留旧 C 点选；缺少颜色构造器时保留已有静态颜色/状态层，不新增 API 猜测。

验证结果：

- 先添加回归并执行，基线在首个 hover 测试报 `missing listener enter`；实现后 `node scripts/test-lua.mjs tests/lua/node_ui.lua` **25 项通过**。
- `node --test tests/node-ui-layout.test.mjs tests/native-ui-theme.test.mjs tests/game-ui.test.mjs tests/build-ui-theme.test.mjs` **20 项通过**，包括从实际导入树生成的宿主控件与各页支付/选牌/结果流程。
- 新增 6 项控件行为覆盖 hover→down→up→exit、主按钮白字、拖出/EndDrag 取消、异触点隔离、禁用不缩放、禁用变更与已选结果优先、重绘/切页/切视图/关闭重开复位、从未显示页面的迟到 Exit、一次监听以及无指针能力的 C 点选。表现事件前后对比核心状态/地图，不改变交易或 RNG。
- 布局测试限制节点树每容器子控件数 `≤50`，保留整块可点击区域、直接子路径和安全区。

本切片**未运行真实平台编译、未导出新的存档副本、未开原神、未做设备预览或实机**。由主线程在最终集成 SHA 上执行真实 MCP 编译/副本验收；窗口失焦后的原生事件顺序、触摸/手柄、实际缩放与颜色仍待同候选实机验证。TASK-4 实机 AC 不勾选。
