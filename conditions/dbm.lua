local _, NeP = ...
NeP.DBM = {}

if not _G.DBM then return end

NeP.Cache.DBM_Timers = {}
local fake_timer = 999

function NeP.DBM.BuildTimers()
  for bar in pairs(_G.DBM.Bars.bars) do
      local id = _G.GetSpellInfo(bar.id:match("%d+")) or bar.id:lower()
      NeP.Cache.DBM_Timers[id] = bar.timer and bar.timer > 0.1 or fake_timer
  end
end

NeP.DSL:Register('dbm', function(_, event)
  return NeP.Cache.DBM_Timers[event:lower()] or fake_timer
end)

--Export to globals
NeP.Globals.DBM = NeP.DBM
