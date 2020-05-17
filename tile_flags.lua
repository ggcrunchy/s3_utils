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
local grid_funcs = require("tektite_core.array.grid")
local movement = require("s3_utils.movement")
local range = require("tektite_core.number.range")
local table_funcs = require("tektite_core.table.funcs")

-- Plugins --
local bit = require("plugin.bit")

-- Corona globals --
local Runtime = Runtime

-- Cached module references --
local _GetFlags_
local _ResolveFlags_

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

local DirFlags = { left = true, right = true, up = true, down = true }

for k in pairs(DirFlags) do
	DirFlags[k] = movement.GetDirectionFlag(k)
end

local function OrFlags (name1, name2, name3, name4)
	return DirFlags[name1] + DirFlags[name2] + (DirFlags[name3] or 0) + (DirFlags[name4] or 0)
end

local TileFlags = {
	FourWays = OrFlags("left", "right", "up", "down"),
	UpperLeft = OrFlags("right", "down"),
	UpperRight = OrFlags("left", "down"),
	LowerLeft = OrFlags("right", "up"),
	LowerRight = OrFlags("left", "up"),
	TopT = OrFlags("left", "right", "down"),
	LeftT = OrFlags("right", "up", "down"),
	RightT = OrFlags("left", "up", "down"),
	BottomT = OrFlags("left", "right", "up"),
	Horizontal = OrFlags("left", "right"),
	Vertical = OrFlags("up", "down"),
	LeftNub = DirFlags.right,
	RightNub = DirFlags.left,
	BottomNub = DirFlags.up,
	TopNub = DirFlags.down
}

local function MaybeNil (name)
	if name == nil then
		return DirFlags -- arbitrary nonce
	else
		return name
	end
end

local FlagGroups

--- DOCME
function M.GetFlags_FromGroup (name, index)
	local fgroup = FlagGroups and FlagGroups[MaybeNil(name)]

	return fgroup and fgroup.working[index] or 0 -- n.b. fallthrough when working[index] nil
end

---
-- @string name One of **"left"**, **"right"**, **"up"**, **"down"**, **"FourWays"**,
-- **"UpperLeft"**, **"UpperRight"**, **"LowerLeft"**, **"LowerRight"**, **"TopT"**,
-- **"LeftT"**, **"RightT"**, **"BottomT"**, **"Horizontal"**, **"Vertical"**, **"LeftNub"**,
-- **"RightNub"**, **"BottomNub"**, **"TopNub"**.
-- @treturn uint Union of flags corresponding to _name_, or 0 if no match is found.
function M.GetFlagsByName (name)
	return TileFlags[name] or DirFlags[name] or 0
end

-- The names of each cardinal direction, indexed by its flag --
local NamesByValueDir = table_funcs.Invert(DirFlags)

-- The names of each flag combination, indexed by its union of flags --
local NamesByValueTile = table_funcs.Invert(TileFlags)

---
-- @uint flags Union of flags.
-- @treturn ?|string|nil One of the values of _name_ in @{GetFlagsByName}, or **nil** if no
-- match was found.
function M.GetNameByFlags (flags)
	return NamesByValueTile[flags]
end

-- The "true" value of flags, as used outside the module --
local ResolvedFlags

---
-- @int index Tile index.
-- @treturn uint Resolved flags, as of the last @{ResolveFlags} call; 0 if no resolution
-- has been performed or _index_ is invalid.
--
-- When the level begins, no flags are considered resumed.
function M.GetFlags (index)
	return ResolvedFlags[index] or 0
end

--- DOCME
function M.GetFlags_FromGroup (name, index)
	local fgroup = FlagGroups and FlagGroups[MaybeNil(name)]

	return fgroup and fgroup.resolved[index] or 0 -- n.b. fallthrough when resolved[index] nil
end

local Highest = { 1, 2, 2 }

for i = 4, 7 do
	Highest[i] = 4
end

for i = 8, 15 do
	Highest[i] = 8
end

local function AuxPowers (_, n)
	local bit = Highest[n]

	return bit and n - bit, bit
end

local function Powers (n)
	return AuxPowers, nil, n
end

---
-- @int index
-- @treturn boolean Is _index_ valid, and did it resolve to neighboring more than two tiles?
-- @treturn uint Number of outbound directions, &isin; [0, 4].
-- @see ResolveFlags
function M.IsJunction (index)
	local n = 0

	for _ in Powers(ResolvedFlags[index]) do
		n = n + 1
	end

	return n > 2, n
end

---
-- @int index
-- @treturn boolean Is _index_ valid, and would its flags resolve to some combination?
-- @see GetFlagsByName, ResolveFlags
function M.IsOnPath (index)
	local flags = ResolvedFlags[index] or 0

	return flags > 0
end

---
-- @int index
-- @treturn boolean Is _index_ valid, and did it resolve to either the **"Horizontal"** or
-- the **"Vertical"** combination?
-- @see GetFlagsByName, ResolveFlags
function M.IsStraight (index)
	local flags = ResolvedFlags[index]

	return flags == TileFlags.Horizontal or flags == TileFlags.Vertical
