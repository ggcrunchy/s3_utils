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
local adaptive = require("tektite_core.table.adaptive")
local audio = require("corona_utils.audio")
local bind = require("tektite_core.bind")

-- Exports --
local M = {}

-- --
local Actions = {} -- Play, etc.

-- --
local Events = {} -- Finished

--
local function LinkSound (sound, other, gsub, osub)
	bind.LinkActionsAndEvents(sound, other, gsub, osub, Events, Actions, "actions")
end

--- DOCME
function M.EditorEvent (_, what, arg1, arg2)
	-- Enumerate Defaults --
	-- arg1: Defaults
	if what == "enum_defs" then
		arg1.reciprocal_link = true

	-- Enumerate Properties --
	-- arg1: Dialog
	-- arg2: Representative object
	elseif what == "enum_props" then
		arg1:StockElements(nil, "sound")
		arg1:AddSeparator()
		arg1:AddSoundPicker{ text = "Sound file", value_name = "filename" }
	--	arg1:AddLink{ text = "Link from source warp", rep = arg2, sub = "from", tags = "warp" }
	--	arg1:AddLink{ text = "Link to target (warp or position)", rep = arg2, sub = "to", tags = { "warp", "position" } }
	--	arg1:AddCheckbox{ text = "Two-way link, if one is blank?", value_name = "reciprocal_link" }
		-- Channel?

	-- Get Tag --
	elseif what == "get_tag" then
		return "sound"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", Events, Actions
	-- GetEvent: sound finished, etc.
	-- Actions: Play... Pause, Resume, Stop (these assume singletons... also, fairly meaningless for short sounds!)

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkSound
	end
end

-- Any useful flags? (Ongoing vs. cut off? Singleton or instantiable? Looping, already playing...)
-- Perhaps impose that sound is singleton (or give warning...) if certain actions are linked

-- Listen to events.
for k, v in pairs{
	enter_level = function()
		-- load sound groups
	end,

	leave_level = function()
		-- remove sound groups
	end
	-- ??
	-- reset_level, leave_level: cancel / fade / etc. long-running (relatively speaking, sometimes) sounds,
	-- e.g. voice, background audio (wind, rain, ...)
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M