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
local random = math.random
local rawequal = rawequal
local remove = table.remove
local yield = coroutine.yield

-- Modules --
local require_ex = require("tektite_core.require_ex")
local bind = require("corona_utils.bind")
local fx = require("s3_utils.fx")
local meta = require("tektite_core.table.meta")
local range = require("tektite_core.number.range")
local tile_flags = require("s3_utils.tile_flags")
local tile_maps = require("s3_utils.tile_maps")
local wrapper = require("coroutine_ops.wrapper")

-- Corona globals --
local display = display
local Runtime = Runtime

-- Imports --
local GetFlags = tile_flags.GetFlags
local GetImage = tile_maps.GetImage
local SetFlags = tile_flags.SetFlags

-- Module --
local M = {}

-- Column and row extrema of currently iterated block --
local CMin, CMax, RMin, RMax

-- Block iterator body
local BlockIter = wrapper.Wrap(function()
	local left = tile_maps.GetTileIndex(CMin, RMin)
	local col, ncols = CMin, tile_maps.GetCounts()

	for row = RMin, RMax do
		for i = 0, CMax - CMin do
			yield(left + i, col + i, row)
		end

		left = left + ncols
	end
end)

-- Binds column and row extents, performing any clamping and sorting
local function BindExtents (col1, row1, col2, row2)
	local ncols, nrows = tile_maps.GetCounts()

	CMin, CMax = range.MinMax_N(col1, col2, ncols)
	RMin, RMax = range.MinMax_N(row1, row2, nrows)
end

-- Iterates over a block defined by input
local function Block (col1, row1, col2, row2)
	BindExtents(col1, row1, col2, row2)

	return BlockIter
end

-- Iterates over a block defined by its members
local function BlockSelf (block)
	CMin, CMax = block:GetColumns()
	RMin, RMax = block:GetRows()

	return BlockIter	
end

-- List of loaded event blocks --
local Blocks

-- Tile -> ID map indicating which event block, if any, occupies a given tile --
local BlockIDs

-- Creation-time values of flags within the block region, for restoration --
local OldFlags

-- Layer into which dust is added --
local MarkersLayer

-- Layers into which block groups are added --
local TilesLayer

-- Wipes event block state at a given tile index
local function Wipe (index)
	BlockIDs[index] = nil

	SetFlags(index, 0)
end

-- Event block methods --
local EventBlock = {}

--- Adds a new group to the block's main group.
-- @treturn DisplayGroup Added group.
function EventBlock:AddGroup ()
	local new = display.newGroup()

	self.m_bgroup:insert(new)

	return new
end

--
local function AuxAddToList (list, top, item, func, arg1, arg2)
	list[top + 1], list[top + 2], list[top + 3], list[top + 4] = item, func, arg1 or false, arg2 or false

	return top + 4
end

--- Adds an item to the block's list.
-- @param item Item to add.
-- @callable func Commands to use on _item_, according to the type of event block.
-- @param[opt] arg1 Argument #1 to _func_ (default **false**)...
-- @param[opt] arg2 ...and #2 (ditto).
function EventBlock:AddToList (item, func, arg1, arg2)
	local list = self.m_list or { top = 0 }

	list.top = AuxAddToList(list, list.top, item, func, arg1, arg2)

	self.m_list, self.m_new = list
end

-- --
local Dynamic

--- Adds an item to the block's list.
-- @param item Item to add.
-- @callable func Commands to use on _item_, according to the type of event block.
-- @treturn function X
function EventBlock:AddToList_Dynamic (item, func, arg1, arg2)
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

--- Indicates whether a block can occupy a region without overlapping a different block.
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
function EventBlock:CanOccupy (col1, row1, col2, row2)
	local count, id = 0, self.m_id

	for index in Block(col1, row1, col2, row2) do
		local bid = BlockIDs[index]

		if bid and bid ~= id then
			count = count + 1
		end
	end

	return count == 0, count
end