end

local function IsFlagSet (rflags, flag)
	return bit.band(rflags or 0, flag) ~= 0
end

local WorkingFlags

---
-- @int index Tile index.
-- @string name One of **"left"**, **"right"**, **"up"**, or **"down"**.
-- @treturn boolean _index_ is valid and the working flag is set for the tile?
function M.IsWorkingFlagSet (index, name)
	return IsFlagSet(WorkingFlags[index], DirFlags[name])
end

local Reverse = { left = "right", right = "left", up = "down", down = "up" }

for k, v in pairs(Reverse) do
	Reverse[k] = DirFlags[v]
end

local Area

local Deltas = { left = -1, right = 1 }

local NCols, NRows

local FlagsUpdatedEvent = { name = "flags_updated" }

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
function M.ResolveFlags (update)
	local col = 0

	for i = 1, Area do
		col = col + 1

		if col > 1 then
			Deltas.left = -1
		else
			Deltas.left, Deltas.right = 1 / 0, 1
		end
			
		if col == NCols then
			col, Deltas.right = 0, 1 / 0
		end

		local flags = WorkingFlags[i]

		for _, power in Powers(flags) do
			local what = NamesByValueDir[power]
			local all = WorkingFlags[i + Deltas[what]]

			if not (all and IsFlagSet(all, Reverse[what])) then
				flags = flags - power
			end
		end

		ResolvedFlags[i] = flags
	end

	if update then
		Runtime:dispatchEvent(FlagsUpdatedEvent)
	end
end

local RotateCW = { left = "up", right = "down", down = "left", up = "right" }

local RotateCCW = table_funcs.Invert(RotateCW)

--- Report the state of a set of flags, after a rotation of some multiple of 90 degrees.
-- @uint flags Union of flags to rotate.
-- @string how If this is **"ccw"** or **"180"**, the flags are rotated through -90 or 180
-- degrees, respectively. Otherwise, the rotation is by 90 degrees.
-- @treturn uint Union of rotated flags.
function M.Rotate (flags, how)
	local rotate, flip, rflags = how == "ccw" and RotateCCW or RotateCW, how == "180", 0

	for _, power in Powers(flags) do
		local new = rotate[NamesByValueDir[power]]

		new = flip and rotate[new] or new
		rflags = rflags + DirFlags[new]
	end

	return rflags
end


--- Set a tile's working flags.
--
-- @{ResolveFlags} can later be called to establish inter-tile connections.
-- @int index Tile index; if outside the level, this is a no-op.
-- @int flags Union of flags to assign.
-- @treturn uint Previous value of tile's working flags; 0 if no value has been assigned, or
-- _index_ is outside the level.
-- @see GetFlags
function M.SetFlags (index, flags)
	local old

	if index >= 1 and index <= Area then
		old, WorkingFlags[index] = WorkingFlags[index], flags
	end

	return old or 0
end

local function AuxBindGroup (fgroup)
	ResolvedFlags, WorkingFlags = fgroup.resolved, fgroup.working
end

local function AuxUseFlags (name)
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
function M.UseFlags (name)
	local current = Current

	if not rawequal(name, current) then
		AuxUseFlags(name)
	end

	return current
end

--- Visit all flag groups, namely the default one and anything instantiated by @{UseFlags}.
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

--- Clear all tile flags, in both the working and resolved sets, in a given region.
--
-- Neighboring tiles' flags remain unaffected. Flag resolution is not performed.
-- @int col1 Column of one corner...
-- @int row1 ...row of one corner...
-- @int col2 ...column of another corner... (Columns will be sorted, and clamped.)
-- @int row2 ...and row of another corner. (Rows too.)
function M.WipeFlags (col1, row1, col2, row2)
	col1, col2 = range.MinMax_N(col1, col2, NCols)
	row1, row2 = range.MinMax_N(row1, row2, NRows)

	local index = grid_funcs.CellToIndex(col1, row1, NCols)

	for _ = row1, row2 do
		for i = 0, col2 - col1 do
			ResolvedFlags[index + i], WorkingFlags[index + i] = nil
		end

		index = index + NCols
	end
end

for k, v in pairs{
	enter_level = function(level)
		Deltas.up = -level.ncols
		Deltas.down = level.ncols

		NCols = level.ncols
		NRows = level.nrows
		Area, FlagGroups, Current = NCols * NRows, {}

		AuxUseFlags(nil)
	end,

	leave_level = function()
		FlagGroups, WorkingFlags, ResolvedFlags = nil
	end,

	reset_level = function()
		_ResolveFlags_()
	end,

	tiles_changed = function()
		_ResolveFlags_(true)
	end
} do
	Runtime:addEventListener(k, v)
end

_GetFlags_ = M.GetFlags
_ResolveFlags_ = M.ResolveFlags

return M