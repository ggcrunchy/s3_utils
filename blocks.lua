--- Common functionality for various "area effect" game events.
--
-- Each such event type must return a factory function, cf. the result of @{GetEvent}.
-- Such functions must gracefully handle an _info_ argument of **"editor_event"**, by
-- returning either an editor event function or **nil**, cf. @{EditorEvent}.
--
-- **N.B.**: In each of the functions below that take columns and rows as input, the
-- operation will transparently sort the columns and rows, and clamp them against the
-- level boundaries. A rect completely outside the level is null and the operation
-- will be a no-op.

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
local rawequal = rawequal
local remove = table.remove

-- Modules --
local call = require("corona_utils.call")
local meta = require("tektite_core.table.meta")
local range = require("tektite_core.number.range")
local rect_iters = require("iterator_ops.grid.rect")
local tile_flags = require("s3_utils.tile_flags")
local tile_maps = require("s3_utils.tile_maps")

-- Corona globals --
local display = display
local Runtime = Runtime
local system = system

-- Imports --
local GetFlags = tile_flags.GetFlags
local GetFlags_FromGroup = tile_flags.GetFlags_FromGroup
local GetImage = tile_maps.GetImage
local SetFlags = tile_flags.SetFlags

-- Exports --
local M = {}

--
--
--

local NCols, NRows

local function AuxBlock (col1, row1, col2, row2)
	return rect_iters.GridIter(col1, row1, col2, row2, NCols)
end

local function GetExtents (col1, row1, col2, row2)
	col1, col2 = range.MinMax_N(col1, col2, NCols)
	row1, row2 = range.MinMax_N(row1, row2, NRows)

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

local LoadedBlocks

-- Tile -> ID map indicating which block, if any, occupies a given tile --
local BlockIDs

-- Creation-time values of flags within the block region, for restoration --
local OldFlags

-- Wipes block state at a given tile index
local function Wipe (index)
	BlockIDs[index] = nil

	SetFlags(index, 0)
end

local Block = {}

--- Add a new group to the block's main group.
-- @treturn DisplayGroup Added group.
function Block:AddGroup ()
	local new = display.newGroup()

	self.m_bgroup:insert(new)

	return new
end

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

--- Variant of @{Block:FillRect} that fills the current rect.
-- @see Block:SetRect
function Block:FillSelf ()
	local id = self.m_id

	for index in BlockSelf(self) do
		BlockIDs[index] = id
	end
end

---
-- @treturn int Minimum column...
-- @treturn int ...and maximum.
function Block:GetColumns ()
	return self.m_cmin, self.m_cmax
end

---
-- @treturn DisplayGroup The block's main group.
function Block:GetGroup ()
	return self.m_bgroup
end

---
-- @treturn DisplayGroup The block's image group.
function Block:GetImageGroup ()
	return self.m_igroup
end

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
	end

	return self.m_cmin_save, self.m_rmin_save, self.m_cmax_save, self.m_rmax_save
end

---
-- @int index Tile index.
-- @treturn uint Tile flags at block creation time.
-- @see s3_utils.tile_flags.GetFlags
function Block:GetOldFlags (index)
	return OldFlags[index] or 0
end

---
-- @treturn int Minimum row...
-- @treturn int ...and maximum.
function Block:GetRows ()
	return self.m_rmin, self.m_rmax
end

--- Iterate over a given region.
-- @int col1 A column...
-- @int row1 ... and row.
-- @int col2 Another column...
-- @int row2 ...and row.
-- @treturn iterator Supplies tile index, column, row.
function Block:Iter (col1, row1, col2, row2)
	return BlockIter(col1, row1, col2, row2)
end

--- Variant of @{Block:Iter} that iterates over the current rect.
-- @treturn iterator Supplies tile index, column, row.
-- @see Block:SetRect
function Block:IterSelf ()
	return BlockSelf(self)
end

