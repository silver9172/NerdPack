local _, NeP = ...

local OPs = {
  ['>='] = function(arg1, arg2) return arg1 >= arg2 end,
  ['<='] = function(arg1, arg2) return arg1 <= arg2 end,
  ['=='] = function(arg1, arg2) return arg1 == arg2 end,
  ['~='] = function(arg1, arg2) return arg1 ~= arg2 end,
  ['>'] = function(arg1, arg2) return arg1 > arg2 end,
  ['<'] = function(arg1, arg2) return arg1 < arg2 end,
  ['+'] = function(arg1, arg2) return arg1 + arg2 end,
  ['-'] = function(arg1, arg2) return arg1 - arg2 end,
  ['/'] = function(arg1, arg2) return arg1 / arg2 end,
  ['*'] = function(arg1, arg2) return arg1 * arg2 end,
  ['!'] = function(arg1, arg2) return not NeP.DSL:Parse(arg1, arg2) end,
  ['@'] = function(arg1, arg2) return NeP.library.parse(arg1) end,
  ['true'] = function() return true end,
  ['false'] = function() return false end,
}

function NeP.DSL:DoMath(arg1, arg2, token)
  local arg1, arg2 = tonumber(arg1), tonumber(arg2)
  if arg1 ~= nil and arg2 ~= nil then
    return OPs[token](arg1, arg2)
  end
end

function NeP.DSL:_AND(Strg, Spell)
  local Arg1, Arg2 = Strg:match('(.*)&(.*)')
  local Arg1 = self:Parse(Arg1, Spell)
  if not Arg1 then return false end -- Dont process anything in front sence we already failed
  local Arg2 = self:Parse(Arg2, Spell)
  return Arg1 and Arg2
end

function NeP.DSL:_OR(Strg, Spell)
  local Arg1, Arg2 = Strg:match('(.*)||(.*)')
  local Arg1 = self:Parse(Arg1, Spell)
  if Arg1 then return true end -- Dont process anything in front sence we already hit
  local Arg2 = self:Parse(Arg2, Spell)
  return Arg1 or Arg2
end

function NeP.DSL:FindNest(Strg)
  local Start, End = Strg:find('({.*})')
  local count1, count2 = 0, 0
  for i=Start, End do
    local temp = Strg:sub(i, i)
    if temp == "{" then
      count1 = count1 + 1
    elseif temp == "}" then
      count2 = count2 + 1
    end
    if count1 == count2 then
      return Start,  i
    end
  end
end

function NeP.DSL:Nest(Strg, Spell)
  local Start, End = NeP.DSL:FindNest(Strg)
  local Result = NeP.DSL:Parse(Strg:sub(Start+1, End-1), Spell)
  Result = tostring(Result or false)
  Strg = Strg:sub(1, Start-1)..Result..Strg:sub(End+1)
  return self:Parse(Strg, Spell)
end

function NeP.DSL:ProcessCondition(Strg, Spell)
  -- Process Unit Stuff
  local unitID, rest = strsplit('.', Strg, 2)
  local target =  'player' -- default target
  unitID =  NeP.FakeUnits.Filter(unitID)
  if unitID and UnitExists(unitID) then
    target = unitID
    Strg = rest
  end
  -- Condition arguments
  local Args = Strg:match('%((.+)%)')
  if Args then 
    Args = NeP.Locale.Spells(Args) -- Translates the name to the correct locale
    Strg = Strg:gsub('%((.+)%)', '')
  else
    Args = Spell
  end
  Strg = Strg:gsub('%s', '')
  -- Process the Condition itself
  local Condition = self:Get(Strg)
  if Condition then return Condition(target, Args) end
end

local fOps = {['!='] = '~=',['='] = '=='}
function NeP.DSL:Comperatores(Strg, Spell)
  local OP = ''
  for Token in Strg:gmatch('[><=~]') do OP = OP..Token end
  if Strg:find('!=') then OP = '!=' end
  local arg1, arg2 = unpack(NeP.string_split(Strg, OP))
  arg1, arg2 = self:Parse(arg1, Spell), DSL.Parse(arg2, Spell)
  return self:DoMath(arg1, arg2, (fOps[OP] or OP))
end

function NeP.DSL:StringMath(Strg, Spell)
  local OP, total = Strg:match('[/%*%+%-]'), 0
  local tempT = NeP.string_split(Strg, OP)
  for i=1, #tempT do
    local Strg = self:Parse(tempT[i], Spell)
    if total == 0 then
      total = Strg
    else
      total = self:DoMath(total, Strg, OP)
    end
  end
  return total
end

function NeP.DSL:ExeFunc(Strg)
  local Args = Strg:match('%((.+)%)')
  if Args then Strg = Strg:gsub('%((.+)%)', '') end
  return _G[Strg](Args)
end

function NeP.DSL:RemoveSpaces(Strg)
  if Strg:find('^%s') then
    Strg = Strg:sub(2);
  end
  if Strg:find('$%s') then
    Strg = Strg:sub(-2);
  end
  return Strg
end

-- Routes
local typesTable = {
  ['function'] = function(dsl, Spell) return dsl() end,
  ['table'] = function(dsl, spell)
    local r_Tbl = {[1] = true}
    for i=1, #dsl do
      local Strg = dsl[i]
      if Strg == 'or' then
        r_Tbl[#r_Tbl+1] = true
      elseif r_Tbl[#r_Tbl] then
        local eval = NeP.DSL:Parse(Strg, spell)
        r_Tbl[#r_Tbl] = eval or false
      end
    end
    for i = 1, #r_Tbl do
      if r_Tbl[i] then
        return true
      end
    end
    return false
  end,
  ['string'] = function(Strg, Spell)
    Strg = NeP.DSL:RemoveSpaces(Strg)
    local pX = Strg:sub(1, 1)
    if Strg:find('{(.-)}') then
      return NeP.DSL:Nest(Strg, Spell)
    elseif Strg:find('||') then
      return NeP.DSL:_OR(Strg, Spell)
    elseif Strg:find('&') then
      return NeP.DSL:_AND(Strg, Spell)
    elseif OPs[pX] then
      Strg = Strg:sub(2);
      return OPs[pX](Strg, Spell)
    elseif Strg:find("func=") then
      Strg = Strg:sub(6);
      return NeP.DSL:ExeFunc(Strg)
    elseif Strg:find('[><=~]') then
      return NeP.DSL:Comperatores(Strg, Spell)
    elseif Strg:find('!=') then
      return NeP.DSL:Comperatores(Strg, Spell)
    elseif Strg:find("[/%*%+%-]") then
      return NeP.DSL:StringMath(Strg, Spell)
    elseif OPs[Strg] then
      return OPs[Strg](Strg, Spell)
    elseif Strg:find('%a') then
      return NeP.DSL:ProcessCondition(Strg, Spell)
    else
      return Strg
    end
  end,
  ['nil'] = function(dsl, Spell) return true end,
  ['boolean']  = function(dsl, Spell) return dsl end,
}

function NeP.DSL:Parse(dsl, Spell)
  if typesTable[type(dsl)] then
    return typesTable[type(dsl)](dsl, Spell)
  end
end

NeP.Globals.DSL.Parse = NeP.DSL.Parse