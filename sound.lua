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

-- Modules --

-- Exports --
local M = {}

--- DOCME
function M.EditorEvent (_, what, arg1, arg2)
	-- Get Tag --
	if what == "get_tag" then
		return "sound"

	-- New Tag --
	elseif what == "new_tag" then
	--	return "sources_and_targets", GetEvent, Actions
	-- GetEvent: sound finished, etc.
	-- Actions: Play... Pause, Resume, Stop (these assume singletons... also, fairly meaningless for short sounds!)

	-- Prep Link --
	elseif what == "prep_link" then
	--	return LinkSound
	end
end

-- Any useful flags? (Ongoing vs. cut off? Singleton or instantiable? Looping, already playing...)
-- Perhaps impose that sound is singleton (or give warning...) if certain actions are linked

-- Listen to events.
for k, v in pairs{
	-- ??
	-- reset_level, leave_level: cancel / fade / etc. long-running (relatively speaking, sometimes) sounds,
	-- e.g. voice, background audio (wind, rain, ...)
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M