--- Triggers a dust effect over the block's region.
-- @uint nmin Minimum number of clouds to randomly throw up...
-- @uint nmax ...and maximum.
-- @treturn uint Total time elapsed, in milliseconds, by effect.
-- @see s3_utils.fx.Poof
function EventBlock:Dust (nmin, nmax)
	local total = 0

	for _ = 1, random(nmin, nmax) do
		local col, row = random(self.m_cmin, self.m_cmax), random(self.m_rmin, self.m_rmax)
		local index = tile_maps.GetTileIndex(col, row)
		local x, y = tile_maps.GetTilePos(index)

		total = max(total, fx.Poof(MarkersLayer, x, y))
	end

	return total
end

--- Fills a region with occupancy information matching this block.
-- @int col1 A column...
-- @int row1 ... and row.
-- @int col2 Another column...
-- @int row2 ...and row.
function EventBlock:FillRect (col1, row1, col2, row2)
	local id = self.m_id

	for index in Block(col1, row1, col2, row2) do
		BlockIDs[index] = id
	end
end

--- Variant of @{EventBlock:FillRect} that fills the current rect.
-- @see EventBlock:SetRect
function EventBlock:FillSelf ()
	local id = self.m_id

	for index in BlockSelf(self) do
		BlockIDs[index] = id
	end
end

--- Getter.
-- @treturn int Minimum column...
-- @treturn int ...and maximum.
function EventBlock:GetColumns ()
	return self.m_cmin, self.m_cmax
end

--- Getter.
-- @treturn DisplayGroup The block's main group.
function EventBlock:GetGroup ()
	return self.m_bgroup
end

--- Getter.
-- @treturn DisplayGroup The block's image group.
function EventBlock:GetImageGroup ()
	return self.m_igroup
end

--- Gets the rect that was current at block initialization.
-- @bool flagged If true, cull any unflagged outer rows and columns.
-- @treturn int Minimum column...
-- @treturn int ...and row.
-- @treturn int Maximum column...
-- @treturn int ...and row.
function EventBlock:GetInitialRect (flagged)
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

--- Getter.
-- @int index Tile index.
-- @treturn uint Tile flags at block creation time.
-- @see s3_utils.tile_flags.GetFlags
function EventBlock:GetOldFlags (index)
	return OldFlags[index] or 0
end

--- Getter.
-- @treturn int Minimum row...
-- @treturn int ...and maximum.
function EventBlock:GetRows ()
	return self.m_rmin, self.m_rmax
end

--- Getters.
-- @treturn boolean List has items?
function EventBlock:HasItems ()
	return self.m_list ~= nil
end

--- Injects a new group above the image group's parent: i.e. the new group becomes
-- the image group's parent, and is added as a child of the old parent.
--
-- By default, the image group belongs to the main group.
-- @treturn DisplayGroup The injected group.
function EventBlock:InjectGroup ()
	local new, parent = display.newGroup(), self.m_igroup.parent

	new:insert(self.m_igroup)
	parent:insert(new)

	return new
end

--- Iterates over a given region.
-- @int col1 A column...
-- @int row1 ... and row.
-- @int col2 Another column...
-- @int row2 ...and row.
-- @treturn iterator Supplies tile index, column, row.
function EventBlock:Iter (col1, row1, col2, row2)
	return Block(col1, row1, col2, row2)
end

-- Helper to iterate list
local function AuxIterList (list, index)
	index = index + 4

	local item = list and list[index]

	if item and index <= list.n then
		return index, item, list[index + 1], list[index + 2], list[index + 3]
	end
end

--
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

--- Performs some operation on each item in the list.
-- @callable visit Visitor function, called as `visit(item, func, arg1, arg2)`, with inputs
-- as assigned by @{EventBlock:AddToList}.
-- @treturn iterator Supplies tile index, item, commands function, argument #1, argument #2.
function EventBlock:IterList (visit)
	local list, dlist = self.m_list, self.m_dynamic_list

	if dlist then
		list = AddDynamicItems(self, dlist, list)
	elseif list then
		list.n = list.top
	end

	return AuxIterList, list, -3
