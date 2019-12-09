--- Various space-filling operations.

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
local max = math.max
local min = math.min
local random = math.random

-- Extension imports --
local indexOf = table.indexOf

-- Modules --
local audio = require("corona_utils.audio")
local color = require("corona_ui.utils.color")
local directories = require("config.Directories")
local flood = require("s3_utils.fill.flood")
local tile_maps = require("s3_utils.tile_maps")

-- Effects --
local caustics_effect = require("s3_utils.effect.caustics")

-- Corona globals --
local display = display
local timer = timer

-- Exports --
local M = {}

--
--
--

-- Work-in-progress batch --
local Batch

--- Begins a fill batch in color mode.
-- @pgroup group Group which will receive fill components.
-- @param ... Color components, as per **object:setFillColor**.
function M.Begin_Color (group, ...)
	assert(not Batch.group, "Batch already in progress")

	Batch.group, Batch.rgba = group, color.PackColor_Number(...)
end

--- Begins a fill batch in image mode.
-- @pgroup group Group which will receive fill components.
-- @string name Filename of image.
function M.Begin_Image (group, name)
	assert(not Batch.group, "Batch already in progress")

	Batch.group, Batch.name = group, name
end

--- Adds a region of tiles to the batch, to be filled in by the effect.
-- @uint ul Index of upper-left tile in region...
-- @uint lr ...and lower-left tile.
function M.AddRegion (ul, lr)
	assert(Batch.group, "No batch running")

	local n = Batch.n or 0

	Batch[n + 1], Batch[n + 2], Batch.n = ul, lr, n + 2
end

-- Available fill methods --
local Methods = { flood_fill = flood }

-- Sound played when shape is filled --
local Sounds = audio.NewSoundGroup{ _prefix = directories.sound, shape_filled = { file = "ShapeFilled.mp3", wait = 1000 } }

-- Tile dimensions --
local TileW, TileH

-- Running fill effect timers --
local Running

-- Fill options --
local FillOpts = {
	on_done = function(timer)
		Sounds:PlaySound("shape_filled")

		local index, n = indexOf(Running, timer), #Running

		Running[index] = Running[n]
		Running[n] = nil
	end
}

--- Commits the batch, launching an effect.
-- @string[opt="flood_fill"] how Fill method applied to added regions.
function M.End (how)
	local n, method = Batch.n, assert(Methods[how or "flood_fill"], "Invalid fill method")

	assert(n and n > 0, "No regions added")

	-- Lazily load sounds on first fill.
	Sounds:Load()

	-- Find the extents of the amalgamated regions.
	local maxc, maxr, minc, minr = 1, 1, tile_maps.GetCounts()

	for i = 1, n, 2 do
		local ulc, ulr = tile_maps.GetCell(Batch[i])
		local lrc, lrr = tile_maps.GetCell(Batch[i + 1])

		minc, maxc = min(ulc, minc), max(lrc, maxc)
		minr, maxr = min(ulr, minr), max(lrr, maxr)
	end

	-- Get the cell-wise dimensions and prepare the effect.
	local nx, ny, rgba, back = maxc - minc, maxr - minr, Batch.rgba
	local minc2, minr2 = minc + 1, minr + 1

	method.Prepare(nx, ny)

	-- Turn each region into cells and submit them to the effect.
	local x, y = (minc + maxc - 1) * TileW / 2, (minr + maxr - 1) * TileH / 2
	local w, h = (maxc - minc) * TileW, (maxr - minr) * TileH

	if rgba then
		back = display.newRect(Batch.group, x, y, w, h)

		back:setFillColor(color.UnpackNumber(rgba))
	else
		back = display.newImageRect(Batch.group, Batch.name, w, h)

		back.x, back.y = x, y
	end

	back.fill.effect = caustics_effect

	back.fill.effect.seed = random(1024)

	for i = 1, display.isValid(back) and n or 0, 2 do
		local ul, lr = Batch[i], Batch[i + 1]
		local ulc, ulr = tile_maps.GetCell(ul)
		local lrc, lrr = tile_maps.GetCell(lr)

		for dr = ulr - minr, lrr - minr2 do
			for dc = ulc - minc, lrc - minc2 do
				method.Add(dc + 1, dr + 1, true)
			end
		end
	end

	-- Launch the effect and clear all temporary state.
	Running[#Running + 1] = method.Run(back, FillOpts)

	Batch.n, Batch.group, Batch.name, Batch.rgba = 0
end

-- --
local function CancelRunning ()
	for i = 1, #Running do
		timer.cancel(Running[i])
	end
end

for k, v in pairs{
	leave_level = function()
		CancelRunning()

		Batch, Running = nil
	end,

	reset_level = function()
		CancelRunning()

		Batch, Running = {}, {}
	end,

	things_loaded = function(level)
		Batch, Running = {}, {}
		TileW = level.w
		TileH = level.h
	end
} do
	Runtime:addEventListener(k, v)
end

return M