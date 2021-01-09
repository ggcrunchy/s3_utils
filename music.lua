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

--- DOCME
function M.AddMenuMusic ()--info)
	-- How much can actually be done here? (probably a config file thing...)
end

--
--
--

local Actions, Events = {}, {}

--- DOCME
function M.editor ()
	return {
		actions = Actions, events = Events,
		inputs = {
			boolean = { looping = true },
			uint = { loop_count = 1 },
			string = { filename = "" }
		}
	}
end

--
--
--

local Music

local function PlayNewTrack (group)
	for _, track in ipairs(Music) do
		track.group:StopAll()
	end -- ^^ TODO: Fade?

	group:PlaySound("track")
end

function Actions:do_play ()
	local function play ()
		return PlayNewTrack(self.group)
	end

	events.Redirect(play, self)

	return play
end

--
--
--

function Actions:do_play_no_cancel ()
	local function play ()
		return self.group:PlaySound("track")
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

local PlayOnEnter, PlayOnReset

local function IsDone (music)
	return not music.group:IsActive()
end

--- DOCME
function M.make (info, params)
	--
	local music, track = system.newEventDispatcher(), { file = info.filename, is_streaming = true, loops = info.looping and "forever" or info.loop_count }

	if info.on_done or info.on_stop then
		function track.on_complete (done)
			if Music then
				Events[done and "on_done" or "on_stop"]:DispatchForObject(music)
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
		psl:Subscribe(info[k], event:GetAdder(), music)
	end

	--
	for k in adaptive.IterSet(info.actions) do
		psl:Publish(Actions[k](music), info.uid, k)
	end

	music.is_done = IsDone

	music:addEventListener("is_done")

	--
	Music = Music or {}
	Music[#Music + 1] = music
end

--
--
--

Runtime:addEventListener("leave_level", function()
	for i = 1, #(Music or "") do
		Music[i].group:Remove()
	end

	Music, PlayOnEnter, PlayOnReset = nil
end)

--
--
--

Runtime:addEventListener("reset_level", function()
	if PlayOnReset then
		PlayNewTrack(PlayOnReset)
	end
end)

--
--
--

Runtime:addEventListener("things_loaded", function()
	if Music then
		for _, music in ipairs(Music) do
			music.group:Load()
		end

		if PlayOnEnter then -- TODO: could also be in ready_to_go, etc.
			PlayOnEnter:PlaySound("track")
		end
	end
end)

--
--
--

return M