end

--- Variant of @{EventBlock:Iter} that iterates over the current rect.
-- @treturn iterator Supplies tile index, column, row.
-- @see EventBlock:SetRect
function EventBlock:IterSelf ()
	return BlockSelf(self)
end

-- Temporary holding area for flags to use in another group --
local FlagsTemp

--- Populates the flags in another group with the block's old flags, zeroing out a one-cell
-- rect around them for safety.
-- @param[opt=self] name Name of flag group, cf. @{tile_flags.UseFlags}.
function EventBlock:MakeIsland (name)
	for index in self:IterSelf() do
		FlagsTemp[index] = GetFlags(index)
	end

	local cur = tile_flags.UseFlags(name or self)
	local cmin, cmax = self:GetColumns()
	local rmin, rmax = self:GetRows()

	for index in self:Iter(cmin - 1, rmin - 1, cmax + 1, rmax + 1) do
		SetFlags(index, FlagsTemp[index] or 0)

		FlagsTemp[index] = nil -- ensure boundary of zeroes
	end

	tile_flags.ResolveFlags()
	tile_flags.UseFlags(cur)
end

--- Sets the block's current rect, as used by the ***Self** methods.
--
-- Until this call, the current rect will be equivalent to @{EventBlock:GetInitialRect}'s
-- result (with _flagged_ false).
--
-- If the rect is null, those methods will be no-ops.
-- @int col1 A column...
-- @int row1 ...and row.
-- @int col2 Another column...
-- @int row2 ...and row.
function EventBlock:SetRect (col1, row1, col2, row2)
	BindExtents(col1, row1, col2, row2)

	self.m_cmin, self.m_cmax = CMin, CMax
	self.m_rmin, self.m_rmax = RMin, RMax
end

--- Wipes event block state (flags, occupancy) in a given region.
-- @int col1 A column...
-- @int row1 ... and row.
-- @int col2 Another column...
-- @int row2 ...and row.
function EventBlock:WipeRect (col1, row1, col2, row2)
	for index in Block(col1, row1, col2, row2) do
		Wipe(index)
	end
end

--- Variant of @{EventBlock:WipeRect} that wipes the current rect.
-- @see EventBlock:SetRect
function EventBlock:WipeSelf ()
	for index in BlockSelf(self) do
		Wipe(index)
	end
end

