------------------------------------------------------------------------
-- RotaAssist local test runner — a minimal busted-compatible shim.
-- 本地测试运行器：busted 兼容层（纯 Lua 5.1，零依赖）。
--
-- Why this exists / 为什么存在:
--   The repo's CI is unavailable and neither busted nor luacheck can be
--   installed on this machine (LuaRocks lacks a C compiler for modern
--   luafilesystem). This shim implements exactly the busted/luassert
--   surface the test suite uses (surveyed 2026-09-01):
--     describe / it / setup / teardown / before_each / after_each / pending
--     assert.equals, is_true, is_false, is_nil, is_not_nil, is_table,
--     is_number, is_function, is_string, is_boolean, is_near,
--     has_no.errors, is_not.equals, not_equals
--   No spy/stub/mock usage exists in tests/ — deliberately not implemented.
--   CI 不可用且本机装不了 busted，本文件按实测清单实现测试套件用到的
--   全部 busted/luassert API。tests/ 未用 spy/stub/mock，故不实现。
--
-- Usage / 用法 (from repo root / 在仓库根目录):
--   lua scripts/run_tests.lua              -- run all tests/test_*.lua
--   lua scripts/run_tests.lua registry sqm -- only files whose name matches
--
-- Semantics mirror busted: describe bodies run immediately to collect the
-- tree; `setup` runs once per block before its first test; before_each /
-- after_each run around every test including nested blocks' tests.
-- All files share one Lua state (same as `busted tests/` in one process).
------------------------------------------------------------------------

-- Allow `require("tests.helpers")` from repo root.
package.path = "./?.lua;./?/init.lua;" .. package.path

------------------------------------------------------------------------
-- Assertion shim (luassert-compatible subset)
------------------------------------------------------------------------

local PENDING_SENTINEL = { __pending = true }

local function fail(msg, level)
    error(msg, (level or 2) + 1)
end

