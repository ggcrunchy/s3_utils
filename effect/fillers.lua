--- Various space-filling operations.
--
-- This module lays claim to the **"filler"** set, cf. @{s3_utils.effect.stash}.

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
local ceil = math.ceil
local format = string.format
local max = math.max
local min = math.min
local pairs = pairs

-- Modules --
local audio = require("corona_utils.audio")
local circle = require("s3_utils.fill.circle")
local color = require("corona_ui.utils.color")
local flood = require("s3_utils.fill.flood")
local length = require("tektite_core.number.length")
local sheet = require("corona_utils.sheet")
local stash = require("s3_utils.effect.stash")
local tile_maps = require("s3_utils.tile_maps")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local transition = transition

-- Exports --
local M = {}

-- Tile dimensions --
local TileW, TileH

-- Image sheets, cached from fill images used on this level --
local ImageCache



-- --
local Batch = {}

--- DOCME
-- @pgroup group
-- @param ... ARGS
function M.Begin_Color (group, ...)
	assert(not Batch.group, "Batch already in progress")

	Batch.group, Batch.color = group, color.PackColor_Number(...)
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

--- DOCME
-- @string[opt="flood_fill"] how X
function M.End (how)
	local n = Batch.n

	assert(n and n > 0, "No regions added")

	--
	local maxc, maxr, minc, minr = 0, 0, 1, 1, tile_maps.GetCounts()

	for i = 1, n, 2 do
		local ulc, ulr = tile_maps.GetCell(Batch[i])
		local lrc, lrr = tile_maps.GetCell(Batch[i + 1])

		minc, maxc = min(ulc, minc), max(lrc, maxc)
		minr, maxr = min(ulr, minr), max(lrr, maxr)
	end

	--
	local nx, ny, rgba, image = maxc - minc + 1, maxr - minr + 1, Batch.rgba

	if not rgba then
		image = sheet.TileImage(Batch.name, nx, ny)
	end

	-- Prepare work, idle, used
	-- TODO: Other methods?
	local method

	if how == "flood_fill" then
		method = flood
	else
		assert("Unknown method!")
	end

	method.Prepare(nx, ny)

	--
	local closest, group, c0, r0 = 1 / 0, Batch.group

	for i = 1, n, 2 do
		local ul, lr = Batch[i], Batch[i + 1]

		--
		local ulc, ulr = tile_maps.GetCell(ul)
		local lrc, lrr = tile_maps.GetCell(lr)
		local left, y = tile_maps.GetTilePos(ul)

		for dr = 0, lrr - ulr do
			local x = left

			for dc = 0, lrc - ulc do
				local rect

				if rgba then
					rect = display.newRect(group, x, y, TileW, TileH)

					rect:setFillColor(color.UnpackNumber(rgba))
				else
				--	rect = sheet.NewImageAtFrame(group, image, index, x, y)

				--	rect.xScale = dw / rect.width
				--	rect.yScale = dh / rect.height
				end

				method.Add(ulc + dc, ulr + dr, rect)

				x = x + TileW
			end

			y = y + TileH
		end
	end

	method.Run()

	Batch.n, Batch.group, Batch.name, Batch.rgba = 0
end



-- Current fill color for non-images --
local R, G, B = 1, 1, 1

-- Name of fill image --
local UsingImage

-- Fade-in transition --
local FadeInParams = {
	time = 300, alpha = 1, transition = easing.inOutExpo,

	onComplete = function(rect)
		local rgroup = rect.parent

		rgroup.m_unfilled = rgroup.m_unfilled - 1
	end
}

-- Sound played when shape is filled --
local Sounds = audio.NewSoundGroup{ _prefix = "SFX", shape_filled = { file = "ShapeFilled.mp3", wait = 1000 } }

-- Fill transition --
local FillParams = {
	time = 1350, transition = easing.outBounce,

	onComplete = function()
		Sounds:PlaySound("shape_filled")
	end
}

--
local function StashPixels (event)
	stash.PushRect("filler", event.m_object, "is_group")
end

do
	-- Kernel --
	local kernel = { category = "filter", group = "fill", name = "circle" }

	kernel.vertexData = {
		{
			name = "dist",
			default = 0, min = 0, max = math.sqrt(2),
			index = 0
		},
		{
			name = "upper",
			default = 0, min = 0, max = 1,
			index = 1
		},
	}

	kernel.fragment = [[
		P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
		{
			P_UV float len = length(uv - .5);

			return CoronaColorScale(texture2D(CoronaSampler0, uv) * smoothstep(-.017, CoronaVertexUserData.y, CoronaVertexUserData.x - len));
		}
	]]

	graphics.defineEffect(kernel)
end

