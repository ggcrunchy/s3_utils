--- Functionality for in-game controls.
--
-- Various elements are added to the GUI, and where possible device input is used as well.
--
-- In the case of screen taps, the **"tapped_at** event is dispatched with the screen x- and
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

-- Standard library imports --
local setmetatable = setmetatable

-- Modules --
local action = require("s3_utils.hud.action")
local device = require("solar2d_utils.device")
local move = require("s3_utils.hud.move")

-- Plugins --
local bit = require("plugin.bit")

-- Solar2D globals --
local display = display
local Runtime = Runtime
local system = system

-- Solar2D modules --
local composer = require("composer")

-- Cached module references --
local _Flush_

-- Exports --
local M = {}

--
--
--

-- Which way are we trying to move?; which way were we moving? --
local Dir, Was

-- A second held direction, to change to if Dir is released (seems to smooth out key input) --
local ChangeTo

local CancelFunc

-- Begins input in a given direction
local function BeginDir (target)
	local dir = target.m_dir

	if not Dir then
		Dir, Was = dir, dir

		if CancelFunc then
			CancelFunc()
		end
	elseif Dir ~= dir and not ChangeTo then
		ChangeTo = dir
	else
		return false
	end

	return true
end

-- Ends input in a given direction
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

-- Use a joystick? --
local platform = system.getInfo("platform")

local UseJoystick = system.getInfo("environment") == "device" and (platform == "android" or platform == "ios")

local BlockedFlags = 0x1

local InUseFlags = BlockedFlags

local function IsActive ()
	return InUseFlags == 0
end

local ActionsFunc

local function DoActions ()
	if IsActive() and ActionsFunc then
		ActionsFunc()
	end
end

-- Number of frames left of "cruise control" movement --
local FramesLeft = 0

local MovingFunc

-- Updates player if any residual input is in effect
local function UpdatePlayer ()
	if IsActive() then
		-- Choose the player's heading: favor movement coming from input; failing that,
		-- if we still have some residual motion, follow that instead. In any case, wind
		-- down any leftover motion.
		local dir = Dir or Was

		if FramesLeft > 0 then
			FramesLeft = FramesLeft - 1
		else
			Was = nil
		end

		-- Move the player, if we can, and if the player isn't already following a path
		-- (in which case this is handled elsewhere).
		if MovingFunc then
			MovingFunc(dir)
		end
	end
end

-- Key input passed through BeginDir / EndDir, pretending to be a button --
local PushDir = {}

-- Map known controller buttons to keys.
device.MapButtonsToAction("space", {
	Xbox360 = "A",
	MFiGamepad = "A",
	MFiExtendedGamepad = "A"
})

-- Processes direction keys or similar input, by pretending to push GUI buttons
local function KeyEvent (event)
	local key = device.TranslateButton(event) or event.keyName

	-- Directional keys from D-pad or trackball: move in the corresponding direction.
	-- The trackball seems to produce the "down" phase followed immediately by "up",
	-- so we let the player coast along for a few frames unless interrupted.
	-- TODO: Secure a Play or at least a tester, try out the D-pad (add bindings)
	if key == "up" or key == "down" or key == "left" or key == "right" then
		if IsActive() then
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
		if IsActive() and event.phase == "down" then
			DoActions()
		end

	-- Propagate other / unknown keys; otherwise, indicate that we consumed the input.
	else
		return "call_next_handler"
	end

	return true
end

local TappedAtEvent = { name = "tapped_at" }

-- Traps touches to the screen and interprets any taps
local function TrapTaps (event)
	if IsActive() then
		local trap = event.target

		-- Began: Did another touch release recently, or is this the first in a while?
		if event.phase == "began" then
			local now = event.time

			if trap.m_last and now - trap.m_last < 550 then
				trap.m_tapped_when, trap.m_last = now
			else
				trap.m_last = now
			end

		-- Released: If this follows a second touch, was it within a certain interval?
		-- (Doesn't feel like a good fit for a tap if the press lingered for too long.)
		elseif event.phase == "ended" then
			if trap.m_tapped_when and event.time - trap.m_tapped_when < 300 then
				TappedAtEvent.x, TappedAtEvent.y = event.x, event.y

				Runtime:dispatchEvent(TappedAtEvent)
			end

			trap.m_tapped_when = nil
		end
	end

	return true
end

--- DOCME
function M.Init (params)
	local hg = params.hud_group

	-- Add an invisible full-screen rect beneath the rest of the HUD to trap taps
	-- ("tap" events don't seem to play nice with the rest of the GUI).
	local trap = display.newRect(hg, 0, 0, display.contentWidth, display.contentHeight)

	trap:translate(display.contentCenterX, display.contentCenterY)

	trap.isHitTestable = true
	trap.isVisible = false

	trap:addEventListener("touch", TrapTaps)

	-- Add input UI elements.
	action.AddActionButton(hg, DoActions)

	if UseJoystick then
		move.AddJoystick(hg)
	end

	-- Bind controller input.
	device.MapAxesToKeyEvents(true)

	-- Track events to maintain input.
	Runtime:addEventListener("enterFrame", UpdatePlayer)

	local handle_key = composer.getVariable("handle_key")

	handle_key:Clear() -- TODO: kludge because we don't go through title screen to wipe quick test
	handle_key:Push(KeyEvent)
end

--- DOCME
function M.Flush ()
	FramesLeft = 0
	Dir, Was = nil
	ChangeTo = nil
end

local function AssignFlags (flags)
	local was_active = InUseFlags == 0

	InUseFlags = flags

	if was_active and flags ~= 0 then
		_Flush_()
	end
end

local ControlFlag = {}

ControlFlag.__index = ControlFlag

--- DOCME
function ControlFlag:Clear ()
	AssignFlags(bit.band(InUseFlags, bit.bnot(self.m_flag)))
end

--- DOCME
function ControlFlag:Set ()
	AssignFlags(bit.bor(InUseFlags, self.m_flag))
end

local NextInUseFlag = 2 * BlockedFlags

--- DOCME
function M.NewFlag ()
	local flag = NextInUseFlag

	NextInUseFlag = 2 * NextInUseFlag

	return setmetatable({ m_flag = flag }, ControlFlag)
end

function M.SetActionsFunc (func)
	ActionsFunc = func
end

function M.SetCancelFunc (func)
	CancelFunc = func
end

function M.SetMovingFunc (func)
	MovingFunc = func
end

function M.WipeFlags ()
	AssignFlags(0)
end

Runtime:addEventListener("level_done", function()
	AssignFlags(BlockedFlags)

	device.MapAxesToKeyEvents(false)

	Runtime:removeEventListener("enterFrame", UpdatePlayer)

	composer.getVariable("handle_key"):Pop()
end)

_Flush_ = M.Flush

return M