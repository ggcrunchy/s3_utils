--- Utilities for certain qualifiers.

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

-- Globals --
local system = system

-- Exports --
local M = {}

--
--
--

local SupportsHighPrecision = system.getInfo("gpuSupportsHighPrecisionFragmentShaders")

--- DOCME
function M.DefaultPrecisionOr (alt_precision)
    return SupportsHighPrecision and "P_DEFAULT" or alt_precision
end

--
--
--

local AuxIterPrecision

if SupportsHighPrecision then
    function AuxIterPrecision (_, prev)
        if not prev then
            return "P_DEFAULT", "any"
        end
    end
else
    function AuxIterPrecision (non_default, prev)
        if not prev then
            return "P_DEFAULT", "vertex"
        elseif prev == "P_DEFAULT" then
            return non_default, "fragment"
        end
    end
end

--- DOCME
function M.IterPrecision (non_default)
    return AuxIterPrecision, non_default or "P_POSITION"
end

return M