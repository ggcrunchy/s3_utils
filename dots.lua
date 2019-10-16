--- Functionality common to most or all "dots", i.e. objects of interest that occupy tiles.
-- The nomenclature is based on _Amazing Penguin_, this game's spiritual prequel, in which
-- such things looked like dots.
--
-- All dots support an **ActOn** method, which defines how the dot responds if acted on by
-- the player.
--
-- A dot may optionally provide other methods: **Reset** and **Update** define how the dot
-- changes state when the level resets and per-frame, respectively; **GetProperty**, called
-- with a name as argument, returns the corresponding property if available, otherwise
-- **nil** (or nothing).

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local ipairs = ipairs
local pairs = pairs
local sort = table.sort

-- Modules --
local collision = require("corona_utils.collision")
local require_ex = require("tektite_core.require_ex")
local shapes = require("s3_utils.shapes")
local tile_maps = require("s3_utils.tile_maps")

-- Corona globals --
local Runtime = Runtime
local timer = timer

-- Cached module references --
local _AddBody_
local _DeductDot_

-- Exports --
local M = {}

--
--
--

-- Tile index -> dot map --
local Dots = {}

-- Try to add a body and report success
local function AddBody (dot) 
	local body_prop = dot.body_P

	if body_prop ~= false then
		collision.MakeSensor(dot, dot.body_type_P, body_prop)

		return true
	end
end

-- How many dots are left to pick up? --
local Remaining

-- Dot type lookup table --
local DotList

