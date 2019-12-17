--- Common functionality for our nefarious foes.

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
local abs = math.abs
local ipairs = ipairs
local pairs = pairs
local pi = math.pi
local require = require
local sin = math.sin

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local call = require("corona_utils.call")
local collision = require("corona_utils.collision")
local component = require("tektite_core.component")
local enemy_events = require("annex.EnemyEvents")
local flow_ops = require("coroutine_ops.flow")
local object_vars = require("config.ObjectVariables")
local store = require("s3_utils.state.store")
local tile_maps = require("s3_utils.tile_maps")
local timers = require("corona_utils.timers")
local visibility = require("corona_utils.visibility")

-- Corona globals --
local display = display
local Runtime = Runtime
local timer = timer

-- Cached module references --
local _BroadcastEvent_

-- Exports --
local M = {}

--
--
--

local Enemies

--- Dispatch an event to multiple enemies.
-- @ptable event Dispatcher input, i.e. for `enemy:dispatchEvent(event)`.
--
-- If _event_ contains a **sender** field, 
-- @string[opt="all"] how Indicates which non-sender enemies are considered: may be **"all"**
-- for the whole set; **"dead"** for dead ones; or live ones otherwise.
function M.BroadcastEvent (event, how)
	local omit, live_value = event.sender

	if how ~= "all" then
		live_value = how ~= "dead"
	end

	for i = 1, #(Enemies or "") do -- ignore alerts if level ending
		local enemy = Enemies[i]

		if enemy ~= omit and live_value ~= not enemy.m_alive then -- live_value might be nil, but compared to boolean
			enemy:dispatchEvent(event)
		end
	end
end

-- Phase-in period --
local PeriodTime = 1.15

-- Phasing time coefficient --
local PhaseFactor = 2 * pi / PeriodTime

--
local function SetPos (enemy)
	local x, y = enemy.m_start:localToContent(0, 0)

	enemy.x, enemy.y = enemy.parent:contentToLocal(x, y)
end

-- Phase-in effect on spawning enemy
local function PhaseSpawning (t, _, enemy)
	enemy.alpha = abs(sin(PhaseFactor * t.time))

	-- Update the position, since the start point might be moving.
	SetPos(enemy)
end

local function SetTile (enemy)
	enemy.m_tile = tile_maps.GetTileIndex_XY(enemy.x, enemy.y)
end

local function PutInPlace (enemy)
	SetPos(enemy)
	SetTile(enemy)
end

-- Behavior of an enemy after (re)spawning and while waiting to become alive
local function PhaseIn (enemy, type_info, is_sleeping)
	if type_info.Start then
		type_info.Start(enemy)
	end

	--
	enemy.m_ready = not is_sleeping

	flow_ops.WaitForSignal(enemy, "m_ready")
	visibility.Enable(enemy, false)

	--
	enemy.isVisible = true

	flow_ops.Wait(type_info.spawn_time, PhaseSpawning, enemy)

	enemy.alpha = 1

	SetTile(enemy)
end

--
local function ClearLocalVars (enemy)
	store.RemoveFamily(enemy.m_local_vars)

	enemy.m_local_vars = nil
end

-- Common logic to apply when an enemy is killed
local function Kill (enemy, other)
	if enemy.m_alive then
		ClearLocalVars(enemy)

		enemy.m_alive = false

		visibility.Enable(enemy, false)

		enemy_events.on_kill(enemy, other)
	end
end

-- Events an enemy can trigger --
local Events = {}

-- Behavior of an enemy between phasing in and being killed
local function Alive (enemy, type_info)
	--
	Events.on_wake:DispatchForObject(enemy)

	-- Make sure the enemy is visible and alive, i.e. able to hurt you and be hurt itself.
	-- Account for enemies that were phasing in when the dots got cleared.
	enemy.m_alive = not enemy.m_no_respawn

	--
	if enemy.m_alive then
		visibility.Enable(enemy, true)
	end

	-- Have it follow its type-specific behavior, until it gets killed.
	while enemy.m_alive do
		local result, other = type_info.Do(enemy)

		if result == "dead" then
			Kill(enemy, other)
		end
	end
end

