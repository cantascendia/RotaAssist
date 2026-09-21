"""test: generated hostile-range populations cannot inflate a known lower bound."""
import subprocess
from pathlib import Path

from hypothesis import given, settings, strategies as st

ROOT = Path(__file__).resolve().parents[1]
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"


@settings(max_examples=20, deadline=None)
@given(st.lists(st.tuples(st.booleans(), st.booleans(), st.booleans()), max_size=39))
def test_nearby_count_ignores_far_idle_and_dead_units(population):
    def boolean(value):
        return "true" if value else "false"

    rows = ",".join("{" + ",".join(map(boolean, item)) + "}" for item in population)
    script = r'''
local helpers = require("tests.helpers")
local RA, ns = helpers.loadAddon()
helpers.loadRegistry(ns)
local population = {ROWS}
local units = { target = { true, false, false, "T" } }
for i, data in ipairs(population) do
    data[4] = "E" .. i
    units["nameplate" .. i] = data
end
-- Explicit target duplicate must never increase the count.
units.nameplate40 = units.target
UnitExists = function(u) return units[u] ~= nil end
UnitCanAttack = function() return true end
UnitIsDead = function(u) return units[u][3] end
UnitAffectingCombat = function(u) return units[u][2] end
UnitGUID = function(u) return units[u][4] end
UnitIsUnit = function(a,b) return units[a][4] == units[b][4] end
IsPlayerSpell = function() return true end
C_Spell.IsSpellInRange = function(_,u) return units[u][1] end
RA:RegisterModule("SpecDetector", { GetCurrentSpec = function() return { specID = 577 } end })
assert(helpers.loadAddonFile("addon/Engine/TargetContext.lua", "RotaAssist", ns))
local context = RA:GetModule("TargetContext")
context:OnEnable()
io.write(tostring(context:GetSnapshot().nearbyEnemies))
'''.replace("ROWS", rows)
    result = subprocess.run([LUA, "-e", script], cwd=ROOT, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    expected = 1 + sum(in_range and engaged and not dead for in_range, engaged, dead in population)
    assert int(result.stdout) == expected
