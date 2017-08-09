--- Various functionality associated with in-game sound effects.

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
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

-- --
local Sounds

-- --
local Actions = {
	-- Play --
	do_play = function(sound)
		return function(what)
			-- Fire --
			if what == "fire" then
				sound.group:PlaySound("sample")

			-- Is Done? --
			elseif what == "is_done" then
				return not sound.group:IsActive()
			end
		end
	end,

	-- Pause --
	do_pause = function(sound)
		return function(what)
			-- Fire --
			if what == "fire" then
				sound.group:PauseAll()

			-- Is Done? --
			elseif what == "is_done" then
				return true
			end
		end
	end,

	-- Resume --
	do_resume = function(sound)
		return function(what)
			-- Fire --
			if what == "fire" then
				sound.group:ResumeAll()

			-- Is Done? --
			elseif what == "is_done" then
				return true
			end
		end
	end,

	-- Stop --
	do_stop = function(sound)
		return function(what)
			-- Fire --
			if what == "fire" then
				sound.group:StopAll()

			-- Is Done? --
			elseif what == "is_done" then
				return true
			end
		end
	end
}

-- --
local Events = {}

for _, v in ipairs{ "on_done", "on_stop" } do
	Events[v] = bind.BroadcastBuilder_Helper("loading_level")
end

--- DOCME
function M.AddSound (info)
	--
	local sample, sound = {
		file = info.filename,
		is_streaming = info.streaming,
		loops = info.looping and "forever" or info.loop_count
	}, { stop_on_reset = not info.persist_on_reset }

	if info.on_done or info.on_stop then
		function sample.on_complete (done)
			if Sounds then
				Events[done and "on_done" or "on_stop"](sound, "fire", false)
			end
		end
	end

	sound.group = audio.NewSoundGroup{ sample = sample }

	--
	for k, event in pairs(Events) do
		event.Subscribe(sound, info[k])
	end

	--
	for k in adaptive.IterSet(info.actions) do
		bind.Publish("loading_level", Actions[k](sound), info.uid, k)
	end

	--
	Sounds[#Sounds + 1] = sound
end

--
local function LinkSound (sound, other, gsub, osub)
	bind.LinkActionsAndEvents(sound, other, gsub, osub, Events, Actions, "actions")
end

--- DOCME
function M.EditorEvent (_, what, arg1, arg2)
	-- Enumerate Defaults --
	-- arg1: Defaults
	if what == "enum_defs" then
		arg1.delay = 0
		arg1.loop_count = 1
		arg1.looping = false
		arg1.persist_on_reset = false
		arg1.streaming = false

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:StockElements(nil, "sound")
		arg1:AddSeparator()
		arg1:AddSoundPicker{ text = "Sound file", value_name = "filename" }
		arg1:AddCheckbox{ text = "Streaming?", value_name = "streaming" }
		arg1:AddCheckbox{ text = "Persist over reset?", value_name = "persist_on_reset" }
		arg1:AddCheckbox{ text = "Loop forever?", value_name = "looping" }
		-- volume, panning, etc...

		local loop_count_section = arg1:BeginSection()

		arg1:AddSpinner{ before = "Loop count: ", min = 1, value_name = "loop_count" }
		arg1:EndSection()
		arg1:AddSpinner{ before = "Delay between sounds: ", min = 0, inc = 50, value_name = "delay" }
		-- Hook to position??

		--
		arg1:SetStateFromValue_Watch(loop_count_section, "looping", true)

	-- Get Link Info --
	-- arg1: Info to populate
	elseif what == "get_link_info" then
		arg1.on_done = "Event links: On(done)"
		arg1.on_stop = "Event links: On(stop)"
		arg1.do_play = "Action links: Do(play)"
		arg1.do_pause = "Action links: Do(pause)"
		arg1.do_resume = "Action links: Do(resume)"
		arg1.do_stop = "Action links: Do(stop)"

	-- Get Tag --
	elseif what == "get_tag" then
		return "sound"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", Events, Actions

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkSound
	end
end

-- Any useful flags? (Ongoing vs. cut off? Singleton or instantiable? Looping, already playing...)
-- Perhaps impose that sound is singleton (or give warning...) if certain actions are linked

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function()
		Sounds = {}
	end,

	-- Leave Level --
	leave_level = function()
		local sounds = Sounds

		Sounds = nil

		for _, sound in ipairs(sounds) do
			sound.group:Remove()
		end
	end,

	-- Reset Level --
	reset_level = function()
		for _, sound in ipairs(Sounds) do
			if sound.stop_on_reset then
				sound.group:StopAll()
			end
		end
	end,

	-- Things Loaded --
	things_loaded = function()
		for _, sound in ipairs(Sounds) do
			sound.group:Load()
		end
	end
	-- ??
	-- reset_level, leave_level: cancel / fade / etc. long-running (relatively speaking, sometimes) sounds,
	-- e.g. voice, background audio (wind, rain, ...)
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M