local function fmt(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

local assertShim = setmetatable({}, {
    __call = function(_, v, msg, ...)
        if not v then error(msg or "assertion failed!", 2) end
        return v, msg, ...
    end,
})

function assertShim.equals(expected, actual, msg)
    if expected ~= actual then
        fail((msg and msg .. "\n" or "")
            .. "Expected " .. fmt(expected) .. " but got " .. fmt(actual))
    end
end
assertShim.equal = assertShim.equals
assertShim.are = { equal = assertShim.equals, equals = assertShim.equals,
                   same = nil }  -- assert.are.same (deep) unused; keep explicit nil

function assertShim.not_equals(expected, actual, msg)
    if expected == actual then
        fail((msg and msg .. "\n" or "")
            .. "Expected value to differ from " .. fmt(expected))
    end
end

assertShim.is_not = { equals = assertShim.not_equals, equal = assertShim.not_equals }

local function typeCheck(wanted)
    return function(v, msg)
        if type(v) ~= wanted then
            fail((msg and msg .. "\n" or "")
                .. "Expected type " .. wanted .. " but got " .. type(v)
                .. " (" .. fmt(v) .. ")")
        end
    end
end

assertShim.is_table    = typeCheck("table")
assertShim.is_number   = typeCheck("number")
assertShim.is_function = typeCheck("function")
assertShim.is_string   = typeCheck("string")
assertShim.is_boolean  = typeCheck("boolean")

function assertShim.is_true(v, msg)
    if v ~= true then
        fail((msg and msg .. "\n" or "") .. "Expected true but got " .. fmt(v))
    end
end

function assertShim.is_false(v, msg)
    if v ~= false then
        fail((msg and msg .. "\n" or "") .. "Expected false but got " .. fmt(v))
    end
end

function assertShim.is_nil(v, msg)
    if v ~= nil then
        fail((msg and msg .. "\n" or "") .. "Expected nil but got " .. fmt(v))
    end
end

function assertShim.is_not_nil(v, msg)
    if v == nil then
        fail((msg and msg .. "\n" or "") .. "Expected a non-nil value")
    end
end

function assertShim.is_near(expected, actual, tolerance, msg)
    if type(actual) ~= "number" or math.abs(expected - actual) > tolerance then
        fail((msg and msg .. "\n" or "")
            .. "Expected " .. fmt(actual) .. " to be within "
            .. tostring(tolerance) .. " of " .. fmt(expected))
    end
end

assertShim.has_no = {
    errors = function(fn, msg)
        local ok, err = pcall(fn)
        if not ok then
            fail((msg and msg .. "\n" or "")
                .. "Expected no error but got: " .. tostring(err))
        end
    end,
}
assertShim.has_no_errors = assertShim.has_no.errors

------------------------------------------------------------------------
-- Test tree collection (busted DSL)
------------------------------------------------------------------------

local function newBlock(name, parent)
    return {
        name = name, parent = parent,
        children = {},          -- ordered: {kind="it"|"block"|"pending", ...}
        setups = {}, teardowns = {},
        beforeEach = {}, afterEach = {},
    }
end

local root = newBlock("", nil)
local current = root

local function dsl_describe(name, fn)
    local block = newBlock(name, current)
    current.children[#current.children + 1] = { kind = "block", block = block }
    local saved = current
    current = block
    local ok, err = pcall(fn)
    current = saved
    if not ok then
        -- Collection-time failure: record as a failing "test" so it is reported.
        block.children[#block.children + 1] = {
            kind = "it", name = "<describe body failed>",
            fn = function() error(err, 0) end,
        }
    end
end

local function dsl_it(name, fn)
    current.children[#current.children + 1] = { kind = "it", name = name, fn = fn }
end

-- `pending` has two busted forms:
--   collection phase (inside describe body): registers a skipped entry;
--   execution phase (inside a running it): aborts that test as pending.
-- The `inRun` flag below distinguishes the two.
local inRun = false
local function dsl_pending(name, fn)  -- luacheck: ignore fn (busted ignores it too)
    if inRun then
        error(PENDING_SENTINEL)
    end
    current.children[#current.children + 1] = { kind = "pending", name = name or "(pending)" }
end

local function reg(list)
    return function(fn) list[#list + 1] = fn end
end

------------------------------------------------------------------------
-- Runner
------------------------------------------------------------------------

local counts = { pass = 0, fail = 0, pending = 0 }
local failures = {}

local function pathOf(block, leaf)
    local parts = {}
    local b = block
    while b and b.name ~= "" do
        table.insert(parts, 1, b.name)
        b = b.parent
    end
    parts[#parts + 1] = leaf
    return table.concat(parts, " > ")
end

local function chainBeforeEach(block, out)
    if block.parent then chainBeforeEach(block.parent, out) end
    for _, fn in ipairs(block.beforeEach) do out[#out + 1] = fn end
end

local function chainAfterEach(block, out)
    for _, fn in ipairs(block.afterEach) do out[#out + 1] = fn end
    if block.parent then chainAfterEach(block.parent, out) end
end

local function runTest(block, entry, fileLabel)
    local pre, post = {}, {}
    chainBeforeEach(block, pre)
    chainAfterEach(block, post)

    local function body()
        for _, fn in ipairs(pre) do fn() end
        entry.fn()
    end

    inRun = true
    local ok, err = pcall(body)
    inRun = false
    -- after_each always runs, mirroring busted.
    for _, fn in ipairs(post) do pcall(fn) end

    if ok then
        counts.pass = counts.pass + 1
    elseif err == PENDING_SENTINEL
        or (type(err) == "table" and err.__pending) then
        counts.pending = counts.pending + 1
    else
        counts.fail = counts.fail + 1
        failures[#failures + 1] = {
            file = fileLabel,
            path = pathOf(block, entry.name),
            err  = tostring(err),
        }
        io.write("F")
        return
    end
    io.write(ok and "." or "P")
end

local function runBlock(block, fileLabel)
    for _, fn in ipairs(block.setups) do
        local ok, err = pcall(fn)
        if not ok then
            counts.fail = counts.fail + 1
            failures[#failures + 1] = {
                file = fileLabel,
                path = pathOf(block, "<setup>"),
                err  = tostring(err),
            }
            io.write("F")
            return  -- setup failed: skip the whole block, same as busted
        end
    end
    for _, entry in ipairs(block.children) do
        if entry.kind == "it" then
            runTest(block, entry, fileLabel)
        elseif entry.kind == "pending" then
            counts.pending = counts.pending + 1
            io.write("P")
        else
            runBlock(entry.block, fileLabel)
        end
    end
    for _, fn in ipairs(block.teardowns) do pcall(fn) end
end

------------------------------------------------------------------------
-- File discovery & main
------------------------------------------------------------------------

local function listTestFiles()
    local files = {}
    -- Windows dir + POSIX ls fallback; sorted for deterministic order.
    local h = io.popen('dir /b tests\\test_*.lua 2>nul') or io.popen('ls tests/test_*.lua 2>/dev/null')
    if h then
        for line in h:lines() do
            local name = line:match("(test_[%w_]+%.lua)$")
            if name then files[#files + 1] = "tests/" .. name end
        end
        h:close()
    end
    table.sort(files)
    return files
end

local filters = {}
for i = 1, select("#", ...) do filters[#filters + 1] = (select(i, ...)) end

local files = listTestFiles()
if #files == 0 then
    io.stderr:write("No test files found. Run from the repo root.\n")
    os.exit(2)
end

-- Install globals
_G.describe    = dsl_describe
_G.it          = dsl_it
_G.pending     = dsl_pending
_G.setup       = function(fn) reg(current.setups)(fn) end
_G.teardown    = function(fn) reg(current.teardowns)(fn) end
_G.before_each = function(fn) reg(current.beforeEach)(fn) end
_G.after_each  = function(fn) reg(current.afterEach)(fn) end
_G.assert      = assertShim

local started = os.clock()

------------------------------------------------------------------------
-- File-level insulation, mirroring busted's default behavior.
-- busted snapshots and restores the environment between test files; without
-- this, a file that mutates mock state (e.g. swaps C_Spell.GetSpellCooldown)
-- silently breaks later files — an order dependency the CI runs never showed.
-- 文件级隔离（对齐 busted 默认行为）：每个文件后恢复全局环境并强制重载
-- mock，否则前面文件对 mock 的改动会污染后面的文件（顺序依赖）。
------------------------------------------------------------------------
local function snapshotGlobals()
    local snap = {}
    for k, v in pairs(_G) do snap[k] = v end
    return snap
end

local function restoreGlobals(snap)
    for k in pairs(_G) do
        if snap[k] == nil then _G[k] = nil end
    end
    for k, v in pairs(snap) do _G[k] = v end
end

local function resetModules()
    -- Force tests.helpers (and its _mockLoaded upvalue) to reload next require,
    -- which in turn reloads mock_wow_api.lua and rebuilds every mock API table.
    for name in pairs(package.loaded) do
        if name:match("^tests%.") then package.loaded[name] = nil end
    end
end

for _, file in ipairs(files) do
    local keep = #filters == 0
    for _, f in ipairs(filters) do
        if file:find(f, 1, true) then keep = true break end
    end
    if keep then
        -- Fresh subtree per file, insulated environment (matches busted).
        local snap = snapshotGlobals()
        resetModules()
        root = newBlock("", nil)
        current = root
        io.write(file, " ")
        local fn, loadErr = loadfile(file)
        if not fn then
            counts.fail = counts.fail + 1
            failures[#failures + 1] = { file = file, path = "<loadfile>", err = tostring(loadErr) }
            io.write("F\n")
        else
            local ok, err = pcall(fn)
            if not ok then
                counts.fail = counts.fail + 1
                failures[#failures + 1] = { file = file, path = "<file body>", err = tostring(err) }
                io.write("F\n")
            else
                runBlock(root, file)
                io.write("\n")
            end
        end
        restoreGlobals(snap)
    end
end

local elapsed = os.clock() - started

print(string.rep("-", 60))
print(string.format("%d passed / %d failed / %d pending  (%.2fs)",
    counts.pass, counts.fail, counts.pending, elapsed))

if #failures > 0 then
    print()
    for i, f in ipairs(failures) do
        print(string.format("FAIL %d) %s :: %s", i, f.file, f.path))
        print("     " .. f.err:gsub("\n", "\n     "))
    end
    os.exit(1)
end
os.exit(0)
