--- Loading, running, and unloading of game levels.

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
local ipairs = ipairs
local yield = coroutine.yield

-- Modules --
--local actions = require("s3_utils.state.actions")
local _ = require("config.Directories")
local directories = require("s3_utils.directories")
local tile_layout = require("s3_utils.tile_layout")
local tile_maps = require("s3_utils.tile_maps")
local tilesets = require("s3_utils.tilesets")
--local values = require("s3_utils.state.values")

-- Solar2D globals --
local display = display
local graphics = graphics
local Runtime = Runtime
local system = system

-- Exports --
local M = {}

--
--
--

local TypeToFactories = {}

local function FindModule (ttype)
	local sep, label, what = ttype:find("%.")

	if sep then
		assert(sep > 1 and sep < #ttype, "Missing prefix or suffix")

		label, what = ttype:sub(1, sep - 1), ttype:sub(sep) -- n.b. keep the separator...

		assert(label ~= "default", "Thing cannot explicitly have `default` label")
	else
		label, what = "default", "." .. ttype -- ...and manually add it here
	end

	for _, dir in directories.IterateForLabel(label) do
		local res = directories.TryRequire(dir .. what)

		if res then
			return res
		end
	end
end

local function AuxAddThing (info, params)
	local ttype = info.type
	local factories = TypeToFactories[ttype]

	if not factories then
		local mod = FindModule(ttype)

		factories, TypeToFactories[ttype] = mod, mod
	end

	factories.make(info, params)
end

--- DOCME
function M.AddThings (current_level, level, params)
	tilesets.UseTileset(level.tileset or "Tree")

	local tgroup = display.newGroup()

	current_level.tiles_layer:insert(tgroup)

	tile_maps.AddTiles(tgroup, tilesets.NewTile, level)

	local things = level.things

	for i = 1, #(things or "") do
		AuxAddThing(things[i], params)
	end
--[[
	TODO? ideally these are just are covered by the above loop, but the
	current design might still have some kinks left

	-- ...and actions...
	for i = 1, #(level.actions or "") do
		actions.AddAction(level.actions[i], params)
	end

	-- ...and values...
	for i = 1, #(level.values or "") do
		values.AddValue(level.values[i], params)
	end
]]
end

--
--
--

local Groups = { "game_group", "canvas_group", "game_group_dynamic", "hud_group" }

local Canvas

local function InvalidateCanvas ()
	Canvas:invalidate("cache")
end

local CanvasRect

local function SetCanvasRectAlpha (event)
	CanvasRect.alpha = event.alpha
end

--- DOCME
function M.BeforeEntering (w, h)
	return function(view, current_level, level, level_list)
		local ncols, nrows = level.ncols, ceil(#level / level.ncols)

		tile_layout.SetCounts(ncols, nrows)
		tile_layout.SetSizes(w, h)

		for _, name in ipairs(Groups) do
			current_level[name] = display.newGroup()

			view:insert(current_level[name])
		end

		-- Rig up a canvas that captures certain layers for use in post-processing.
		Canvas = graphics.newTexture{
			type = "canvas", width = display.contentWidth, height = display.contentHeight
		}

		current_level.canvas = Canvas

		Canvas:draw(current_level.game_group)
		Runtime:addEventListener("enterFrame", InvalidateCanvas)
		Runtime:addEventListener("set_canvas_alpha", SetCanvasRectAlpha)
		
		Canvas.anchorX, Canvas.anchorY = -.5, -.5

		-- Give it a frame to take hold, and finish up.
		yield()

		CanvasRect = display.newImageRect(current_level.canvas_group, Canvas.filename, Canvas.baseDir, display.contentWidth, display.contentHeight)

		CanvasRect.x, CanvasRect.y = display.contentCenterX, display.contentCenterY

		-- Add game group sublayers, duplicating them in the level info for convenience.
		for i, name in ipairs{ "bg_layer", "tiles_layer", "decals_layer", "things_layer", "markers_layer" } do
			local layer = display.newGroup()

			current_level[name] = layer

			current_level[i > 2 and "game_group_dynamic" or "game_group"]:insert(layer)
		end

		-- Add the level background, falling back to a decent default if none was given.
		local bg_func = level.background or level_list.DefaultBackground

		bg_func(current_level.bg_layer)

		-- Enforce true letterbox mode.
		if display.screenOriginX ~= 0 then
			for i = 1, 2 do
				local border = display.newRect(0, display.contentCenterY, -display.screenOriginX, display.contentHeight)

				border:setFillColor(0)

				border.anchorX, border.x = i == 1 and 1 or 0, i == 1 and 0 or display.contentWidth
			end
		end
	end
end

--
--
--

--- DOCME
function M.Cleanup (current_level)
	for _, name in ipairs(Groups) do
		if name ~= "game_group" then
			display.remove(current_level and current_level[name])
		end
	end

	Canvas:releaseSelf()
	Runtime:removeEventListener("enterFrame", InvalidateCanvas)
	Runtime:removeEventListener("set_canvas_alpha", SetCanvasRectAlpha)

	Canvas, CanvasRect = nil
end

--
--
--

-- Tile names, expanded from two-character shorthands --
local Expansions = tilesets.GetExpansions()

--- DOCME
function M.DecodeTileLayout (level)
	level.ncols = level.main[1]
	level.start_col = level.player.col
	level.start_row = level.player.row

	for i, tile in ipairs(level.tiles.values) do
		level[i] = Expansions[tile] or false
	end
end

--
--
--

--- DOCME
function M.ReturnTo_Win (win_scene, alt_scene)
	return function(info)
		if info.why == "won" and info.which > (system.getPreference("app", "completed", "number") or 0) then
			return win_scene
		else
			return alt_scene
		end
	end
end

--
--
--

return M