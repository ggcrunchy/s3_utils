--- An abstraction over memory bitmaps for platforms still lacking support.

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
local pairs = pairs

-- Modules --
local meta = require("tektite_core.table.meta")

-- Plugins --
local ok, memoryBitmap = pcall(require, "plugin.memoryBitmap")

-- Corona globals --
local display = display
local graphics = graphics

-- Exports --
local M = {}

--
--
--

local function RoundUpMask (x)
	local xx = x + 13 -- 3 black pixels per side, for mask, plus 7 to round
					  -- all but multiples of 8 past the next such multiple
	return xx - xx % 8 -- Remove the overshot to land on a multiple
end

if ok then
    local Params = {}

    function M.newTexture (params)
        if params.type == "mask" then
            for k, v in pairs(params) do
                if k == "width" or k == "height" then
                    v = RoundUpMask(v)
                end

                Params[k] = v
            end

            params, Params = Params, params
        end

        local texture = memoryBitmap.newTexture(params)

        if params.type == "mask" then
            params, Params = Params, params

            for k in pairs(params) do
                Params[k] = nil
            end
        end

        return texture
    end

    M.newTexture = memoryBitmap.newTexture
else -- minimal shim
    local Bitmap = {}

    function Bitmap:invalidate ()
        self.m_canvas:invalidate("cache")
    end

    function Bitmap:releaseSelf ()
        self.m_canvas:releaseSelf()
    end

    function Bitmap:setPixel (x, y, ...)
        local canvas = self.m_canvas
        local w = canvas.width

        if x >= 1 and x <= w and y >= 1 and y <= canvas.height then
            local index = (y - 1) * w + x

            self.m_group[index]:setFillColor(...)
        end
    end

    local function GetTextureType (ptype)
        if ptype == "mask" then
            return "maskCanvas"
        elseif ptype ~= "rgb" then
            return "canvas"
        end
    end

    function M.newTexture (params)
        local ttype, texture = GetTextureType(params.type)

        if ttype then
            local w, h, tparams = params.width, params.height, { type = ttype }

            if params.type == "mask" then
                tparams.width, tparams.height = RoundUpMask(w), RoundUpMask(h)
            else
                tparams.width, tparams.height = w, h
            end

            local group, canvas = display.newGroup(), graphics.newTexture(tparams)

            texture = { m_canvas = canvas, m_group = group, filename = canvas.filename, baseDir = canvas.baseDir, width = tparams.width, height = tparams.height }

            local left, top = -tparams.width / 2, -tparams.height / 2

            if params.type == "mask" then
                left, top, w, h = left + 3, top + 3, w - 6, h - 6
            end

            group.x, group.y = left, top

            for y = 1, h do
                for x = 1, w do
                    local pixel = display.newRect(group, 0, 0, 1, 1)

                    pixel:setFillColor(0, 0)

                    pixel.anchorX, pixel.x = 0, x - 1
                    pixel.anchorY, pixel.y = 0, y - 1
                end
            end

            canvas:draw(group)

            meta.Augment(texture, Bitmap)
        end

        return texture
    end
end

return M