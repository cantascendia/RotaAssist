-- Minimal busted-compatible shim for running specific tests under plain Lua 5.1.
-- Used only as a local sanity-check when busted is unavailable.
-- 仅在没有 busted 时本地快速验证用，CI 仍由真实 busted 执行。

local M = {}

local stack = {}
local results = { total = 0, failed = 0, errors = {} }

local function indent()
    return string.rep("  ", #stack)
end

local function joinPath()
    return table.concat(stack, " > ")
end

local _setup, _before_each, _after_each, _teardown

local function describe(name, fn)
    table.insert(stack, name)
    print(indent() .. "[describe] " .. name)
    -- Each describe block has its own setup/before_each scope.
    local prev_setup, prev_before, prev_after, prev_teardown = _setup, _before_each, _after_each, _teardown
    _setup, _before_each, _after_each, _teardown = nil, nil, nil, nil
    if _setup_inherit ~= false then
        -- Inherit parent before_each (busted does this)
        _before_each = prev_before
    end
    local ok, err = pcall(fn)
    if not ok then
        results.failed = results.failed + 1
        results.errors[#results.errors + 1] = string.format("%s: describe error: %s", joinPath(), err)
        print(indent() .. "  ERROR in describe: " .. tostring(err))
    end
    if _teardown then pcall(_teardown) end
    _setup, _before_each, _after_each, _teardown = prev_setup, prev_before, prev_after, prev_teardown
    table.remove(stack)
end

local function setup_fn(fn) _setup = fn; pcall(fn) end
local function teardown_fn(fn) _teardown = fn end
local function before_each_fn(fn) _before_each = fn end
local function after_each_fn(fn) _after_each = fn end

local function it(name, fn)
    results.total = results.total + 1
    if _before_each then
        local ok, err = pcall(_before_each)
        if not ok then
            results.failed = results.failed + 1
            results.errors[#results.errors + 1] = string.format("%s > %s (before_each): %s", joinPath(), name, err)
            print(indent() .. "  FAIL (before_each) " .. name .. ": " .. tostring(err))
            return
        end
    end
    local ok, err = pcall(fn)
    if _after_each then pcall(_after_each) end
    if ok then
        print(indent() .. "  PASS " .. name)
    else
        results.failed = results.failed + 1
        results.errors[#results.errors + 1] = string.format("%s > %s: %s", joinPath(), name, err)
        print(indent() .. "  FAIL " .. name .. ": " .. tostring(err))
    end
end

-- Minimal assert.* compatible API
local A = {}

local function fail(msg)
    error(msg or "assertion failed", 3)
end

function A.equals(expected, actual, msg)
    if expected ~= actual then
        fail(string.format("%s: expected %s, got %s", msg or "equals", tostring(expected), tostring(actual)))
    end
end
A.equal = A.equals
A.are = setmetatable({}, { __index = function(_, k)
    if k == "equal" or k == "equals" then return A.equals end
    if k == "same" then return A.equals end
end })

function A.is_true(v, msg)
    if v ~= true and not v then
        fail(string.format("%s: expected truthy, got %s", msg or "is_true", tostring(v)))
    end
end

function A.is_false(v, msg)
    if v then fail(string.format("%s: expected false, got %s", msg or "is_false", tostring(v))) end
end

function A.is_nil(v, msg)
    if v ~= nil then fail(string.format("%s: expected nil, got %s", msg or "is_nil", tostring(v))) end
end

function A.is_not_nil(v, msg)
    if v == nil then fail(string.format("%s: expected non-nil", msg or "is_not_nil")) end
end

function A.is_table(v, msg)
    if type(v) ~= "table" then fail(string.format("%s: expected table, got %s", msg or "is_table", type(v))) end
end

function A.is_number(v, msg)
    if type(v) ~= "number" then fail(string.format("%s: expected number, got %s", msg or "is_number", type(v))) end
end

function A.is_string(v, msg)
    if type(v) ~= "string" then fail(string.format("%s: expected string, got %s", msg or "is_string", type(v))) end
end

function A.is_function(v, msg)
    if type(v) ~= "function" then fail(string.format("%s: expected function, got %s", msg or "is_function", type(v))) end
end

-- Make 'assert' callable like busted (assert(x) and assert.is_true(x) both supported)
local _real_assert = assert
local proxy = setmetatable({}, {
    __call = function(_, v, msg) if not v then fail(msg or "assertion failed") end end,
    __index = A,
})
_G.assert = proxy

_G.describe = describe
_G.it = it
_G.setup = setup_fn
_G.teardown = teardown_fn
_G.before_each = before_each_fn
_G.after_each = after_each_fn

function M.run(testFiles)
    for _, path in ipairs(testFiles) do
        print("\n=== " .. path .. " ===")
        local fn, err = loadfile(path)
        if not fn then
            results.failed = results.failed + 1
            results.errors[#results.errors + 1] = path .. ": loadfile failed: " .. tostring(err)
            print("LOADFILE FAIL: " .. tostring(err))
        else
            local ok, runErr = pcall(fn)
            if not ok then
                results.failed = results.failed + 1
                results.errors[#results.errors + 1] = path .. ": " .. tostring(runErr)
                print("RUN FAIL: " .. tostring(runErr))
            end
        end
    end
    print(string.format("\n--- Summary: %d total, %d failed ---", results.total, results.failed))
    if #results.errors > 0 then
        print("\nFailures:")
        for _, e in ipairs(results.errors) do print("  " .. e) end
    end
    -- Restore real assert just in case
    _G.assert = _real_assert
    return results.failed == 0
end

return M