local function ZeroSpan (block, col1, row1, col2, row2)
	for index in block:Iter(col1, row1, col2, row2) do
		SetFlags(index, 0)
	end
end

--- Populate the flags in a group with the block's old flags, zeroing out a one-cell
-- rect around them for safety.
-- @param[opt=self] name Name of flag group, cf. @{tile_flags.UseFlags}.
-- @param[opt] from Name of source flag group. If absent, uses the default.
function Block:MakeIsland (name, from)
	local cur = tile_flags.UseFlags(name or self)
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
		SetFlags(index, GetFlags_FromGroup(from, index))
	end

	tile_flags.ResolveFlags()
	tile_flags.UseFlags(cur)
end

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

--- Variant of @{Block:WipeRect} that wipes the current rect.
-- @see Block:SetRect
function Block:WipeSelf ()
	for index in BlockSelf(self) do
		Wipe(index)
	end
end

--- Add a block to the level and register an event for it.
-- @ptable info Block info, with at least the following properties:
--
-- * **name**: **string** The event is registered under this name, which should be unique
-- among blocks.
-- * **type**: **string** One of the choices reported by @{GetTypes}.
-- * **col1**, **row1**, **col2**, **row2**: **int** Columns and rows defining the block.
-- These will be sorted and clamped, as with block operations.
--
-- @todo Detect null blocks? Mention construction, Block:Reset
-- @todo this is now out of date!
-- @ptable params
function M.New (info, params)
	if not LoadedBlocks then
		LoadedBlocks, BlockIDs, OldFlags = {}, {}, {}
		NCols, NRows = tile_maps.GetCounts()
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
	block.m_id, block.m_igroup = #LoadedBlocks + 1, display.newGroup()

	for i, index in ipairs(block) do
		block[i] = GetImage(index) or false

		if block[i] then
			block.m_igroup:insert(block[i])
		end

		BlockIDs[index] = block.m_id
		OldFlags[index] = GetFlags(index)
	end

	local tiles_layer = params.tiles_layer

	block.m_bgroup:insert(block.m_igroup)
	tiles_layer:insert(block.m_bgroup)

	LoadedBlocks[block.m_id] = block

	meta.Augment(block, Block)

	return block
end

--- DOCME
function Block:AttachEvent (event, info, params)
	params:GetPubSubList():Publish(event, info.uid, "fire")

	call.Redirect(event, self)
end

local BlockKeys = { "type", "col1", "row1", "col2", "row2" }

--- Handler for block-related events sent by the editor.
--
-- If an editor event function is available for _type_, if will be called afterward as
-- `func(what, arg1, arg2, arg3)`.
-- @string type Block type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local cons = nil--BlockList[type].editor

	if cons then
		local event = cons--("editor_event")

		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Block to build
		if what == "build" then
			for _, key in ipairs(BlockKeys) do
				arg3[key] = arg2[key]
			end

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
--			arg1.starts_on = true

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:StockElements(event and event("get_thumb_filename"))
			arg1:AddSeparator()
--			arg1:AddCheckbox{ text = "On By Default?", value_name = "starts_on" }
--			arg1:AddSeparator()

		-- Get Link Grouping --
		elseif what == "get_link_grouping" then
			return {
				{ text = "ACTIONS", font = "bold", color = "actions" }, "fire"
			}

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.fire = "Do area effect"

		-- Get Tag --
		elseif what == "get_tag" then
			return "block"

		-- New Tag --
		elseif what == "new_tag" then
			return "sources_and_targets", nil, "fire"

		-- Prep Link --
		elseif what == "prep_link" then
			-- ??

		-- Verify --
		elseif what == "verify" then
			-- Has one or more source...
		end

		local result, r2, r3

		if event then
			result, r2, r3 = event(what, arg1, arg2, arg3)
		end

		return result, r2, r3
	end
end

