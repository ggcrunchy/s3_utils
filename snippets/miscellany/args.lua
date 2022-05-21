--- Helpers for some types of arguments.

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
local includer = require("solar2d_utils.includer")

-- Globals --
local system = system

-- Exports --
local M = {}

--
--
--

local Order

if system.getInfo("platform") == "win32" then
    function Order (precision, qualifier)
        return precision .. [[ ]] .. qualifier .. "\n"
    end
else
    function Order (precision, qualifier)
        return qualifier .. [[ ]] .. precision .. "\n"
    end
end

--- DOCME
M.INOUT = includer.AddSnippet([[

    #define INOUT_PARAM(precision) ]] .. Order([[precision]], [[inout]]))

--
--
--

--- DOCME
M.OUT = includer.AddSnippet([[

    #define OUT_PARAM(precision) ]] .. Order([[precision]], [[out]]))

--
--
--

return M