-- Behavior of an enemy once killed and while in its death throes
local function Die (enemy, type_info)
	--
	Events.on_die:DispatchForObject(enemy)

	-- If possible, die in some enemy-specific way. Otherwise, fly off.
	if type_info.Die then
		type_info.Die(enemy)
	else
		enemy_events.def_die(enemy)
	end

	-- Clear the velocities in case the enemy gets killed a different way next time.
	enemy_events.post_die(enemy)

	-- Hide the enemy until it rephases.
	enemy.isVisible = false
end

-- Behavior of enemy after its death throes and while waiting to phase in
local function WaitToRespawn (_, type_info)
	flow_ops.Wait(type_info.respawn_delay)
end

-- Coroutine body: Common overall enemy logic
local function EnemyFunc (event, index, type_info, info)
	local enemy = Enemies[index]

	local is_sleeping = info.asleep

	while true do
		PhaseIn(enemy, type_info, is_sleeping)
		Alive(enemy, type_info)
		Die(enemy, type_info)

		if enemy.m_no_respawn then
			timer.pause(event.source)
		else
			is_sleeping = info.sleep_on_death

			WaitToRespawn(enemy, type_info)
		end

		PutInPlace(enemy)
	end
end

-- Enemy actions that can be triggered --
local Actions = {
	-- Do Kill --
	do_kill = function(enemy)
		return function()
			return Kill(enemy)
		end
	end,

	-- Do Wake --
	do_wake = function(enemy)
		return function()
			enemy.m_ready = true
		end
	end
}

-- --
local Properties = {
	boolean = {
		-- --
		alive = function(enemy)
			return function()
				return enemy.m_alive == true
			end
		end
	},

	family = {
		-- --
		local_vars = function(enemy)
			return function()
				if enemy.m_alive then
					enemy.m_local_vars = enemy.m_local_vars or {}

					return enemy.m_local_vars
				else
					return false
				end
			end
		end
	},

	number = {
		-- --
		enemy_x = function(enemy)
			return function()
				return enemy.x
			end
		end,

		-- --
		enemy_y = function(enemy)
			return function()
				return enemy.y
			end
		end,

		-- --
		sp_x = function(enemy)
			local x

			return function()
				x = x or enemy.m_start.x

				return x
			end
		end,

		-- --
		sp_y = function(enemy)
			local y

			return function()
				y = y or enemy.m_start.y

				return y
			end
		end
	}
}

--
local function LinkEnemy (enemy, other, esub, osub)
	local helper = bind.PrepLink(enemy, other, esub, osub)

	helper("try_actions", Actions)
	helper("try_events", Events)
	helper("try_out_properties", Properties)
	helper("commit")
end

--- Handler for enemy-related events sent by the editor.
-- @string type Enemy type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local type_info = nil--EnemyList[type] -- TODO!!!
	local event = type_info and type_info.EditorEvent

	if event then
		-- Build --
		-- arg1: Level
		-- arg2: Original entry
		-- arg3: Spawn point to build
		if what == "build" then
			-- COMMON STUFF
			-- t.col, t.row = ...

		-- Enumerate Defaults --
		-- arg1: Defaults
		elseif what == "enum_defs" then
			arg1.asleep = false
			arg1.sleep_on_death = false
			arg1.can_attach = true

		-- Enumerate Properties --
		-- arg1: Dialog
		elseif what == "enum_props" then
			arg1:StockElements(event("get_thumb_filename"))
			arg1:AddSeparator()
			arg1:AddCheckbox{ text = "Asleep By Default?", value_name = "asleep" }
			arg1:AddCheckbox{ text = "Fall Asleep If Killed?", value_name = "sleep_on_death" }
			arg1:AddCheckbox{ text = "Can Attach To Block?", value_name = "can_attach" }
			arg1:AddSeparator()

		-- Get Link Grouping --
		elseif what == "get_link_grouping" then
			return {
				{ text = "ACTIONS", font = "bold", color = "actions" }, "do_kill", "do_wake",
				{ text = "EVENTS", font = "bold", color = "events", is_source = true }, "on_die", "on_wake",
				{ text = "OUT-PROPERTIES", font = "bold", color = "props", is_source = true }, "alive", "enemy_x", "enemy_y", "sp_x", "sp_y", "local_vars"
			}

		-- Get Link Info --
		-- arg1: Info to populate
		elseif what == "get_link_info" then
			arg1.on_die = "On(die)"
			arg1.on_wake = "On(wake)"
			arg1.do_kill = "Kill enemy"
			arg1.do_wake = "Wake spawner"
			arg1.alive = "BOOL: Is alive?"
			arg1.enemy_x = "NUM: Enemy's x"
			arg1.enemy_y = "NUM: Enemy's y"
			arg1.local_vars = "FAM: Enemy vars"
			arg1.sp_x = "NUM: Spawner's x"
			arg1.sp_y = "NUM: Spawner's y"

		-- Get Tag --
		elseif what == "get_tag" then
			return "enemy"

		-- New Tag --
		elseif what == "new_tag" then
			return "sources_and_targets", Events, Actions, object_vars.UnfoldPropertyFunctionsAsTagReadyList(Properties)

		-- Prep Link --
		elseif what == "prep_link" then
			return LinkEnemy

		-- Verify --
		elseif what == "verify" then
			-- COMMON STUFF... nothing yet, I don't think, assuming well-formed editor
		end

		return event(what, arg1, arg2, arg3)
	end