---
-- @treturn {string,...} Unordered list of block type names.
--[=[
function M.GetTypes ()
	local types = {}

	for k in pairs(BlockList) do
		types[#types + 1] = k
	end

	return types
end
--]=]

-----------------------------------------------------------
-----------------------------------------------------------
-----------------------------------------------------------

local function AuxAddToList (list, top, item, func, arg1, arg2)
	list[top + 1], list[top + 2], list[top + 3], list[top + 4] = item, func, arg1 or false, arg2 or false

	return top + 4
end

--- Add an item to the block's list.
-- @param item Item to add.
-- @callable func Commands to use on _item_, according to the type of block.
-- @param[opt] arg1 Argument #1 to _func_ (default **false**)...
-- @param[opt] arg2 ...and #2 (ditto).
function Block:AddToList (item, func, arg1, arg2)
	local list = self.m_list or { top = 0 }

	list.top = AuxAddToList(list, list.top, item, func, arg1, arg2)

	self.m_list = list
end

local Dynamic

--- Add an item to the block's list.
-- @param item Item to add.
-- @callable func Commands to use on _item_, according to the type of block.
-- @treturn function X
function Block:AddToList_Dynamic (item, func, arg1, arg2)
	local list = self.m_dynamic_list or {}

	Dynamic = Dynamic or {}

	local dfunc = remove(Dynamic)

	if dfunc then
		dfunc(Dynamic, item, func, arg1, arg2) -- arbitrary nonce
	else
		function dfunc (what, a, b, c, d)
			if rawequal(what, Dynamic) then -- see note above
				item, func, arg1, arg2 = a, b, c, d
			else
				assert(list[dfunc], "Invalid dynamic function")

				if what == "get" then
					return item, func, arg1, arg2
				elseif what == "update_args" then
					arg1, arg2 = a, b
				elseif what == "remove" then
					Dynamic[#Dynamic + 1], list[dfunc], item, func, arg1, arg2 = dfunc
				end
			end
		end
	end

	self.m_dynamic_list, list[dfunc] = list, true

	return dfunc
end

---
-- @treturn boolean List has items?
function Block:HasItems ()
	return self.m_list ~= nil
end

local function AuxIterList (list, index)
	index = index + 4

	local item = list and list[index]

	if item and index <= list.n then
		return index, item, list[index + 1], list[index + 2], list[index + 3]
	end
end

local function AddDynamicItems (block, dlist, list)
	local n = list and list.top or 0 -- N.B. dynamic items added after top

	for dfunc in pairs(dlist) do
		list = list or { top = 0 }
		n = AuxAddToList(list, n, dfunc("get"))
	end

	if list then
		block.m_list, list.n = list, n
	end

	return list
end

--- Iterate over each item in the list.
-- @treturn iterator Supplies tile index, item, commands function, argument #1, argument #2.
function Block:IterList ()
	local list, dlist = self.m_list, self.m_dynamic_list

	if dlist then
		list = AddDynamicItems(self, dlist, list)
	elseif list then
		list.n = list.top
	end

	return AuxIterList, list, -3
end

-----------------------------------------------------------
-----------------------------------------------------------
-----------------------------------------------------------

for k, v in pairs{
	leave_level = function()
		LoadedBlocks, BlockIDs, Dynamic, OldFlags = nil
	end,

	pre_reset = function()
		if LoadedBlocks then
			BlockIDs = {}

			-- Restore any flags that may have been altered by a block.
			for i, flags in pairs(OldFlags) do
	--[[
				local image = GetImage(i) -- Relevant?...

				if image then
					PutObjectAt(i, image)
				end
	]]
	-- Physics...
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
		end
	end,

	things_loaded = function()
		local event = { name = "block_setup" }

		for i = 1, #(LoadedBlocks or "") do
			event.block = LoadedBlocks[i]

			Runtime:dispatchEvent(event)
		end
	end
} do
	Runtime:addEventListener(k, v)
end

return M