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

-- Solar2D globals --
local Runtime = Runtime

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

local function BeginDir (dir)
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

local function EndDir (dir)
	if Dir == dir or ChangeTo == dir then
		if Dir == dir then
			Dir = ChangeTo
			Was = Dir or Was
		end

		ChangeTo = nil
	end
end

--- DOCME
function M.SetDirection (dir, release)
	if release then
		EndDir(dir)
	elseif BeginDir(dir) then
		FramesLeft = 6
	end
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

local IsActive

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

_Clear_ = M.Clear

return M