end

---
-- @treturn {string,...} Unordered list of enemy type names.
--[=[
function M.GetTypes ()
	local types = {}

	for k in pairs(EnemyList) do
		types[#types + 1] = k
	end

	return types
end
]=]
--- Kill all enemies on demand.
function M.KillAll ()
	for _, enemy in ipairs(Enemies) do
		Kill(enemy)
	end
end

-- Enemy situation <-> events bindings --
for _, v in ipairs{ "on_die", "on_wake" } do
	Events[v] = call.NewDispatcher()
end

local EnemyComponent = component.RegisterType{ name = "enemy", interfaces = { "harmable", "harmful", "damage" } }

--- Add a new enemy of type _name_ to the level.
--
-- An enemy follows the life cycle: **wait for (re)spawn &rArr; phase-in &rArr; alive
-- &rArr; death throes &rArr; dead &rArr; wait...**, with most interesting behavior
-- during the **alive** step.
--
-- For each name, there must be a corresponding module **"enemy.Name"** (e.g. for _name_ of
-- **"eraser"**, the module is **"enemy.Eraser"**), the value of which is a table with
-- required fields:
--
-- * **Do**: Function which updates the enemy while alive, called as
--    result, other = Do(enemy).
--
-- A _result_ of **"dead"** will put _enemy_ into the killed state; if _other_ is non-**nil**,
-- it is assumed to be a physics object, its `getLinearVelocity` method is called, and the
-- results are assigned to _enemy_'s **m_vx** and **m_vy** fields.
--
-- * **New**: Function which instantiates the appropriate display object for the enemy
-- along with any state derived from _info_, called as
--    enemy = New(group, info).
--
-- * **respawn_delay**: Delay, in seconds, between the death throes and respawn of this type.
-- * **spawn_time**: Time, in seconds, over which this enemy type phases in.
--
-- Optional elements include:
--
-- * **body**: A body to assign via `physics.addBody`.
-- * **Die**: Function which performs the death throes for this enemy type, called with
-- _enemy_ as argument.
--
-- * **Start**: Function used to prepare the enemy before it begins to phase in, called with
-- _enemy_ as argument.
--
-- **Do**, **Die**, and **Start** are each called within a coroutine context.
-- @pgroup group Display group that will hold the enemy.
-- @ptable info Information about the new enemy. Required fields:
--
-- * **col**: Column on which enemy spawns.
-- * **row**: Row on which enemy spawns.
-- * **type**: Name of enemy type, q.v. _name_, above.
--
-- Instance-specific data may also be passed in other fields.
function M.New (info, params, enemy, type_info)
	Enemies = Enemies or {}
	Enemies[#Enemies + 1] = enemy

	--
	local psl = params:GetPubSubList()

	for k, event in pairs(Events) do
		psl:Subscribe(info[k], event:GetAdder(), enemy)
	end

	--
	for k in adaptive.IterSet(info.actions) do
		psl:Publish(Actions[k](enemy), info.uid, k)
	end

	object_vars.PublishProperties(psl, info.props, Properties, info.uid, enemy)

	-- Find the start tile to (re)spawn the enemy there, and kick off its behavior. Unless
	-- fixed, this starting position may attach to a block and be moved around.
	enemy.m_start = display.newCircle(enemy.parent, 0, 0, 5)

	enemy.m_start.isVisible = false

	tile_maps.PutObjectAt(tile_maps.GetTileIndex(info.col, info.row), enemy.m_start)

	enemy.m_can_attach = not type_info.fixed

	collision.MakeSensor(enemy, "dynamic", type_info.body)
	collision.SetType(enemy, "enemy")
	component.AddToObject(enemy, EnemyComponent)

	enemy.isVisible = false

	PutInPlace(enemy) -- blocks might need this before timer fires

	local index = #Enemies -- avoid enemy being an upvalue

	enemy.m_func = timers.Wrap(30, function(event)
		return EnemyFunc(event, index, type_info, info)
	end)

	timer.pause(enemy.m_func)
end

local ReactEvent = {}

--
local function TryConfigFunc (key, arg)
	local func = enemy_events[key]

	return func and func({
		broadcast_event = _BroadcastEvent_, kill = Kill,

		-- Helper for getting hit by harmful things
		die_or_react = function(enemy, name, okey, object)
			ReactEvent.name, ReactEvent[okey], ReactEvent.result = name, object, "dead"

			enemy:dispatchEvent(ReactEvent)

			ReactEvent[okey] = nil

			if ReactEvent.result == "dead" then
				Kill(enemy, object)
			end
		end,

		-- Helper to apply an action to each enemy
		for_each = function(func, arg)
			for _, enemy in ipairs(Enemies) do
				func(enemy, arg)
			end
		end
	}, arg)
end

--
local OnCollision = TryConfigFunc("on_collision")

local TouchedEnemyEvent = { name = "touched_enemy" }

collision.AddHandler("enemy", function(phase, enemy, other)
	-- Enemy touched enemy: delegate reaction to enemy.
	if collision.GetType(other) == "enemy" then
		TouchedEnemyEvent.phase, TouchedEnemyEvent.enemy = phase, other

		enemy:dispatchEvent(TouchedEnemyEvent)
	
		TouchedEnemyEvent.target = nil
	elseif OnCollision then
		OnCollision(phase, enemy, other)
	end
end)

-- ^^ Make these configable (with all args, DieOrReact)

-- Logic for start positions in blocks
local function BlockFunc (event)
	local start = event.target

	start.m_local_coordinate_system = event.local_coordinate_system

	local x, y = event.group:localToContent(start.m_old_x, start.m_old_y)

	start.rotation, start.x, start.y = event.angle or 0, start.parent:contentToLocal(x, y)
end

local EventToBroadcast

local function Broadcast (name)
	EventToBroadcast = EventToBroadcast or {}
	EventToBroadcast.name = name

	_BroadcastEvent_(EventToBroadcast)
end

local events = {
	block = _BroadcastEvent_,

	block_setup = function(event)
		local block = event.block
		local cmin, cmax = block:GetColumns()
		local rmin, rmax = block:GetRows()

		for i = 1, #(Enemies or "") do
			local enemy = Enemies[i]

			if enemy.m_can_attach then
				local start, col, row = enemy.m_start, tile_maps.GetCell(enemy.m_tile)

				if col >= cmin and col <= cmax and row >= rmin and row <= rmax then
					start.m_old_x, start.m_old_y = start.x, start.y

					start:addEventListener("with_block_update", BlockFunc)
					block:DataStore_Append(start)

					start.m_block = block
				end
			end
		end
	end,

	leave_level = function()
		Broadcast("about_to_leave")

		for i = 1, #(Enemies or "") do
			local enemy = Enemies[i]

			ClearLocalVars(enemy)

			timer.cancel(enemy.m_func)
		end

		EventToBroadcast, Enemies = nil
	end,

	reset_level = function()
		Broadcast("about_to_reset")

		for i = 1, #(Enemies or "") do
			local enemy = Enemies[i]

			ClearLocalVars(enemy)

			enemy.m_alive = false

			enemy_events.base_reset(enemy)

			enemy.isVisible = true

			if timers.IsPaused(enemy.m_func) then
				timer.resume(enemy.m_func)
			else
				timer.cancel(enemy.m_func)

				enemy.m_func = timers.PerformWithDelayFromExample(30, enemy.m_func)
			end
		end
	end,

	ready_to_go = function()
		for i = 1, #(Enemies or "") do
			timer.resume(Enemies[i].m_func)
		end
	end
}

TryConfigFunc("add_listeners", events)

for k, v in pairs(events) do
	Runtime:addEventListener(k, v)
end

-- TODO: Bosses too?

_BroadcastEvent_ = M.BroadcastEvent

return M