-- Prepares a new event block
local function NewBlock (col1, row1, col2, row2)
	-- Validate the block region, saving indices as we go to avoid repeating some work.
	local block = {}

	for index in Block(col1, row1, col2, row2) do
		assert(not OldFlags[index], "Tile used by another block")

		block[#block + 1] = index
	end

	-- Now that the true column and row values are known (from running the iterator),
	-- initialize the current values.
	block.m_cmin, block.m_rmin = CMin, RMin
	block.m_cmax, block.m_rmax = CMax, RMax
	block.m_bgroup = display.newGroup()

	-- Save the initial rect, given the current values --
	block.m_cmin_save, block.m_rmin_save = block.m_cmin, block.m_rmin
	block.m_cmax_save, block.m_rmax_save = block.m_cmax, block.m_rmax

	-- Lift any tile images into the block's own group. Mark the block region as occupied
	-- and cache the current flags on each tile, for restoration.
	block.m_id, block.m_igroup = #Blocks + 1, display.newGroup()

	for i, index in ipairs(block) do
		block[i] = GetImage(index) or false

		if block[i] then
			block.m_igroup:insert(block[i])
		end

		BlockIDs[index] = block.m_id
		OldFlags[index] = GetFlags(index)
	end

	block.m_bgroup:insert(block.m_igroup)
	TilesLayer:insert(block.m_bgroup)

	Blocks[block.m_id] = block

	meta.Augment(block, EventBlock)

	return block
end

-- Block events --
local Events

-- Event block type lookup table --
local EventBlockList

--- Adds a block to the level and registers an event for it.
-- @ptable info Block info, with at least the following properties:
--
-- * **name**: **string** The event is registered under this name, which should be unique
-- among event blocks.
-- * **type**: **string** One of the choices reported by @{GetTypes}.
-- * **col1**, **row1**, **col2**, **row2**: **int** Columns and rows defining the block.
-- These will be sorted and clamped, as with block operations.
--
-- @todo Detect null blocks? Mention construction, EventBlock:Reset
function M.AddBlock (info)
	local block = NewBlock(info.col1, info.row1, info.col2, info.row2)
	local event, cmds = assert(EventBlockList[info.type], "Invalid event block")(info, block)

	bind.Publish("loading_level", event, info.uid, "fire")
	bind.SetActionCommands(event, cmds)

	Events[#Events + 1] = event -- TODO: Forgo this when not debugging?
end

-- Keys referenced in editor event --
local BlockKeys = { "type", "col1", "row1", "col2", "row2" }

--- Handler for event block-related events sent by the editor.
--
-- If an editor event function is available for _type_, if will be called afterward as
-- `func(what, arg1, arg2, arg3)`.
-- @string type Event block type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result(s) of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local cons = EventBlockList[type]

	if cons then
		local event = cons("editor_event")

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
			return "event_block"

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

--- Getter.
-- @param name Name used to register event in @{AddBlock}.
-- @treturn callable If missing, a no-op. Otherwise, this is a function called as
--   result = event(what, arg1, arg2)
-- which should handle the following choices of _what_:
--
-- * **"fire"**: Fires the event. _arg1_ indicates whether the source, e.g. a switch, wants
-- to fire forward or backward (forward = true), for events that make such distinctions.
-- If _result_ is **"failed"**, the event was unable to fire.
-- * **"is_done"**: If _result_ is false, the event is still in progress.
-- * **"show"**: Shows or hides event hints. _arg1_ is the responsible party for firing
-- events, e.g. a switch, and _arg2_ is a boolean (true = show).
--
-- **CONSIDER**: Formalize _arg1_ in "show" more... e.g. an options list (m\_forward is
-- the only one we care about so far)... or maybe JUST the forward boolean, since the
-- hint might as well be compatible with fire?
function M.GetEvent (name)
	return Events[name] or function() end -- TODO: Remove this function?
end

--- Fires all events.
-- @bool forward Forward boolean, argument to event's **"fire"** handler.
function M.FireAll (forward)
	forward = not not forward

	for _, v in ipairs(Events) do
		local commands = bind.GetActionCommands(v)

		if commands then
			commands("set_direction", forward)
		end

		v()
	end
end

--- Getter.
-- @treturn {string,...} Unordered list of event block type names.
function M.GetTypes ()
	local types = {}

	for k in pairs(EventBlockList) do
		types[#types + 1] = k
	end

	return types
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		Blocks, BlockIDs, Events, FlagsTemp, OldFlags = {}, {}, {}, {}, {}
		MarkersLayer = level.markers_layer
		TilesLayer = level.tiles_layer
	end,

	-- Leave Level --
	leave_level = function()
		Blocks, BlockIDs, Dynamic, Events, FlagsTemp, MarkersLayer, OldFlags, TilesLayer = nil
	end,

	-- Pre-Reset --
	pre_reset = function()
		if #Blocks > 0 then
			BlockIDs = {}
		end

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
		for _, block in ipairs(Blocks) do
			if block.Reset then
				block:Reset()
			end

			block:SetRect(block:GetInitialRect()) -- TODO: Make responsibilty of event?
			block:FillSelf()
		end
	end,

	-- Things Loaded --
	things_loaded = function()
		local event = { name = "event_block_setup" }

		for _, block in ipairs(Blocks) do
			event.block = block

			Runtime:dispatchEvent(event)
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Install various types of events.
EventBlockList = require_ex.DoList("config.EventBlocks")

-- Export the module.
return M