--- Adds a new _name_-type sensor dot to the level.
--
-- For each name, there must be a corresponding module, the value of which will be a
-- constructor function, called as
--    cons(group, info)
-- and which returns the new dot, which must be a display object without physics.
--
-- These modules are loaded through @{tektite_core.require_ex.DoList} from **config.Dots**.
--
-- Various dot read properties (cf. @{tektite_core.table.meta.Augment}) are important:
--
-- If the **is_counted\_P** property is true, the dot will count toward the remaining dots
-- total. If this count falls to 0, the **all\_dots\_removed** event is dispatched.
--
-- If the **add\_to\_shapes\_P** property is true, the dot will be added to / may be removed from
-- shapes, and assumes that its **is_counted\_P** property is true.
--
-- Unless the **omit\_from\_event\_blocks\_P** property is true, a dot will be added to any event
-- block that it happens to occupy.
--
-- The **body\_P** and **body_type\_P** properties can be supplied to @{corona_utils.collision.MakeSensor}.
-- If **body\_P** is **false**, these properties are not assigned.
-- @pgroup group Display group that will hold the dot.
-- @ptable info Information about the new dot. Required fields:
--
-- * **col**: Column on which dot sits.
-- * **row**: Row on which dot sits.
-- * **type**: Name of dot type, q.v. _name_, above. This is also assigned as the dot's collision type.
--
-- Instance-specific data may also be passed in other fields.
-- @ptable Load parameters.
-- @see corona_utils.collision.GetType, s3_utils.shapes.RemoveAt
function M.AddDot (group, info, params)
	local dot = DotList[info.type].make(group, info, params)
	local index = tile_maps.GetTileIndex(info.col, info.row)

	tile_maps.PutObjectAt(index, dot)

	if AddBody(dot) then
		collision.SetType(dot, info.type)
	end

	local is_counted

	if dot.add_to_shapes_P then
		shapes.AddPoint(index)

		is_counted = true
	else
		is_counted = dot.is_counted_P
	end

	dot.m_count = is_counted and 1 or 0
	dot.m_index = index

	Remaining = Remaining + dot.m_count

	Dots[#Dots + 1] = dot
end

--- Deduct a remaining dot, firing off an event if it was the last one.
function M.DeductDot ()
	Remaining = Remaining - 1

	if Remaining == 0 then
		Runtime:dispatchEvent{ name = "all_dots_removed" }
	end
end

--- Handler for dot-related events sent by the editor.
-- @string type Dot type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local cons = DotList[type].editor

	if cons then
		local event = cons--("editor_event")

		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Dot to build
		if what == "build" then
			-- COMMON STUFF
			-- t.col, t.row = ...

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
--			arg1.starts_on = true
			arg1.can_attach = true

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:StockElements(event and event("get_thumb_filename"))
			arg1:AddSeparator()
--			arg1:AddCheckbox{ text = "On By Default?", value_name = "starts_on" }
			arg1:AddCheckbox{ text = "Can Attach To Event Block?", value_name = "can_attach" }
			arg1:AddSeparator()

		-- Verify --
		elseif what == "verify" then
			-- COMMON STUFF... nothing yet, I don't think, assuming well-formed editor
		end

		local result, r2, r3

		if event then
			result, r2, r3 = event(what, arg1, arg2, arg3)
		end

		return result, r2, r3
	end
end

--- Getter.
-- @treturn {string,...} Unordered list of dot type names.
function M.GetTypes ()
	local types = {}

	for k in pairs(DotList) do
		types[#types + 1] = k
	end

	return types
end

-- Per-frame setup / update
local function OnEnterFrame ()
	for _, dot in ipairs(Dots) do
		if dot.Update then
			dot:Update()
		end
	end
end

-- Dot-ordering predicate
local function DotLess (a, b)
	return a.m_index < b.m_index
end

-- Default logic for dot in block's list
local function BlockFunc (what, dot, arg1, arg2)
	local prep = dot.block_func_prep_P

	if prep and prep(what, dot, arg1, arg2) == "ignore" then
		return
	end

	if what == "get_local_xy" then
		return arg1, arg2
	elseif what == "set_content_xy" then
		dot.x, dot.y = dot.parent:contentToLocal(arg1, arg2)
	elseif what == "set_angle" then
		local on_rotate = dot.on_rotate_block_P

		if on_rotate then
			on_rotate(dot, arg1)
		else
			dot.rotation = arg1
		end
	end
end

for k, v in pairs{
	-- Act On Dot --
	act_on_dot = function(event)
		local dot = event.dot

		-- Remove the dot from any shapes it's in.
		shapes.RemoveAt(dot.m_index)

		-- If this dot counts toward the "dots remaining", deduct it.
		if dot.m_count > 0 then
			_DeductDot_()
		end

		-- Do dot-specific logic.
		if dot.ActOn then
			dot:ActOn(event.facing, event.actor)
		end
	end,

	-- Enter Level --
	enter_level = function()
		Remaining = 0

		Runtime:addEventListener("enterFrame", OnEnterFrame)
	end,

	-- Event Block Setup --
	event_block_setup = function(event)
		-- Sort the dots so that they may be incrementally traversed as we iterate the block.
		if not Dots.sorted then
			sort(Dots, DotLess)

			Dots.sorted = true
		end

		-- Accumulate any non-omitted dot inside the event block region into its list.
		local block = event.block
		local slot, n = 1, #Dots

		for index in block:IterSelf() do
			while slot <= n and Dots[slot].m_index < index do
				slot = slot + 1
			end

			local dot = Dots[slot]

			if dot and dot.m_index == index and not dot.omit_from_event_blocks_P then
				block:AddToList(dot, BlockFunc, dot.x, dot.y)
			end
		end
	end,

	-- Leave Level --
	leave_level = function()
		Dots = {}

		Runtime:removeEventListener("enterFrame", OnEnterFrame)
	end,

	-- Reset Level --
	reset_level = function()
		Remaining = 0

		for _, dot in ipairs(Dots) do
			tile_maps.PutObjectAt(dot.m_index, dot)

			dot.isVisible = true
			dot.rotation = 0

			if dot.Reset then
				dot:Reset()
			end

			Remaining = Remaining + dot.m_count
		end

		timer.performWithDelay(0, function()
			for _, dot in ipairs(Dots) do
				if collision.RemoveBody(dot) then
					AddBody(dot)
				end
			end
		end)
	end
} do
	Runtime:addEventListener(k, v)
end

DotList = require_ex.DoList("config.Dots")

_AddBody_ = M.AddBody
_DeductDot_ = M.DeductDot

return M