--- This module deals with tile direction flags.
--
-- Terminology-wise, a "flag" in the following refers to an unsigned integer with a single
-- bit set, and a "union of flags" is the logical or of one or more distinct flags.

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
local pairs = pairs
local rawequal = rawequal

-- Modules --
local enums = require("s3_utils.enums")
local tile_layout = require("s3_utils.tile_layout")

-- Solar2D globals --
local Runtime = Runtime

-- Cached module references --
local _GetDirections_
local _GetFlags_
local _Resolve_

-- Exports --
local M = {}

--
--
--

local Current

---
-- @return Name of current flag group.
function M.GetCurrentGroup ()
	return Current
end

--
--
--

--- Iterate over the directions open on a given tile.
-- @int index
-- @treturn iterator Supplies direction.
function M.GetDirections (index)
	return tile_layout.GetDirectionsFromFlags(_GetFlags_(index))
end

--
--
--

-- The "true" value of flags, as used outside the module --
local ResolvedFlags

---
-- @int index Tile index.
-- @treturn uint Resolved flags, as of the last @{Resolve} call; 0 if no resolution has
-- been performed or _index_ is invalid.
--
-- When the level begins, no flags are considered resolved.
function M.GetFlags (index)
	return ResolvedFlags[index] or 0
end

--
--
--

local NilNonce = {}

local function MaybeNil (name)
	if name == nil then
		return NilNonce
	else
		return name
	end
end

local FlagGroups

--- DOCME
function M.GetFlags_FromGroup (name, index)
	local fgroup = FlagGroups and FlagGroups[MaybeNil(name)]

	return fgroup and fgroup.resolved[index] or 0 -- n.b. fallthrough when resolved[index] nil
end

--
--
--

local WorkingFlags

--- DOCME
function M.GetWorkingFlags (index)
	return WorkingFlags[index] or 0
end

--
--
--

---
-- @int index Tile index.
-- @string name One of **"left"**, **"right"**, **"up"**, or **"down"**.
-- @treturn boolean _index_ is valid and the working flag is set for the tile?
function M.IsWorkingFlagSet (index, name)
	return enums.IsFlagSet(WorkingFlags[index], name)
end

--
--
--

local Deltas = { left = -1, right = 1 }

local FlagsUpdatedEvent = { name = "flags_updated" }

local Reverse = { left = "right", right = "left", up = "down", down = "up" }

--- Resolve the current working flags, as set by @{SetFlags}, into the current active
-- flag set. The working flags will remain intact.
--
-- The operation begins with the working set of flags, and looks for these cases:
--
-- *  One-way, e.g. a right-flagged tile whose right neighbor is not left-flagged.
-- *  Orphaned border, e.g. a down-flagged tile on the lowest row.
--
-- The final result, after culling the troublesome flags, is the resolved flag set.
-- @bool update If true, the **"flags_updated"** event is dispatched after resolution.
function M.Resolve (update)
	local col, ncols = 0, tile_layout.GetCounts()

	Deltas.down, Deltas.up = ncols, -ncols

	for i = 1, tile_layout.GetArea() do
		col = col + 1

		if col > 1 then
			Deltas.left = -1
		else
			Deltas.left, Deltas.right = 1 / 0, 1
		end
			
		if col == ncols then
			col, Deltas.right = 0, 1 / 0
		end

		local flags = WorkingFlags[i]

		for what in tile_layout.GetDirectionsFromFlags(flags) do
			local all = WorkingFlags[i + Deltas[what]]

			if not (all and enums.IsFlagSet(all, Reverse[what])) then
				flags = flags - enums.GetFlagByName(what)
			end
		end

		ResolvedFlags[i] = flags
	end

	if update then
		Runtime:dispatchEvent(FlagsUpdatedEvent)
	end
end

--
--
--

local RotateCW, RotateCCW = { left = "up", right = "down", down = "left", up = "right" }, {}

