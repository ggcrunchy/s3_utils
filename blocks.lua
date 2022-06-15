--- Common functionality for various "area effect" game events.
--
-- Each such event type must return a factory function, cf. the result of @{GetEvent}.
-- Such functions must gracefully handle an _info_ argument of **"editor_event"**, by
-- returning either an editor event function or **nil**, cf. @{EditorEvent}.
--
-- **N.B.**: In each of the functions below that take columns and rows as input, the
-- operation will transparently sort the columns and rows, clamping the results
-- against the level boundaries. Rects completely outside are null and the
-- operations will be no-ops.

-- TODO: is that last statement actually true, at the moment? (or stuff above that...)

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
local assert = assert
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs
local remove = table.remove

-- Modules --
local component = require("tektite_core.component")
local coordinate = require("tektite_core.number.coordinate")
local data_store = require("s3_objects.mixin.data_store")
local events = require("solar2d_utils.events")
local meta = require("tektite_core.table.meta")
local tile_flags = require("s3_utils.tile_flags")
local tile_layout = require("s3_utils.tile_layout")
local tile_maps = require("s3_utils.tile_maps")

-- Solar2D globals --
local display = display
local Runtime = Runtime
local system = system

-- Imports --
local GetFlags_FromSet = tile_flags.GetFlags_FromSet
local GetImage = tile_maps.GetImage
local SetFlags = tile_flags.SetFlags

-- Extension imports --
local indexOf = table.indexOf

-- Cached module references --
local _FindActiveBlock_

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.EditorEvent ()
	return {
		inputs = {
			string = { type = "" },
			uint = { col1 = 1, row1 = 1, col2 = 1, row2 = 1 }
		}
	}
	-- ^^ TODO: this is to be inherited somehow...
end

--
--
--

local NCols, NRows

local IterStack = {}

