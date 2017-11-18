local _, NeP = ...
NeP.Units = {}
NeP.Unit.Units = {}

local Units = NeP.Unit.Units

local function _add(name, func)
	if not Units[name] then
		Units[name] = func
	end
end

function NeP.Unit.Add(_, name, func)
	if type(name) == 'table' then
		for i=1, #name do
			_add(name[i], func)
		end
	elseif type(name) == 'string' then
		_add(name, func)
	else
		NeP.Core:Print("ERROR! tried to add an invalid fake unit")
	end
end

-- /dump NeP.Units:Filter("lowest")
local function process(unit)
	local arg = unit:match('%((.+)%)')
	local num = tonumber(unit:match("%d+") or 0)
	local tunit = unit:gsub('%((.+)%)', ''):gsub("%d+", '')
	return Units[tunit] and Units[tunit](num, arg) or unit
end

local function not_in_tbl(unit, tbl)
	for i=1, #tbl do
		if tbl[i] == unit then return false end
	end
	return true
end

-- If the fake unit returns a table then we need
-- to merge it, EX: {tank, enemies}
-- tank is a single unit while enemie is a table
local function add_tbl(unit, tbl)
	local unit_type = type(unit)
	--table
	if unit_type =='table' then
		for _, v in pairs(unit) do
			NeP.Units:Process(v.key or v, tbl)
		end
	--function
	elseif unit_type == 'function' then
		NeP.Units:Process(unit(), tbl)
	--add
	elseif unit_type == 'string' then
		unit = process(unit)
		if not unit then return end
		if type(unit) ~= 'string' then
			NeP.Units:Process(unit, tbl)
		elseif not_in_tbl(unit, tbl) then
			tbl[#tbl+1] = unit
		end
	end
end

function NeP.Unit.Process(unit, tbl)
	tbl = tbl or {}
	add_tbl(unit, tbl)
	return tbl
end

--cache
NeP.Cache.Targets = {}
local C = NeP.Cache.Targets

function NeP.Unit.Filter(unit, tbl)
	-- cached
	if not C[unit] then
		C[unit] = NeP.Units:Process(unit, tbl)
	end
	return C[unit]
end
