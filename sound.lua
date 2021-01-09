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
local audio = require("solar2d_utils.audio")
local events = require("solar2d_utils.events")
local multicall = require("solar2d_utils.multicall")

-- Solar2D globals --
local system = system

-- Exports --
local M = {}

--
--
--

local Actions, Events = {}, {}

--- DOCME
function M.editor ()
	return {
		actions = Actions, events = Events,
		inputs = {
			boolean = { looping = false--[[, persist_on_reset = false]], streaming = false },
			uint = { delay = 0, loop_count = 1 }
		}
	}
end

--
--
--

function Actions:do_play ()
	local function play ()
		return self.group:PlaySound("sample")
	end

	events.Redirect(play, self)

	return play
end

--
--
--

function Actions:do_pause ()
	return function()
		return self.group:PauseAll()
	end
end

--
--
--

function Actions:do_resume ()
	return function()
		return self.group:ResumeAll()
	end
end

--
--
--

function Actions:do_stop ()
	return function()
		return self.group:StopAll()
	end
end

--
--
--

for _, v in ipairs{ "on_done", "on_stop" } do
	Events[v] = multicall.NewDispatcher()
end

--
--
--

local function IsDone (sound)
	return not sound.group:IsActive()
end

local Sounds

--- DOCME
function M.make (info, params)
	--
	local sample, sound = {
		file = info.filename,
		is_streaming = info.streaming,
		loops = info.looping and "forever" or info.loop_count
	}, system.newEventDispatcher()

	sound.stop_on_reset = not info.persist_on_reset

	if info.on_done or info.on_stop then
		function sample.on_complete (done)
			if Sounds then
				Events[done and "on_done" or "on_stop"]:DispatchForObject(sound)
			end
		end
	end

	sound.group = audio.NewSoundGroup{ sample = sample }

	--
	local psl = params:GetPubSubList()

	for k, event in pairs(Events) do
		psl:Subscribe(info[k], event:GetAdder(), sound)
	end

	--
	for k in adaptive.IterSet(info.actions) do
		psl:Publish(Actions[k](sound), info.uid, k)
	end

	sound.is_done = IsDone

	sound:addEventListener("is_done")

	--
	Sounds = Sounds or {}
	Sounds[#Sounds + 1] = sound
end

--
--
--

Runtime:addEventListener("leave_level", function()
	for i = 1, #(Sounds or "") do
		Sounds[i].group:Remove()
	end

	Sounds = nil
end)

--
--
--

Runtime:addEventListener("reset_level", function()
	for i = 1, #(Sounds or "") do
		local sound = Sounds[i]

		if sound.stop_on_reset then
			sound.group:StopAll()
		end
	end
end)

--
--
--

Runtime:addEventListener("things_loaded", function()
	for i = 1, #(Sounds or "") do
		Sounds[i].group:Load()
	end
end)
	-- ??
	-- reset_level, leave_level: cancel / fade / etc. long-running (relatively speaking, sometimes) sounds,
	-- e.g. voice, background audio (wind, rain, ...)
--
--
--

return M