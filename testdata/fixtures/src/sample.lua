--[[
  sample.lua — comprehensive Lua syntax fixture for parser testing.
  Covers: tables, metatables, OOP, closures, coroutines, iterators,
  error handling, modules, varargs, string patterns, bit ops, environments.
]]

-- -------------------------------------------------------------------------- --
-- Constants
-- -------------------------------------------------------------------------- --

local MAX_RETRIES = 3
local DEFAULT_TIMEOUT = 30.0
local GREETING = "hello"

-- -------------------------------------------------------------------------- --
-- Basic types & operators
-- -------------------------------------------------------------------------- --

local int_val  = 42
local float_val = 3.14
local big_int  = 0x7FFFFFFF
local str_val  = "hello, world"
local long_str = [[
  multi-line
  string literal
]]
local bool_t   = true
local null_val = nil

-- Arithmetic & logical
local result = (int_val + float_val) * 2 - 1
local concat = str_val .. " " .. tostring(int_val)
local len    = #str_val
local band   = int_val & 0xFF     -- bitwise AND (Lua 5.3+)
local bor    = int_val | 0x100
local bxor   = int_val ~ 0x0F
local bnot   = ~int_val
local lsh    = int_val << 2
local rsh    = int_val >> 1

-- -------------------------------------------------------------------------- --
-- Tables (arrays and dicts)
-- -------------------------------------------------------------------------- --

local arr = {10, 20, 30, 40, 50}
local dict = { name = "Alice", age = 30, active = true }
local mixed = { 1, 2, key = "value", nested = { a = 1, b = 2 } }

arr[#arr + 1] = 60              -- append
table.insert(arr, 70)
table.remove(arr, 1)
table.sort(arr, function(a, b) return a > b end)

-- -------------------------------------------------------------------------- --
-- Functions
-- -------------------------------------------------------------------------- --

local function add(a, b)
  return a + b
end

local multiply = function(x, y) return x * y end

-- Multiple return values
local function min_max(t)
  local lo, hi = t[1], t[1]
  for _, v in ipairs(t) do
    if v < lo then lo = v end
    if v > hi then hi = v end
  end
  return lo, hi
end

-- Varargs
local function sum(...)
  local total = 0
  for _, v in ipairs({...}) do total = total + v end
  return total
end

-- Default arguments via "or"
local function greet(name, greeting)
  greeting = greeting or GREETING
  return greeting .. ", " .. name .. "!"
end

-- Closures
local function make_counter(start)
  local count = start or 0
  return {
    increment = function() count = count + 1 end,
    decrement = function() count = count - 1 end,
    value     = function() return count end,
  }
end

-- -------------------------------------------------------------------------- --
-- Metatables & OOP
-- -------------------------------------------------------------------------- --

local Animal = {}
Animal.__index = Animal

function Animal.new(name, weight)
  local self = setmetatable({}, Animal)
  self.name   = name
  self.weight = weight
  return self
end

function Animal:speak()
  return self.name .. " says ..."
end

function Animal:__tostring()
  return ("Animal(%s, %.1fkg)"):format(self.name, self.weight)
end

function Animal:__lt(other)
  return self.weight < other.weight
end

-- Inheritance
local Dog = setmetatable({}, { __index = Animal })
Dog.__index = Dog

function Dog.new(name, weight, breed)
  local self = Animal.new(name, weight)
  setmetatable(self, Dog)
  self.breed  = breed
  self.tricks = {}
  return self
end

function Dog:speak()
  return self.name .. " says woof!"
end

function Dog:learn(trick)
  table.insert(self.tricks, trick)
  return self    -- fluent interface
end

function Dog:perform()
  local out = {}
  for _, t in ipairs(self.tricks) do
    out[#out + 1] = self.name .. " performs " .. t
  end
  return out
end

-- -------------------------------------------------------------------------- --
-- Iterators & coroutines
-- -------------------------------------------------------------------------- --

local function fibonacci()
  local a, b = 0, 1
  return function()
    local v = a
    a, b = b, a + b
    return v
  end
end

local function range(from, to, step)
  step = step or 1
  return function(_, i)
    i = i + step
    if i <= to then return i end
  end, nil, from - step
end

-- Coroutine-based generator
local function fibonacci_co()
  return coroutine.wrap(function()
    local a, b = 0, 1
    while true do
      coroutine.yield(a)
      a, b = b, a + b
    end
  end)
end

-- -------------------------------------------------------------------------- --
-- Error handling
-- -------------------------------------------------------------------------- --

local function safe_call(fn, ...)
  local ok, result = pcall(fn, ...)
  if not ok then
    return nil, result   -- result holds error message
  end
  return result
end

local function safe_divide(a, b)
  if b == 0 then
    error(("division by zero: %d / %d"):format(a, b), 2)
  end
  return a / b
end

local val, err = safe_call(safe_divide, 10, 0)
if err then io.stderr:write("error: " .. err .. "\n") end

-- xpcall with traceback
local function with_traceback(fn, ...)
  return xpcall(fn, function(e)
    return e .. "\n" .. debug.traceback("", 2)
  end, ...)
end

-- -------------------------------------------------------------------------- --
-- String patterns
-- -------------------------------------------------------------------------- --

local date = "2026-06-04"
local year, month, day = date:match("(%d%d%d%d)-(%d%d)-(%d%d)")

local words = {}
for w in ("one two three four"):gmatch("%S+") do
  words[#words + 1] = w
end

local snake = ("CamelCaseName"):gsub("%u", function(c)
  return "_" .. c:lower()
end):gsub("^_", "")

-- -------------------------------------------------------------------------- --
-- Modules (returns a table)
-- -------------------------------------------------------------------------- --

local M = {}

M.VERSION = "1.0.0"

function M.greet(name) return greet(name) end
function M.fibonacci() return fibonacci() end

M.Animal = Animal
M.Dog    = Dog

-- -------------------------------------------------------------------------- --
-- Entry point
-- -------------------------------------------------------------------------- --

local dog = Dog.new("Rex", 30, "Labrador")
dog:learn("sit"):learn("shake")
print(dog:speak())
for _, line in ipairs(dog:perform()) do print(line) end

local fib = fibonacci_co()
local fibs = {}
for _ = 1, 10 do fibs[#fibs + 1] = fib() end
print(table.concat(fibs, ", "))

local lo, hi = min_max({3, 1, 4, 1, 5, 9, 2, 6})
print(("min=%d  max=%d"):format(lo, hi))

return M