local function GridIter (state)
  local col, row = state.col, state.row

  if col > state.col2 then
    row = row + 1

    if row == state.last_row then
      IterStack[#IterStack + 1] = state

      return
    else
      col, state.row = state.col1, row
    end
  end

  state.col = col + 1

  return row * NCols + col, col, row + 1
end

local function AuxBlock (col1, row1, col2, row2)
  local state = remove(IterStack) or {}

  state.col, state.row = col1, row1 - 1
  state.col1, state.col2 = col1, col2
  state.last_row = row2

	return GridIter, state
end

local function MinMax_N (a, b, n)
	if b < a then
		a, b = b, a
	end

	return max(1, a), min(b, n)
end

local function GetExtents (col1, row1, col2, row2)
	col1, col2 = MinMax_N(col1, col2, NCols)
	row1, row2 = MinMax_N(row1, row2, NRows)

	return col1, row1, col2, row2
end

local function BlockIter (col1, row1, col2, row2)
	return AuxBlock(GetExtents(col1, row1, col2, row2))
end

local function BlockSelf (block)
	local col1, col2 = block:GetColumns()
	local row1, row2 = block:GetRows()

	return AuxBlock(col1, row1, col2, row2)
end

-- Tile -> ID map indicating which block, if any, occupies a given tile --
local BlockIDs

-- Wipes block state at a given tile index
local function Wipe (index)
	BlockIDs[index] = nil

	SetFlags(index, 0)
end

--
--
--

local Block = {}

--
--
--

--- DOCME
function Block:AttachEvent (event, info, params)
	params:GetPubSubList():Publish(event, info.uid, "fire")

	events.Redirect(event, self)
end

--
--
--

--- Check whether a block can occupy a region without overlapping a different block.
-- The block will ignore itself, since this test will often be used to determine if a
-- block could be changed.
--
-- **N.B.** that this is **not** called automatically by other block methods.
-- @int col1 A column...
-- @int row1 ... and row.
-- @int col2 Another column...
-- @int row2 ...and row.
-- @treturn boolean The block can occupy the region, i.e. each tile is either unoccupied
-- or already occupied by this block?
-- @treturn uint If the first return value is **false**, the number of conflicting tiles.
-- Otherwise, 0.
function Block:CanOccupy (col1, row1, col2, row2)
	local count, id = 0, self.m_id

	for index in BlockIter(col1, row1, col2, row2) do
		local bid = BlockIDs[index]

		if bid and bid ~= id then
			count = count + 1
		end
	end

	return count == 0, count
end

--
--
--

--- DOCME
function Block:Contains (col, row)
  local cmin, cmax = self:GetColumns()
  local rmin, rmax = self:GetRows()

  return col >= cmin and col <= cmax and row >= rmin and row <= rmax
end

--
--
--

--- DOCME
function Block:Contains_Index (index)
  return self:Contains(tile_layout.GetCell(index))
end

--
--
--

--- DOCME
function Block:Contains_XY (x, y)
  return self:Contains(tile_layout.GetCell_XY(x, y))
end

--
--
--

--- Fill a region with occupancy information matching this block.
-- @int col1 A column...
-- @int row1 ... and row.
-- @int col2 Another column...
-- @int row2 ...and row.
function Block:FillRect (col1, row1, col2, row2)
	local id = self.m_id

	for index in BlockIter(col1, row1, col2, row2) do
		BlockIDs[index] = id
	end
end

--
--
--

--- Variant of @{Block:FillRect} that fills the current rect.
-- @see Block:SetRect
function Block:FillSelf ()
	local id = self.m_id

	for index in BlockSelf(self) do
		BlockIDs[index] = id
	end
end

--
--
--

---
-- @treturn int Minimum column...
-- @treturn int ...and maximum.
function Block:GetColumns ()
	return self.m_cmin, self.m_cmax
end

--
--
--

---
-- @treturn DisplayGroup The block's main group.
function Block:GetGroup ()
	return self.m_bgroup
end

--
--
--

--- Get the rect that was current at block initialization.
-- @bool flagged If true, cull any unflagged outer rows and columns.
-- @treturn int Minimum column...
-- @treturn int ...and row.
-- @treturn int Maximum column...
-- @treturn int ...and row.
function Block:GetInitialRect (flagged)
	if flagged then
		local cmin, rmin = self.m_cmax_save, self.m_rmax_save
		local cmax, rmax = self.m_cmin_save, self.m_rmin_save

		for index, col, row in self:Iter(self.m_cmin_save, self.m_rmin_save, self.m_cmax_save, self.m_rmax_save) do
			if self:GetOldFlags(index) ~= 0 then
				cmin, cmax = min(cmin, col), max(cmax, col)
				rmin, rmax = min(rmin, row), max(rmax, row)
			end
		end

		return cmin, rmin, cmax, rmax
	else
		return self.m_cmin_save, self.m_rmin_save, self.m_cmax_save, self.m_rmax_save
	end
end

--
--
--

-- Creation-time values of flags within the block region, for restoration --
local OldFlags

---
-- @int index Tile index.
-- @treturn uint Tile flags at block creation time.
-- @see s3_utils.tile_flags.GetFlags
function Block:GetOldFlags (index)
	return OldFlags[index] or 0
end

--
--
--

---
-- @treturn int Minimum row...
-- @treturn int ...and maximum.
function Block:GetRows ()
	return self.m_rmin, self.m_rmax
end

--
--
--

--- Iterate over a given region.
-- @int col1 A column...
-- @int row1 ... and row.
-- @int col2 Another column...
-- @int row2 ...and row.
-- @treturn iterator Supplies tile index, column, row.
function Block:Iter (col1, row1, col2, row2)
	return BlockIter(col1, row1, col2, row2)
end

--
--
--

--- Variant of @{Block:Iter} that iterates over the current rect.
-- @treturn iterator Supplies tile index, column, row.
-- @see Block:SetRect
function Block:IterSelf ()
	return BlockSelf(self)
end

--
--
--

local function ZeroSpan (block, col1, row1, col2, row2)
	for index in block:Iter(col1, row1, col2, row2) do
		SetFlags(index, 0)
	end
end

--- Populate the flags in a set with the block's old flags, zeroing out a one-cell
-- rect around them for safety.
-- @param[opt=self] name Name of flag set, cf. @{tile_flags.UseSet}.
-- @param[opt] from Name of source flag set. If absent, uses the default.
function Block:MakeIsland (name, from)
	local cur = tile_flags.UseSet(name or self)
	local cmin, cmax = self:GetColumns()
	local rmin, rmax = self:GetRows()

	if cmin > 1 then
		ZeroSpan(self, cmin - 1, rmin, cmin - 1, rmax)
	end

	if rmin > 1 then
		ZeroSpan(self, cmin - 1, rmin - 1, cmax + 1, rmin - 1) -- also do corners
	end

	if cmax < NCols then
		ZeroSpan(self, cmax + 1, rmin, cmax + 1, rmax)
	end

	if rmax < NRows then
		ZeroSpan(self, cmin - 1, rmax + 1, cmax + 1, rmax + 1) -- also do corners
	end

	for index in self:IterSelf() do
		SetFlags(index, GetFlags_FromSet(from, index))
	end

	tile_flags.Resolve()
	tile_flags.UseSet(cur)
end

--
--
--

--- Set the block's current rect, as used by the ***Self** methods.
--
-- Until this call, the current rect will be equivalent to @{Block:GetInitialRect}'s
-- result (with _flagged_ false).
--
-- If the rect is null, those methods will be no-ops.
-- @int col1 A column...
-- @int row1 ...and row.
-- @int col2 Another column...
-- @int row2 ...and row.
function Block:SetRect (col1, row1, col2, row2)
	col1, row1, col2, row2 = GetExtents(col1, row1, col2, row2)

	self.m_cmin, self.m_cmax = col1, col2
	self.m_rmin, self.m_rmax = row1, row2
end

--
--
--

local Event = {}

--- DOCME
function Block:TryToBeginLate (object)
		Event.name, Event.result, Event.target = "is_done", true, self

		self:dispatchEvent(Event)

    Event.target = nil

    local active = not Event.result

		if active then
			Event.name, Event.block, Event.force, Event.phase = "block", self, true, "began"

			object:dispatchEvent(Event)

			Event.block = nil
		end

    return active
end

--
--
--

--- Wipe block state (flags, occupancy) in a given region.
-- @int col1 A column...
-- @int row1 ... and row.
-- @int col2 Another column...
-- @int row2 ...and row.
function Block:WipeRect (col1, row1, col2, row2)
	for index in BlockIter(col1, row1, col2, row2) do
		Wipe(index)
	end
end

--
--
--

--- Variant of @{Block:WipeRect} that wipes the current rect.
-- @see Block:SetRect
function Block:WipeSelf ()
	for index in BlockSelf(self) do
		Wipe(index)
	end
end

--
--
--

component.AddToObject(Block, data_store)

--
--
--

local ActiveBlocks, LoadedBlocks

--- DOCME
function M.FindActiveBlock (x, y)
  for i = 1, #(ActiveBlocks or "") do
    local id = ActiveBlocks[i]
    local block = LoadedBlocks[id]
    local lcs = block:GetLocalCoordinateSystem()

    x, y = coordinate.GlobalToLocal(lcs, x, y, "use_ref")

    local tile = tile_layout.GetIndex_XY(x, y)

    if block:Contains_Index(tile) then
      return block, tile, x, y
    end
  end

  return nil
end

--- DOCME
function M.FindTileAtPos (x, y)
  local block, tile, lx, ly = _FindActiveBlock_(x, y)
  local flags = block and tile_flags.GetFlags_FromSet(block, tile)

  if block and flags ~= 0 then -- spot exists and has a tile?
    return tile, flags, block, lx, ly
  end

  tile = tile_layout.GetIndex_XY(x, y) -- unable to find active block: try normal tile

  if tile then
    return tile, tile_flags.GetFlags(tile)
  else
    return nil
  end
end

--
--
--

--- Add a block to the level and register an event for it.
-- @ptable info Block info, with at least the following properties:
--
-- * **type**: **string** One of the choices reported by @{GetTypes}.
-- * **col1**, **row1**, **col2**, **row2**: **int** Columns and rows defining the block.
-- These will be sorted and clamped, as with block operations.
--
-- @todo Detect null blocks? Mention construction, Block:Reset
-- @todo this is now out of date!
-- @ptable params
-- @pgroup[opt] into
function M.New (info, params, into)
	if not LoadedBlocks then
		LoadedBlocks, BlockIDs, OldFlags = {}, {}, {}
		NCols, NRows = tile_layout.GetCounts()
	end

	local col1, row1, col2, row2 = GetExtents(info.col1, info.row1, info.col2, info.row2)

	-- Validate the block region, saving indices as we go to avoid repeating some work.
	local block = system.newEventDispatcher()

	for index in AuxBlock(col1, row1, col2, row2) do
		assert(not OldFlags[index], "Tile used by another block")

		block[#block + 1] = index
	end

	-- Now that the true column and row values are known (from running the iterator),
	-- initialize the current values.
	block.m_cmin, block.m_rmin = col1, row1
	block.m_cmax, block.m_rmax = col2, row2
	block.m_bgroup = display.newGroup()

	-- Save the initial rect, given the current values --
	block.m_cmin_save, block.m_rmin_save = block.m_cmin, block.m_rmin
	block.m_cmax_save, block.m_rmax_save = block.m_cmax, block.m_rmax

	-- Lift any tile images into the block's own group. Mark the block region as occupied
	-- and cache the current flags on each tile, for restoration.
	block.m_id, into = #LoadedBlocks + 1, into or block.m_bgroup

	for i, index in ipairs(block) do
		block[i] = GetImage(index) or false

		if block[i] then
			into:insert(block[i])
		end

		BlockIDs[index] = block.m_id
		OldFlags[index] = tile_flags.GetWorkingFlags(index)
	end

	params:GetLayer("tiles"):insert(block.m_bgroup)

	LoadedBlocks[block.m_id] = block

	meta.Augment(block, Block)

	return block
end

--
--
--

Runtime:addEventListener("block", function(event)
  local block = event.block

  if block.GetLocalCoordinateSystem then
    if event.phase == "began" then
      ActiveBlocks = ActiveBlocks or {}
      ActiveBlocks[#ActiveBlocks + 1] = block.m_id
    else
      local index = ActiveBlocks and indexOf(ActiveBlocks, block.m_id)

      if index then
        remove(ActiveBlocks, index)
      end
    end
  end
end)

--
--
--

local ShapeList

Runtime:addEventListener("filled_shape", function(event)
  local block = ShapeList and ShapeList[event.shape]

  if block then
    block:ConsumeFillList(event.shape:GetFillList())

    ShapeList[event.shape] = nil
  end
end)

--
--
--

Runtime:addEventListener("leave_level", function()
	ActiveBlocks, LoadedBlocks, BlockIDs, OldFlags = nil
end)

--
--
--

local ShapeInfo = {}

local function AuxVisit (tile, info)
  local ncols = info.dr

  for index = info.ul, info.lr, info.column_count do
    if tile >= index and tile <= index + ncols then
      return
    end
  end

  return "quit"
end

Runtime:addEventListener("new_shape", function(event)
  local shape = event.shape

  ShapeInfo.column_count = tile_layout.GetCounts()

  for i = 1, #(LoadedBlocks or "") do
    local block = LoadedBlocks[i]
    local c1, r1, c2, r2 = block:GetInitialRect()

    ShapeInfo.dr = c2 - c1
    ShapeInfo.ul = tile_layout.GetIndex(c1, r1)
    ShapeInfo.lr = tile_layout.GetIndex(c2, r2)

    if block.ConsumeFillList and shape:Visit(AuxVisit, ShapeInfo) then
      shape:SetFillList{}

      ShapeList = ShapeList or {}
      ShapeList[shape] = block

      break
    end
  end
end)

--
--
--

Runtime:addEventListener("pre_reset", function()
	if LoadedBlocks then
		BlockIDs, ActiveBlocks = {}

		-- Restore any flags that might have been altered by a block.
		for i, flags in pairs(OldFlags) do
			SetFlags(i, flags)
		end

		-- Reset any block state and refill initial block regions with IDs.
		for _, block in ipairs(LoadedBlocks) do
			if block.Reset then
				block:Reset()
			end

			block:SetRect(block:GetInitialRect()) -- TODO: Make responsibilty of event?
			block:FillSelf()
		end

    -- Flush any shape-to-block mappings.
    ShapeList = nil
	end
end)

--
--
--

Runtime:addEventListener("things_loaded", function()
	local event = { name = "block_setup" }

	for i = 1, #(LoadedBlocks or "") do
		event.block = LoadedBlocks[i]

		Runtime:dispatchEvent(event)
	end
end)

--
--
--

_FindActiveBlock_ = M.FindActiveBlock

return M