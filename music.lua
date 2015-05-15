--- Various in-game music logic.

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

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local audio = require("corona_utils.audio")
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

--- DOCME
function M.AddMenuMusic (info)
	-- How much can actually be done here? (probably a config file thing...)
end

-- --
local Actions = {
	-- Play --
	do_play = function(music)
		return function(what)
			-- Fire --
			if what == "fire" then
				-- music

			-- Is Done? --
			elseif what == "is_done" then
				return true
			end
		end
	end,

	-- Play (No Cancel) --
	do_play_no_cancel = function(music)
		--
	end,

	-- Pause --
	do_pause = function(music)
		--
	end,

	-- Resume --
	do_resume = function(music)
		--
	end,

	-- Rewind --
	do_rewind = function(music)
		--
	end,

	-- Stop --
	do_stop = function(music)
		--
	end
}

-- --
local Events = {
	on_done = bind.BroadcastBuilder_Helper("loading_level")
}

--- DOCME
function M.AddMusic (info)
	local music = {}

	-- filename: required
	-- is playing: probably automatic, if only one (though should that decision be made here?)...
	-- looping or play count (default to looping)...
	-- Detection for disabled audio option

	--
	if info.on_done ~= nil then
		-- Use onComplete logic...
	end

	--
	if info.play_on_enter then
		--
	end

	if info.play_on_leave then
		--
	end

	--
	for k, event in pairs(Events) do
		event.Subscribe(music, info[k])
	end

	--
	for k in adaptive.IterSet(info.actions) do
		bind.Publish("loading_level", Actions[k](music), info.uid, k)
	end
end

--
local function LinkMusic (music, other, gsub, osub)
	bind.LinkActionsAndEvents(music, other, gsub, osub, Events, Actions, "actions")
end

--- DOCME
function M.EditorEvent (_, what, arg1, arg2)
	-- Enumerate Defaults --
	-- arg1: Defaults
	if what == "enum_defs" then
		arg1.looping = true

	-- Enumerate Properties --
	-- arg1: Dialog
	-- arg2: Representative object
	elseif what == "enum_props" then
		arg1:StockElements(nil, "music")
		arg1:AddSeparator()
		arg1:AddMusicPicker{ text = "Music file", value_name = "filename" }
		arg1:AddLink{ text = "Event links: On(done)", rep = arg2, sub = "on_done", interfaces = "event_target" }
		arg1:AddLink{ text = "Action links: Do(play)", rep = arg2, sub = "do_play", interfaces = "event_source" }
		arg1:AddLink{ text = "Action links: Do(play, no cancel)", rep = arg2, sub = "do_play_no_cancel", interfaces = "event_source" }
		arg1:AddLink{ text = "Action links: Do(pause)", rep = arg2, sub = "do_pause", interfaces = "event_source" }
		arg1:AddLink{ text = "Action links: Do(resume)", rep = arg2, sub = "do_resume", interfaces = "event_source" }
		arg1:AddLink{ text = "Action links: Do(rewind)", rep = arg2, sub = "do_rewind", interfaces = "event_source" }
		arg1:AddLink{ text = "Action links: Do(stop)", rep = arg2, sub = "do_stop", interfaces = "event_source" }
		arg1:AddCheckbox{ text = "Looping?", value_name = "looping" }
		arg1:AddSpinner{ before = "Loop count: ", min = 1, value_name = "loop_count" }

	-- Get Tag --
	elseif what == "get_tag" then
		return "music"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", Events, Actions

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkMusic
	end
end

-- Some default score (perhaps in LevelMap, if not here), if one not present
-- Default reset_level behavior (global action?), override

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		-- boolean?
			-- launch!
	end,

	-- Enter Menus --
	enter_menus = function()
		-- What kind of menu? (e.g. editor shouldn't do anything...)
	end,

	-- Leave Level --
	leave_level = function()
		-- cancel
	end,

	-- Leave Menus --
	leave_menus = function()
		--
	end,

	-- Reset Level --
	reset_level = function()
		-- boolean?
			-- reset playing one
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M