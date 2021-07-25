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
local sort = table.sort

-- Modules --
local collision = require("solar2d_utils.collision")
local shapes = require("s3_utils.shapes")
local tile_layout = require("s3_utils.tile_layout")

-- Solar2D globals --
local Runtime = Runtime
local timer = timer

-- Cached module references --
local _DeductDot_

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.EditorEvent ()
	return {
		inputs = {
			boolean = { can_attach = true }
		}
	}
	-- ^^ TODO: inherit this somehow
end

--
--
--

local function TryToAddBody (dot) 
	local body_prop = dot.body_P

	if body_prop ~= false then
		collision.MakeSensor(dot, dot.body_type_P, body_prop)

		return true
	end
end

-- Tile index -> dot map --
local Dots

local PreviousTime

local function OnEnterFrame (event)
	local now, dt = event.time, 0

	if PreviousTime then
		dt = (now - PreviousTime) / 1000
	end

	PreviousTime = now

	for _, dot in ipairs(Dots) do
		if dot.Update then
			dot:Update(dt)
		end
	end
end

-- How many dots are left to pick up? --
local Remaining

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
-- The **body\_P** and **body_type\_P** properties can be supplied to @{solar2d_utils.collision.MakeSensor}.
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
-- @see solar2d_utils.collision.GetType, s3_utils.shapes.RemoveAt
function M.New (info, dot)
	local index = tile_layout.GetIndex(info.col, info.row)

	tile_layout.PutObjectAt(index, dot)

	if TryToAddBody(dot) then
		collision.SetType(dot, info.type:sub(5)) -- lop off the "dot." part
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

	if not Dots then
		Dots, Remaining = {}, 0

		Runtime:addEventListener("enterFrame", OnEnterFrame)
	end

	Remaining = Remaining + dot.m_count

	Dots[#Dots + 1] = dot
end

--
--
--

--- Deduct a remaining dot, firing off an event if it was the last one.
function M.DeductDot ()
	Remaining = Remaining - 1

	if Remaining == 0 then
		Runtime:dispatchEvent{ name = "all_dots_removed" }
	end
end

--
--
--

Runtime:addEventListener("act_on_dot", function(event)
	local dot = event.dot

	-- Remove the dot from any shapes that contain it.
	shapes.RemoveAt(dot.m_index)

	-- If this dot counts toward the "dots remaining", deduct it.
	if dot.m_count > 0 then
		_DeductDot_()
	end

	-- Do dot-specific logic.
	if dot.ActOn then
		dot:ActOn(event.actor, event.body)
	end
end)

--
--
--

local function DotLess (a, b)
	return a.m_index < b.m_index
end

local function BlockFunc (event)
	local dot = event.target
	local x, y = event.group:localToContent(dot.m_old_x, dot.m_old_y)

	dot.x, dot.y = dot.parent:contentToLocal(x, y)

	local angle = event.angle

	if angle then
		local on_rotate = dot.on_rotate_block_P

		if on_rotate then
			on_rotate(dot, angle)
		else
			dot.rotation = angle
		end
	end
end

Runtime:addEventListener("block_setup", function(event)
	-- Sort the dots for incremental traversal as we iterate the block.
	if not Dots.sorted then
		sort(Dots, DotLess)

		Dots.sorted = true
	end

	-- Accumulate any non-omitted dot inside the block region into its list.
	local block = event.block
	local slot, n = 1, #Dots

	for index in block:IterSelf() do
		while slot <= n and Dots[slot].m_index < index do
			slot = slot + 1
		end

		local dot = Dots[slot]

		if dot and dot.m_index == index and not dot.omit_from_blocks_P then
			dot.m_old_x, dot.m_old_y = dot.x, dot.y

			if dot.addEventListener then
				dot:addEventListener("with_block_update", BlockFunc)
			else
				dot.with_block_update = BlockFunc
			end

			block:DataStore_Append(dot)
		end
	end
end)

--
--
--

Runtime:addEventListener("leave_level", function()
	Dots, PreviousTime = nil

	Runtime:removeEventListener("enterFrame", OnEnterFrame)
end)

--
--
--

Runtime:addEventListener("reset", function()
	Remaining, PreviousTime = 0

	if Dots then
		for _, dot in ipairs(Dots) do
			tile_layout.PutObjectAt(dot.m_index, dot)

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
					TryToAddBody(dot)
				end
			end
		end)
	end
end)

--
--
--

_DeductDot_ = M.DeductDot

return M