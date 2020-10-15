--- Pools for various resources, to be recycled through effects.

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
local max = math.max
local remove = table.remove

-- Solar2D globals --
local display = display
local timer = timer

-- Exports --
local M = {}

--
--
--

local function Pull (cset, what, into)
	local cache = cset and cset[what]
	local object = cache and remove(cache)

	if object then
		into:insert(object) 
	end

	return object
end

local function NewCircle (into)
	return display.newCircle(into, 0, 0, 1)
end

local Circles

--- If a circle has been stashed in a certain cache, it will be pulled out and recycled.
-- Otherwise, a fresh circle is created with default properties.
-- @param what Name of a cache which may contain circles deposited by @{PushCircle}.
-- @pgroup[opt] into Group into which the circle is pulled. If absent, the stage.
-- @callable[opt] new Circle constructor, which takes _into_ as argument and returns a
-- circle display object; if absent, a default is used.
-- @treturn DisplayCircle Circle display object.
function M.PullCircle (what, into, new)
	into = into or display.getCurrentStage()

	return Pull(Circles, what, into) or (new or NewCircle)(into)
end

--
--
--

local function NewRect (into)
	return display.newRect(into, 0, 0, 1, 1)
end

local Rects

--- If a rect has been stashed in a certain cache, it will be pulled out and recycled.
-- Otherwise, a fresh rect is created with default properties.
-- @param what Name of a cache which may contain rects deposited by @{PushRect}.
-- @pgroup[opt] into Group into which the rect is pulled. If absent, the stage.
-- @callable[opt] new Rect constructor, which takes _into_ as argument and returns a rect
-- display object; if absent, a default is used.
-- @treturn DisplayRect Rect display object.
function M.PullRect (what, into, new)
	into = into or display.getCurrentStage()

	return Pull(Rects, what, into) or (new or NewRect)(into)
end

--
--
--

local Stash

local function AddToCache (cache, object)
	if display.isValid(object) then
		if display.isValid(Stash) then
			if object.parent ~= Stash then
				cache[#cache + 1] = object
			end

			Stash:insert(object)
		else
			object:removeSelf()
		end
	end
end

local function AddFromGroup (into, from, last)
	for i = from.numChildren, max(last, 1), -1 do
		AddToCache(into, from[i])
	end
end

local function Push (list, what, object, how)
	if list then
		local cache = list[what] or {}

		if how == "is_group" or how == "is_dead_group" then
			if how == "is_dead_group" then
				object.isVisible = false

				timer.performWithDelay(100, function(event)
					if display.isValid(object) then
						AddFromGroup(cache, object, object.numChildren - 10)

						if object.numChildren > 0 then
							return
						else
							object:removeSelf()
						end
					end

					timer.cancel(event.source)
				end, 0)
			else
				AddFromGroup(cache, object, 1)
			end
		else
			AddToCache(cache, object)
		end

		list[what] = cache
	elseif display.isValid(object) then
		object:removeSelf()
	end
end

--- Stash one or more circles for later retrieval by @{PullCircle}.
-- @param what Name of a cache (will be created if absent).
-- @pobject circle A group or circle, pushed according to _how_.
-- @string how As per @{PushRect}, _mutatis mutandis_.
function M.PushCircle (what, circle, how)
	Push(Circles, what, circle, how)
end

--
--
--

--- Stash one or more rects for later retrieval by @{PullRect}.
-- @param what Name of a cache (will be created if absent).
-- @pobject rect A group or rect, pushed according to _how_.
-- @string[opt] how If this is **"is\_group"**, _rect_ must be a display group containing
-- only rects. All of its elements will be emptied into the cache.
--
-- If it is **"is\_dead\_group"**, _rect_ is also such a group. In this case, elements are
-- gradually transferred to the cache, after which _rect_ will remove itself.
--
-- Otherwise, _rect_ is a display rect and is sent to the cache.
function M.PushRect (what, rect, how)
	Push(Rects, what, rect, how)
end

--
--
--

Runtime:addEventListener("leave_level", function()
	local stash = Stash

	timer.performWithDelay(200, function(event)
		local n = stash.numChildren

		if n > 0 then
			for i = n, max(n - 15, 1), -1 do
				stash:remove(i)
			end
		else
			timer.cancel(event.source)

			stash:removeSelf()
		end
	end, 0)

	Circles, Rects, Stash = nil
end)

--
--
--

Runtime:addEventListener("things_loaded", function()
	Circles, Rects = {}, {}
	Stash = display.newGroup()

	Stash.isVisible = false
end)

--
--
--

return M