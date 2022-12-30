--- Functionality common to most or all "dots", i.e. objects of interest that occupy tiles.
-- The nomenclature comes from _Amazing Penguin_, the chief inspiration behind this project,
-- where such things looked like dots.
--
-- Each dot type has an **ActOn** method, defining how it responds to player action.
--
-- A dot may provide certain other methods: **Reset** and **Update** define the behavior when
-- the level resets and per-frame, respectively; **GetProperty**, given a name, returns the
-- corresponding property if available, otherwise **nil** (or nothing).

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

-- Modules --
local collision = require("solar2d_utils.collision")
local shapes = require("s3_utils.shapes")
local tile_layout = require("s3_utils.tile_layout")
local timers = require("solar2d_utils.timers")

-- Solar2D globals --
local Runtime = Runtime

-- Cached module references --
local _DeductDot_
local _GetIndex_

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

-- How many dots are left to pick up? --
local Remaining

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

--- DOCME
function M.GetIndex (dot)
  return dot.m_index
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

local function AuxEnterFrame (dt)
	for _, dot in ipairs(Dots) do
		if dot.Update then
			dot:Update(dt)
		end
	end
end

local OnEnterFrame

--- Adds a new _name_-type sensor dot to the level.
--
-- For each name, there must be a corresponding module, the value of which will be a
-- constructor function, called as
--    cons(group, info)
-- and which returns the new dot, which must be a display object without physics.
--
-- Various readable properties (cf. @{tektite_core.table.meta.Augment}) are important:
--
-- If the **is_counted\_P** property is true, the dot will count toward the remaining dots
-- total. If this count falls to 0, the **all\_dots\_removed** event is dispatched.
--
-- If the **add\_to\_shapes\_P** property is true, the dot will be added to / may be removed from
-- shapes, and assumes that its **is_counted\_P** property is true.
--
-- The **body\_P** and **body_type\_P** properties can be supplied to @{solar2d_utils.collision.MakeSensor}.
-- If **body\_P** is **false**, these properties are not assigned.
-- @pgroup group Display group that will hold the dot.
-- @ptable info Information about the new dot. Required fields:
--
-- * **col**: Column on which dot sits.
-- * **row**: Row on which dot sits.
-- * **type**: Name of dot type, q.v. _name_, above. This is also assigned as the collision type,
-- although the **type\_name\_P** may be used to override this.
--
-- Instance-specific data may also be passed in other fields.
-- @ptable Load parameters.
-- @see solar2d_utils.collision.GetType, s3_utils.shapes.RemoveAt
function M.New (info, dot)
	local index = tile_layout.GetIndex(info.col, info.row)

	tile_layout.PutObjectAt(index, dot)

	if TryToAddBody(dot) then
		collision.SetType(dot, dot.type_name_P or info.type:sub(5)) -- lop off the "dot." part
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

	if dot.Update and not OnEnterFrame then
    OnEnterFrame = timers.WithDelta(AuxEnterFrame)

		Runtime:addEventListener("enterFrame", OnEnterFrame)
	end

	Remaining = (Remaining or 0) + dot.m_count

  Dots = Dots or {}
	Dots[#Dots + 1] = dot
end

--
--
--

local TouchEvent = { name = "touching_dot" }

--- DOCME
function M.Touch (dot, phase)
  local is_touched = phase == "began"

  TouchEvent.dot, TouchEvent.is_touching = dot, is_touched

  Runtime:dispatchEvent(TouchEvent)

  TouchEvent.dot = nil

  return is_touched
end

--
--
--

Runtime:addEventListener("act_on_dot", function(event)
	local dot = event.dot

	-- Remove the dot from any shapes that contain it.
	shapes.RemoveAt(_GetIndex_(dot))

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

Runtime:addEventListener("leave_level", function()
  if OnEnterFrame then
    Runtime:removeEventListener("enterFrame", OnEnterFrame)
  end

	Dots, OnEnterFrame, Remaining = nil
end)

--
--
--

Runtime:addEventListener("reset", function()
	Remaining = 0

	for i = 1, #(Dots or "") do
    local dot = Dots[i]

    tile_layout.PutObjectAt(_GetIndex_(dot), dot)

    dot.isVisible = true
    dot.rotation = 0

    if dot.Reset then
      dot:Reset()
    end

    Remaining = Remaining + dot.m_count
	end
end)

--
--
--

_DeductDot_ = M.DeductDot
_GetIndex_ = M.GetIndex

return M