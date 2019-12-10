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
local ipairs = ipairs
local pairs = pairs

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local audio = require("corona_utils.audio")
local bind = require("corona_utils.bind")
local call = require("corona_utils.call")

-- Corona globals --
local system = system

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.AddMenuMusic (info)
	-- How much can actually be done here? (probably a config file thing...)
end

-- --
local Music

--
local function PlayNewTrack (group)
	if Music then
		for _, track in ipairs(Music) do
			track.group:StopAll()
		end -- ^^ TODO: Fade?

		group:PlaySound("track")
	end
end

-- --
local Actions = {
	-- Play --
	do_play = function(music)
		local function play (arg)
			return PlayNewTrack(music.group)
		end

		call.Redirect(play, music)

		return play
	end,

	-- Play (No Cancel) --
	do_play_no_cancel = function(music)
		local function play ()
			return music.group:PlaySound("track")
		end

		call.Redirect(play, music)

		return play
	end,

	-- Pause --
	do_pause = function(music)
		return function()
			return music.group:PauseAll()
		end
	end,

	-- Resume --
	do_resume = function(music)
		return function()
			return music.group:ResumeAll()
		end
	end,

	-- Stop --
	do_stop = function(music)
		return function()
			return music.group:StopAll()
		end
	end
}

-- --
local Events = {}

for _, v in ipairs{ "on_done", "on_stop" } do
	Events[v] = bind.BroadcastBuilder_Helper()
end

-- --
local PlayOnEnter, PlayOnReset

local function IsDone (music)
	return not music.group:IsActive()
end

--- DOCME
function M.AddMusic (info, params)
	--
	local music, track = system.newEventDispatcher(), { file = info.filename, is_streaming = true, loops = info.looping and "forever" or info.loop_count }

	if info.on_done or info.on_stop then
		function track.on_complete (done)
			if Music then
				Events[done and "on_done" or "on_stop"](music)
			end
		end
	end

	music.group = audio.NewSoundGroup{ track = track }

	--
	if info.play_on_enter then
		PlayOnEnter = music.group
	end

	if info.play_on_leave then
		PlayOnReset = music.group
	end

	--
	local psl = params:GetPubSubList()

	for k, event in pairs(Events) do
		event.Subscribe(music, info[k], psl)
	end

	--
	for k in adaptive.IterSet(info.actions) do
		bind.Publish(psl, Actions[k](music), info.uid, k)
	end

	music.is_done = IsDone

	music:addEventListener("is_done")

	--
	Music = Music or {}
	Music[#Music + 1] = music
end

--
local function LinkMusic (music, other, msub, osub)
	local helper = bind.PrepLink(music, other, msub, osub)

	helper("try_actions", Actions)
	helper("try_events", Events)
	helper("commit")
end

--- DOCME
function M.EditorEvent (_, what, arg1, arg2)
	-- Enumerate Defaults --
	-- arg1: Defaults
	if what == "enum_defs" then
		arg1.filename = ""
		arg1.loop_count = 1
		arg1.looping = true

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:StockElements()
		arg1:AddSeparator()
		arg1:AddMusicPicker{ text = "Music file", value_name = "filename" }
		arg1:AddCheckbox{ text = "Loop forever?", value_name = "looping" }

		local loop_count_section = arg1:BeginSection()

			arg1:AddStepperWithEditable{ before = "Loop count: ", min = 1, value_name = "loop_count" }

		arg1:EndSection()

		-- volume?

		--
		arg1:SetStateFromValue_Watch(loop_count_section, "looping", "use_false")

	-- Get Link Grouping --
	elseif what == "get_link_grouping" then
		return {
			{ text = "ACTIONS", font = "bold", color = "actions" }, "do_play", "do_play_no_cancel", "do_pause", "do_resume", "do_stop",
			{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "on_done", "on_stop"
		}

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.on_done = "On(done)"
		arg1.on_stop = "On(stop)"
		arg1.do_play = "Play, removing any others"
		arg1.do_play_no_cancel = "Play, leaving others"
		arg1.do_pause = "Pause"
		arg1.do_resume = "Resume"
		arg1.do_stop = "Stop"

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

-- Some default score (perhaps in LevelMap, if not here), if one not present?

for k, v in pairs{
	leave_level = function()
		for i = 1, #(Music or "") do
			Music[i].group:Remove()
		end

		Music, PlayOnEnter, PlayOnReset = nil
	end,

	reset_level = function()
		if PlayOnReset then
			PlayNewTrack(PlayOnReset)
		end
	end,

	things_loaded = function()
		if Music then
			for _, music in ipairs(Music) do
				music.group:Load()
			end

			if PlayOnEnter then -- TODO: could also be in ready_to_go, etc.
				PlayOnEnter:PlaySound("track")
			end
		end
	end
} do
	Runtime:addEventListener(k, v)
end

return M