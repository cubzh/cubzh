-- This module only exists for test purposes.
-- It does not affect worlds in any way.

local envtest = {}

print("- _G ~= _ENV", _G ~= _ENV and "✅" or "❌")

print("- foo is nil", foo == nil and "✅" or "❌")

g = "g"
print("- set global", g == "g" and "✅" or "❌")

local l = "l"
print("- set local", l == "l" and "✅" or "❌")

return envtest