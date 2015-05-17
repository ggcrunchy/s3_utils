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

-- Modules --
local require_ex = require("tektite_core.require_ex")
local _ = require("s3_utils.controls")
local dots = require("s3_utils.dots")
local enemies = require("s3_utils.enemies")
local event_blocks = require("s3_utils.event_blocks")
local global_events = require("s3_utils.global_events")
local loop = require_ex.Lazy("corona_boilerplate.game.loop")
local music = require("s3_utils.music")
local persistence = require("corona_utils.persistence")
local player = require("game.Player")
local sound = require("s3_utils.sound")
local tile_maps = require("s3_utils.tile_maps")

-- Corona globals --
local display = display
local timer = timer

-- Exports --
local M = {}

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
function M.AddThings (current_level, level)
	-- Add the tiles to the level...
	local tgroup = tile_maps.NewImageGroup()

	current_level.tiles_layer:insert(tgroup)

	tile_maps.AddTiles(tgroup, level)

	-- ...and the event blocks...
	for _, block in Ipairs(level.event_blocks) do
		event_blocks.AddBlock(block)
	end

	-- ...and the dots...
	for _, dot in Ipairs(level.dots) do
		dots.AddDot(current_level.things_layer, dot)
	end

	-- ...and the player...
	player.AddPlayer(current_level.things_layer, level.start_col, level.start_row)

	-- ...and the enemies...
	for _, enemy in Ipairs(level.enemies) do
		enemies.SpawnEnemy(current_level.things_layer, enemy)
	end

	-- ...and any global events...
	global_events.AddEvents(level.global_events)

	-- ...and music...
	for _, track in Ipairs(level.music) do
		music.AddMusic(track)
	end

	-- ...and sounds.
	for _, sample in Ipairs(level.sound) do
		sound.AddSound(sample)
	end
end

-- Primary display groups --
local Groups = { "game_group", "hud_group" }

--- DOCME
function M.Cleanup (current_level)
	for _, name in ipairs(Groups) do
		display.remove(current_level and current_level[name])
	end
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

		-- Add game group sublayers, duplicating them in the level info for convenience.
		for _, name in ipairs{ "bg_layer", "tiles_layer", "decals_layer", "things_layer", "markers_layer" } do
			local layer = display.newGroup()

			current_level[name] = layer

			current_level.game_group:insert(layer)
		end

		-- Add the level background, falling back to a decent default if none was given.
		local bg_func = level.background or level_list.DefaultBackground

		bg_func(current_level.bg_layer, current_level.ncols, current_level.nrows, w, h)
	end
end

-- Tile names, expanded from two-character shorthands --
local Names = {
	_H = "Horizontal", _V = "Vertical",
	UL = "UpperLeft", UR = "UpperRight", LL = "LowerLeft", LR = "LowerRight",
	TT = "TopT", LT = "LeftT", RT = "RightT", BT = "BottomT",
	_4 = "FourWays", _U = "Up", _L = "Left", _R = "Right", _D = "Down"
}

--- DOCME
function M.DecodeTileLayout (level)
	level.ncols = level.main[1]
	level.start_col = level.player.col
	level.start_row = level.player.row

	for i, tile in ipairs(level.tiles.values) do
		level[i] = Names[tile] or false
	end
end

--- DOCME
-- On(win): unload the level and do win-related logic
function M.ExtendWinEvent ()
	global_events.ExtendAction("win", function()
		timer.performWithDelay(loop.GetWaitToEndTime(), function()
			loop.UnloadLevel("won")
		end)
	end)
end

--- DOCME
function M.ReturnTo_Win (win_scene, alt_scene)
	return function(info)
		if info.why == "won" and info.which > persistence.GetConfig().completed then
			return win_scene
		else
			return alt_scene
		end
	end
end

-- Export the module.
return M