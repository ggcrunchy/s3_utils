--- Functionality for loading game components.

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
local ceil = math.ceil
local ipairs = ipairs
local yield = coroutine.yield

-- Modules --
local require_ex = require("tektite_core.require_ex")
local actions = require("s3_utils.state.actions")
local blocks = require("s3_utils.blocks")
local _ = require("s3_utils.controls")
local dots = require("s3_utils.dots")
local enemies = require("s3_utils.enemies")
local global_events = require("s3_utils.global_events")
local loop = require_ex.Lazy("corona_boilerplate.game.loop")
local music = require("s3_utils.music")
local player = require("game.player.core")
local sound = require("s3_utils.sound")
local tile_maps = require("s3_utils.tile_maps")
local tilesets = require("s3_utils.tilesets")
local triggers = require("s3_utils.triggers")
local values = require("s3_utils.state.values")

-- Corona globals --
local display = display
local graphics = graphics
local Runtime = Runtime
local system = system

-- Exports --
local M = {}

--
--
--

--
local function NoOp () end

-- Helper to iterate on possibly empty tables
local function Ipairs (t)
	if t then
		return ipairs(t)
	else
		return NoOp
	end
end

--- DOCME
function M.AddThings (current_level, level, params)
	tilesets.UseTileset(level.tileset or "tree")

	-- Add the tiles to the level...
	local tgroup = display.newGroup()

	current_level.tiles_layer:insert(tgroup)

	tile_maps.AddTiles(tgroup, level)

	-- ...and the blocks...
	for _, block in Ipairs(level.blocks) do
		blocks.AddBlock(block, params)
	end

	-- ...and the dots...
	for _, dot in Ipairs(level.dots) do
		dots.AddDot(current_level.things_layer, dot, params)
	end

	-- ...and the player...
	player.AddPlayer(current_level.things_layer, level.start_col, level.start_row)

	-- ...and the enemies...
	for _, enemy in Ipairs(level.enemies) do
		enemies.SpawnEnemy(current_level.things_layer, enemy, params)
	end

	-- ...and any global events...
	global_events.AddEvents(level.global_events, params)

	-- ...and any triggers...
	for _, trigger in Ipairs(level.triggers) do
		triggers.AddTrigger(current_level.things_layer, trigger, params)
	end

	-- ...and actions...
	for _, action in Ipairs(level.actions) do
		actions.AddAction(action, params)
	end

	-- ...and values...
	for _, value in Ipairs(level.values) do
		values.AddValue(value, params)
	end

	-- ...and music...
	for _, track in Ipairs(level.music) do
		music.AddMusic(track, params)
	end

	-- ...and sounds.
	for _, sample in Ipairs(level.sound) do
		sound.AddSound(sample, params)
	end
end

-- Primary display groups --
local Groups = { "game_group", "canvas_group", "game_group_dynamic", "hud_group" }

-- --
local Canvas

--
local function InvalidateCanvas ()
	Canvas:invalidate("cache")
end

-- --
local CanvasRect

--
local function SetCanvasRectAlpha (event)
	CanvasRect.alpha = event.alpha
end

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

--- DOCME
function M.BeforeEntering (w, h)
	return function(view, current_level, level, level_list)
		-- Record some information to pass along via dispatch.
		current_level.ncols = level.ncols
		current_level.nrows = ceil(#level / level.ncols)
		current_level.w = w
		current_level.h = h

		-- Add the primary display groups.
		for _, name in ipairs(Groups) do
			current_level[name] = display.newGroup()

			view:insert(current_level[name])
		end

		-- Rig up a canvas that captures certain layers for use in post-processing.
		Canvas = graphics.newTexture{
			type = "canvas", width = display.contentWidth, height = display.contentHeight
		}

		Canvas:draw(current_level.game_group)
		Runtime:addEventListener("enterFrame", InvalidateCanvas)
		Runtime:addEventListener("set_canvas_alpha", SetCanvasRectAlpha)
		
		Canvas.anchorX, Canvas.anchorY = -.5, -.5

		-- Give it a frame to take hold, and finish up.
		yield()

		Runtime:dispatchEvent{ name = "set_canvas", canvas = Canvas }

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

		bg_func(current_level.bg_layer, current_level.ncols, current_level.nrows, w, h)

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

--- DOCME
-- On(win): unload the level and do win-related logic
function M.ExtendWinEvent ()
	global_events.ExtendAction("win", function()
		loop.UnloadLevel("won")
	end)
end

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

return M