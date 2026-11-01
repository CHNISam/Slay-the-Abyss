# 824a5da 定向复跑

将 LUA_RUNNER 指向已有的原生Lua5.4 run-lua.py，不安装依赖。以下路径均相对此交接目录：

    export LUA_RUNNER=/path/to/existing/run-lua.py
    test -f "$LUA_RUNNER"
    cd head
    node scripts/build-lua-data.mjs
    node scripts/build-ui.mjs
    python "$LUA_RUNNER" ../generated-cost-regression.lua

当前head预期exit1，明确提示Blood for Blood expected cost 3, actual 4。

    python "$LUA_RUNNER" ../generated-cost-boundaries.lua

当前head预期exit1：TOTAL 11 cases, 5 failed。测试期望是真正来源规则，不是把错误签名当通过。

    python "$LUA_RUNNER" ../choice-ui-compatibility.lua

当前head预期exit0，只验证本轮已有选择接口兼容。

两个费用probe原样取自Git归档ff3d54b。generated-cost-regression.lua SHA256为6cdfb0ad57a622efbd5be6d71496ad78f5d47edbfcd1e2643fdb921978699f60；generated-cost-boundaries.lua SHA256为d572fb02a3088589efb27ddc89d962f51666b6a35dd37d776f3f47bc157eeeff。

不要将head内未列入verified-source.json的历史文件用于声称当前版本验证。当前data/UI已从列表内精确源重建，全部源码未做本地修复。