--- Fills a rectangular region gradually over time, according to a fill process.
--
-- If an image has been assigned with @{SetImage}, it will be used to fill the region.
-- Otherwise, the region is filled with a solid rectangle, tinted according to @{SetColor}.
--
-- Calling @{SetColor} or @{SetImage} will not affect a fill already in progress.
-- @pgroup group Group into which fill graphics are loaded.
-- @string[opt="circle"] how The fill process, which currently may be **"circle"**.
-- @number ulx Upper-left x-coordinate...
-- @number uly ...and y-coordinate.
-- @number lrx Lower-right x-coordinate...
-- @number lry ...and y-coordinate.
-- @treturn DisplayObject "Final" result of fill. Changing its parameters during the fill
-- may lead to strange results. It can be removed to cancel the fill.
function M.Fill (group, how, ulx, uly, lrx, lry)
	-- Lazily load sounds on first fill.
	Sounds:Load()

	-- Prepare the "final" object, that graphically matches the composite fill elements
	-- and will be left behind in their place once the fill operation is complete. Kick
	-- off the fill transition; as the object scales, the fill process will update to
	-- track its dimensions.
	local filler

	if UsingImage then
		filler = display.newImage(group, UsingImage)
	else
		filler = display.newRect(group, 0, 0, 1, 1)
	end

	local cx, w = (ulx + lrx) / 2, TileW / 2
	local cy, h = (uly + lry) / 2, TileH / 2

	filler.x, filler.width = cx, w
	filler.y, filler.height = cy, h

	FillParams.width = lrx - ulx
	FillParams.height = lry - uly

	transition.to(filler, FillParams)

	-- Extract useful effect values from the fill dimensions.
	local tilew, tileh = TileW / 2.5, TileH / 2.5
	local halfx, halfy = ceil(FillParams.width / tilew - 1), ceil(FillParams.height / tileh - 1)
	local nx, ny = halfx * 2 + 1, halfy * 2 + 1
	local dw, dh = FillParams.width / nx, FillParams.height / ny

	-- Save the current fill color or image. In the image case, tile it, then cache the
	-- tiling, since it may be reused, e.g. on level reset; if a tiling already exists,
	-- use that.
	local r, g, b = R, G, B
	local cur_image

	if UsingImage then
		local key = format("%s<%i,%i>", UsingImage, nx, ny)

		cur_image = ImageCache[key]

		if not cur_image then
			cur_image = { mid = halfy * nx + halfx + 1 }

			cur_image.isheet = sheet.TileImage(UsingImage, nx, ny)

			ImageCache[key] = cur_image
		end
	else
		filler:setFillColor(r, g, b)
	end

	-- Circle --
	if how == "circle" then
		local rgroup = display.newGroup()

		group:insert(rgroup)

		rgroup.m_unfilled = nx * ny

		-- A circle, quantized into subrectangles, which are faded in as the radius grows.
		-- In the image case, the rect will be an unanimated (??) sprite generated by the
		-- image tiling; otherwise, we pull the rect from the stash, if available. On each
		-- addition, a "spots remaining" counter is decremented. 
		local spread = circle.SpreadOut(halfx, halfy, function(x, y)
			local rx, ry, rect = cx + (x - .5) * dw, cy + (y - .5) * dh

			if cur_image then
				local index = cur_image.mid + y * nx + x

				rect = sheet.NewImageAtFrame(rgroup, cur_image.isheet, index, rx, ry, dw, dh)

				rect.xScale = dw / rect.width
				rect.yScale = dh / rect.height
			else
				rect = stash.PullRect("filler", rgroup)

				rect.x, rect.width = rx + dw / 2, dw
				rect.y, rect.height = ry + dh / 2, dh

				rect:setFillColor(r, g, b)
			end

			rect.alpha = .05

			transition.to(rect, FadeInParams)
		end)

		-- The final object begins hidden, since it will be built up visually from the fill
		-- components. Over time, fit its current shape to a circle and act in that region.
--[[
		filler.isVisible = false

		timers.RepeatEx(function()
			if display.isValid(filler) then
				local radius = length.ToBin_RoundUp(filler.width / dw, filler.height / dh, 1.15, .01)

				spread(radius)

				-- If there are still spots in the region to fill, quit. Otherwise, show the
				-- final result and go on to the next steps.
				if rgroup.m_unfilled ~= 0 then
					return
				end

				filler.isVisible = true
			end

			-- If the fill finished or was cancelled, we remove the intermediate components.
			-- In the case of an image, it's too much work to salvage anything, so just remove
			-- the group. Otherwise, stuff the components back into the stash.
			timers.DeferIf(cur_image and "remove" or StashPixels, rgroup)

			return "cancel"
		end, 45)]]
		filler.fill.effect = "filter.fill.circle"

		transition.to(filler.fill.effect, { dist = math.sqrt(2), upper = .557, time = 1100 })

	-- Other options: random fill, cross-fade, Hilbert...
	else
		
	end

	return filler
end

--- Setter.
-- @byte r Red component of fill color. If absent, old value is retained (by default, 1).
-- @byte g ...green component, likewise...
-- @byte b ...and blue component.
function M.SetColor (r, g, b)
	R, G, B = r or R, g or G, b or B
end

--- Setter.
-- @string name Filename of fill image, or **nil** to clear the image.
function M.SetImage (name)
	UsingImage = name
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		ImageCache = {}
		TileW = level.w
		TileH = level.h
	end,

	-- Leave Level --
	leave_level = function()
		ImageCache = nil
	end,

	-- Reset Level --
	reset_level = function()
		for k in pairs(ImageCache) do
			ImageCache[k] = nil
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M