for k, v in pairs(RotateCW) do
	RotateCCW[v] = k
end

--- Report the state of a set of flags, after a rotation of some multiple of 90 degrees.
-- @uint flags Union of flags to rotate.
-- @string how If this is **"ccw"** or **"180"**, the flags are rotated through -90 or 180
-- degrees, respectively. Otherwise, the rotation is by 90 degrees.
-- @treturn uint Union of rotated flags.
function M.Rotate (flags, how)
	local rotate, flip, rflags = how == "ccw" and RotateCCW or RotateCW, how == "180", 0

	for what in tile_layout.GetDirectionsFromFlags(flags) do
		local new = rotate[what]

		if flip then
			new = rotate[new]
		end

		rflags = rflags + enums.GetFlagByName(new)
	end

	return rflags
end

--
--
--

--- Set a tile's working flags.
--
-- @{Resolve} can later be called to establish inter-tile connections.
-- @int index Tile index; if outside the level, this is a no-op.
-- @int flags Union of flags to assign.
-- @treturn uint Previous value of tile's working flags; 0 if no value has been assigned, or
-- _index_ is outside the level.
-- @see GetFlags
function M.SetFlags (index, flags)
	local old

	if index >= 1 and index <= tile_layout.GetArea() then
		old, WorkingFlags[index] = WorkingFlags[index], flags
	end

	return old or 0
end

--
--
--

local function AuxBindGroup (fgroup)
	ResolvedFlags, WorkingFlags = fgroup.resolved, fgroup.working
end

local function AuxUseGroup (name)
	Current, name = name, MaybeNil(name)

	local fgroup = FlagGroups[name] or { resolved = {}, working = {} }

	FlagGroups[name] = fgroup

	AuxBindGroup(fgroup)
end

--- Swap out the current working / resolved flags for another group (created on first use).
--
-- This is a no-op if _name_ is already the current group.
-- @param name Name of set, or **nil** for the default.
-- @return Name of group in use before call.
function M.UseGroup (name)
	local current = Current

	if not rawequal(name, current) then
		AuxUseGroup(name)
	end

	return current
end

--
--
--

--- Visit all flag groups, namely the default one and anything instantiated by @{UseGroup}.
-- For each one, _func_ is called with the group name after making the given flags current.
--
-- The group current before this call is restored afterward.
function M.VisitGroups (func)
	local current = Current

	for name, fgroup in pairs(FlagGroups) do
		if name ~= current then
			AuxBindGroup(fgroup)
			func(name)
		end
	end

	AuxBindGroup(FlagGroups[MaybeNil(current)])
	func(current)
end

--
--
--

local function AuxWipe (index)
	ResolvedFlags[index], WorkingFlags[index] = nil
end

--- Clear all tile flags, in both the working and resolved sets, in a given region.
--
-- Neighboring tiles' flags remain unaffected. Flag resolution is not performed.
-- @int col1 Column of one corner...
-- @int row1 ...row of one corner...
-- @int col2 ...column of another corner... (Columns will be sorted, and clamped.)
-- @int row2 ...and row of another corner. (Rows too.)
function M.Wipe (col1, row1, col2, row2)
	tile_layout.VisitRegion(AuxWipe, col1, row1, col2, row2)
end

--
--
--

Runtime:addEventListener("enter_level", function()
	FlagGroups, Current = {}

	AuxUseGroup(nil)
end)

--
--
--

Runtime:addEventListener("leave_level", function()
	FlagGroups, WorkingFlags, ResolvedFlags = nil
end)

--
--
--

Runtime:addEventListener("reset_level", function()
	_Resolve_()
end)

--
--
--

Runtime:addEventListener("tiles_changed", function()
	_Resolve_(true)
end)

--
--
--

_GetDirections_ = M.GetDirections
_GetFlags_ = M.GetFlags
_Resolve_ = M.Resolve

return M