--- Functionality for in-game controls.
--
-- Various elements are added to the GUI; where possible, device input is used as well.
--
-- In the case of screen taps, the **"tapped_at"** event is dispatched with the screen x- and
-- y-coordinates under keys **x** and **y** respectively.

-- FIXLISTENER above stuff

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

-- Modules --
local action = require("s3_utils.hud.action")
local device = require("solar2d_utils.device")
local move = require("s3_utils.hud.move")

-- Solar2D globals --
local Runtime = Runtime
local system = system

-- Solar2D modules --
local composer = require("composer")

-- Cached module references --
local _Clear_

-- Exports --
local M = {}

--
--
--

-- Which way are we trying to move?; which way were we moving? --
local Dir, Was

-- A second held direction, to change to if Dir is released (seems to smooth out key input) --
local ChangeTo

-- Number of frames left of "cruise control" movement --
local FramesLeft = 0

--- DOCME
function M.Clear ()
	Dir, Was = nil
	ChangeTo = nil
	FramesLeft = 0
end

--
--
--

local MovementBeganEvent = { name = "movement_began" }

local function BeginDir (target)
	local dir = target.m_dir

	if not Dir then
		Dir, Was = dir, dir

		Runtime:dispatchEvent(MovementBeganEvent)
	elseif Dir ~= dir and not ChangeTo then
		ChangeTo = dir
	else
		return false
	end

	return true
end

local function EndDir (target)
	local dir = target.m_dir

	if Dir == dir or ChangeTo == dir then
		if Dir == dir then
			Dir = ChangeTo
			Was = Dir or Was
		end

		ChangeTo = nil
	end
end

local IsActive

local ActionEvent = { name = "do_action" }

local function DoActions ()
	if IsActive then
		Runtime:dispatchEvent(ActionEvent)
	end
end

-- Key input passed through BeginDir / EndDir, pretending to be a button --
local PushDir = {}

-- Processes direction keys or similar input, by pretending to push GUI buttons
local function KeyEvent (event)
	local key = device.TranslateButton(event) or event.keyName

	-- Directional keys from D-pad or trackball: move in the corresponding direction.
	-- The trackball seems to produce the "down" phase followed immediately by "up",
	-- so we let the player coast along for a few frames unless interrupted.
	-- TODO: Secure a Play or at least a tester, try out the D-pad (add bindings)
	if key == "up" or key == "down" or key == "left" or key == "right" then
		if IsActive then
			PushDir.m_dir = key

			if event.phase == "up" then
				EndDir(PushDir)
			elseif BeginDir(PushDir) then
				FramesLeft = 6
			end
		end

	-- Confirm key or trackball press: attempt to perform player actions.
	-- TODO: Add bindings
	elseif key == "center" or key == "space" then
		if event.phase == "down" then
			DoActions()
		end

	-- Propagate other / unknown keys; otherwise, indicate that we consumed the input.
	else
		return "call_next_handler"
	end

	return true
end

local Platform = system.getInfo("environment") == "device" and system.getInfo("platform")

--- DOCME
function M.Init (params)
	-- Add input UI elements.
	action.AddActionButton(params.hud_group, DoActions)

	if Platform == "android" or Platform == "ios" then
		move.AddJoystick(params.hud_group)
	end

	-- Bind controller input.
	device.MapAxesToKeyEvents(true)

	-- Track events to maintain input.
	local handle_key = composer.getVariable("handle_key")

	handle_key:Clear() -- TODO: kludge because we don't go through title screen to wipe quick test
	handle_key:Push(KeyEvent)
end

--
--
--

local Source

--- DOCME
function M.SetDirectionSource (func)
	Source = func
end

--
--
--

local MoveEvent = { name = "move_subject" }

-- Update player if any residual input is in effect
-- @number dt 
function M.UpdatePlayer (dt)
	if IsActive then
		if Source then
			MoveEvent.dir = Source()
		else
			MoveEvent.dir = Dir or Was -- favor input direction, else last heading
		end

		if FramesLeft > 0 then
			FramesLeft = FramesLeft - 1 -- wind down any residual motion
		else
			Was = nil
		end

		MoveEvent.dt = dt

		Runtime:dispatchEvent(MoveEvent)
	end
end

--
--
--

--- DOCME
function M.WrapActiveAction (func, def)
	return function(...)
		if IsActive then
			return func(...)
		else
			return def
		end
	end
end

--
--
--

Runtime:addEventListener("disable_input", function()
	IsActive = false

	_Clear_()
end)

--
--
--

Runtime:addEventListener("enable_input", function()
	IsActive = true
end)

--
--
--

Runtime:addEventListener("level_done", function()
	device.MapAxesToKeyEvents(false)
	composer.getVariable("handle_key"):Pop()
end)

--
--
--

device.MapButtonsToAction("space", {
	Xbox360 = "A",
	MFiGamepad = "A",
	MFiExtendedGamepad = "A"
})

--
--
--

_Clear_ = M.Clear

return M