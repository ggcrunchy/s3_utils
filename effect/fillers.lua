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
local pairs = pairs

-- Modules --
local audio = require("corona_utils.audio")
local color = require("corona_ui.utils.color")
local flood = require("s3_utils.fill.flood")
local sheet = require("corona_utils.sheet")
local tile_maps = require("s3_utils.tile_maps")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Batch

--- DOCME
-- @pgroup group
-- @param ... ARGS
function M.Begin_Color (group, ...)
	assert(not Batch.group, "Batch already in progress")

	Batch.group, Batch.rgba = group, color.PackColor_Number(...)
end

--- DOCME
-- @pgroup group
-- @string name
function M.Begin_Image (group, name)
	assert(not Batch.group, "Batch already in progress")

	Batch.group, Batch.name = group, name
end

--- DOCME
-- @uint ul
-- @uint lr
function M.AddRegion (ul, lr)
	local group = assert(Batch.group, "No batch running")

	if display.isValid(group) then
		local n = Batch.n or 0

		Batch[n + 1], Batch[n + 2], Batch.n = ul, lr, n + 2
	end
end

-- Image sheets, cached from fill images used on this level --
local ImageCache

-- --
local Methods = { flood_fill = flood }

-- Sound played when shape is filled --
local Sounds = audio.NewSoundGroup{ _prefix = "SFX", shape_filled = { file = "ShapeFilled.mp3", wait = 1000 } }

-- Tile dimensions --
local TileW, TileH

-- --
local FillOpts = {
	on_done = function()
		Sounds:PlaySound("shape_filled")
	end
}

--- DOCME
-- @string[opt="flood_fill"] how X
function M.End (how)
	local n, method = Batch.n, assert(Methods[how or "flood_fill"], "Invalid fill method")

	assert(n and n > 0, "No regions added")

	-- Lazily load sounds on first fill.
	Sounds:Load()

	--
	local maxc, maxr, minc, minr = 1, 1, tile_maps.GetCounts()

	for i = 1, n, 2 do
		local ulc, ulr = tile_maps.GetCell(Batch[i])
		local lrc, lrr = tile_maps.GetCell(Batch[i + 1])

		minc, maxc = min(ulc, minc), max(lrc, maxc)
		minr, maxr = min(ulr, minr), max(lrr, maxr)
	end

	--
	local nx, ny, rgba, image = maxc - minc, maxr - minr, Batch.rgba

	if not rgba then
		image = sheet.TileImage(Batch.name, nx, ny)
	end

	method.Prepare(nx, ny)

	--
	local group = Batch.group

	for i = 1, n, 2 do
		local ul, lr = Batch[i], Batch[i + 1]

		--
		local ulc, ulr = tile_maps.GetCell(ul)
		local lrc, lrr = tile_maps.GetCell(lr)
		local left, y = tile_maps.GetTilePos(ul)

		left, y = left + TileW / 2, y + TileH / 2

		for dr = ulr - minr, lrr - minr - 1 do
			local x = left

			for dc = ulc - minc, lrc - minc - 1 do
				local rect

				if rgba then
					rect = display.newRect(group, x, y, TileW, TileH)

					rect:setFillColor(color.UnpackNumber(rgba))
				else
				--	rect = sheet.NewImageAtFrame(group, image, index, x, y)

				--	rect.xScale = dw / rect.width
				--	rect.yScale = dh / rect.height
				end

				method.Add(dc + 1, dr + 1, rect)

				x = x + TileW
			end

			y = y + TileH
		end
	end

	method.Run(FillOpts)

	Batch.n, Batch.group, Batch.name, Batch.rgba = 0
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		Batch, ImageCache = {}, {}
		TileW = level.w
		TileH = level.h
	end,

	-- Leave Level --
	leave_level = function()
		Batch, ImageCache = nil
	end,

	-- Reset Level --
	reset_level = function()
		Batch = {}

		for k in pairs(ImageCache) do
			ImageCache[k] = nil
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M