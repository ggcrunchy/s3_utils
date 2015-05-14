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
local remove = table.remove
local require = require
local sin = math.sin

-- Modules --
local require_ex = require("tektite_core.require_ex")
local adaptive = require("tektite_core.table.adaptive")
local bind = require("tektite_core.bind")
local collision = require("corona_utils.collision")
local enemy_events = require("annex.EnemyEvents")
local flow_ops = require("coroutine_ops.flow")
local movement = require("s3_utils.movement")
local tile_maps = require("s3_utils.tile_maps")
local wrapper = require("coroutine_ops.wrapper")

-- Corona globals --
local display = display
local Runtime = Runtime

-- Cached module references --
local _AlertEnemies_

-- Exports --
local M = {}

-- Phase-in period --
local PeriodTime = 1.15

-- Phasing time coefficient --
local PhaseFactor = 2 * pi / PeriodTime

-- Phase-in effect on spawning enemy
local function PhaseSpawning (t, _, enemy)
	enemy.alpha = abs(sin(PhaseFactor * t.time))
end

-- Behavior of an enemy after (re)spawning and while waiting to become alive
local function PhaseIn (enemy, type_info, info, is_sleeping)
	--
	enemy.m_facing = info.facing
	enemy.m_pref_turn, enemy.m_alt_turn = movement.Turns(not info.prefers_left)

	--
	local x, y = enemy.m_start:localToContent(0, 0)

	enemy.x, enemy.y = enemy.parent:contentToLocal(x, y)

	enemy.m_tile = tile_maps.GetTileIndex_XY(enemy.x, enemy.y)

	--
	if type_info.Start then
		type_info.Start(enemy)
	end

	--
	enemy.m_ready = not is_sleeping

	flow_ops.WaitForSignal(enemy, "m_ready")

	--
	collision.SetVisibility(enemy, false)

	--
	enemy.isVisible = true

	flow_ops.Wait(type_info.spawn_time, PhaseSpawning, enemy)

	enemy.alpha = 1
end

-- Common logic to apply when an enemy is killed
local function Kill (enemy, other)
	if enemy.m_alive then
		enemy.m_alive = false

		collision.SetVisibility(enemy, false)

		enemy_events.on_kill(enemy, other)
	end
end

-- Events an enemy can trigger --
local Events = {}

-- Behavior of an enemy between phasing in and being killed
local function Alive (enemy, type_info)
	--
	Events.on_wake(enemy, "fire", false)

	-- Make sure the enemy is visible and alive, i.e. able to hurt you and be hurt itself.
	-- Account for enemies that were phasing in when the dots got cleared.
	enemy.m_alive = not enemy.m_no_respawn

	--
	if enemy.m_alive then
		collision.SetVisibility(enemy, true)
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
	Events.on_die(enemy, "fire", false)

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
local function EnemyFunc (enemy, type_info, info)
	collision.MakeSensor(enemy, "dynamic", type_info.body)
	collision.SetType(enemy, "enemy")

	enemy.isVisible = false

	local is_sleeping = info.asleep

	while true do
		PhaseIn(enemy, type_info, info, is_sleeping)
		Alive(enemy, type_info)
		Die(enemy, type_info)

		is_sleeping = info.sleep_on_death

		if enemy.m_no_respawn then
			return "done"
		else
			WaitToRespawn(enemy, type_info)
		end
	end
end

-- Enemy behavior coroutines; enemy objects --
local Coros, Enemies

-- Omit the "self" enemy (in the relevant case, passed as "arg") when sending an alert? --
local OmitArg

--- Sends an alert to the enemies in the level, which can respond in their **ReactTo** method,
-- cf. @{SpawnEnemy}.
-- @string what Name of alert, passed to **ReactTo**.
-- @param arg Alert argument, also passed to **ReactTo**.
-- @string how If this is **"all"**, all enemies are sent the alert. If it is **"dead"**,
-- only dead enemies are alerted. Otherwise, only live enemies are alerted.
function M.AlertEnemies (what, arg, how)
	local live_value, omit

	-- Filter out alert recipients: an enemy alerting others must not alert itself, and
	-- otherwise screen passed on who is or is not alive. The "omit self" flag is consumed
	-- immediately, so clean it up in order to not confused subsequent alerts.
	omit, OmitArg = OmitArg and arg

	if how ~= "all" then
		live_value = how ~= "dead"
	end

	-- Send the alert to all valid recipients.
	for _, enemy in ipairs(Enemies) do
		if enemy ~= omit and live_value ~= not enemy.m_alive then
			enemy:ReactTo(what, arg)
		end
	end
end

-- Enemy type lookup table --
local EnemyList

-- Enemy actions that can be triggered --
local Actions = {
	-- Do Kill --
	do_kill = function(enemy)
		return function(what)
			-- Fire --
			if what == "fire" then
				Kill(enemy)

			-- Is Done? --
			elseif what == "is_done" then
				return true
			end
		end
	end,

	-- Do Wake --
	do_wake = function(enemy)
		return function(what)
			-- Fire --
			if what == "fire" then
				enemy.m_ready = true

			-- Is Done? --
			elseif what == "is_done" then
				return true
			end
		end
	end
}

--
local function LinkEnemy (enemy, other, esub, osub)
	bind.LinkActionsAndEvents(enemy, other, esub, osub, Events, Actions, "actions")
end

--- Handler for enemy-related events sent by the editor.
-- @string type Enemy type, as listed by @{GetTypes}.
-- @string what Name of event.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return Result of the event, if any.
function M.EditorEvent (type, what, arg1, arg2, arg3)
	local type_info = EnemyList[type]

	if type_info and type_info.EditorEvent then
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
		-- arg2: Representative object
		elseif what == "enum_props" then
			arg1:StockElements("Enemy", type)
			arg1:AddSeparator()
			arg1:AddCheckbox{ text = "Asleep By Default?", value_name = "asleep" }
			arg1:AddCheckbox{ text = "Fall Asleep If Killed?", value_name = "sleep_on_death" }
			arg1:AddCheckbox{ text = "Can Attach To Event Block?", value_name = "can_attach" }
			arg1:AddLink{ text = "Event links: On(die)", rep = arg2, sub = "on_die", interfaces = "event_target" }
			arg1:AddLink{ text = "Event links: On(wake)", rep = arg2, sub = "on_wake", interfaces = "event_target" }
			arg1:AddLink{ text = "Action links: Do(kill)", rep = arg2, sub = "do_kill", interfaces = "event_source" }
			arg1:AddLink{ text = "Action links: Do(wake)", rep = arg2, sub = "do_wake", interfaces = "event_source" }
			arg1:AddSeparator()

		-- Get Tag --
		elseif what == "get_tag" then
			return "enemy"

		-- New Tag --
		elseif what == "new_tag" then
			return "sources_and_targets", Events, Actions

		-- Prep Link --
		elseif what == "prep_link" then
			return LinkEnemy

		-- Verify --
		elseif what == "verify" then
			-- COMMON STUFF... nothing yet, I don't think, assuming well-formed editor
		end

		return type_info.EditorEvent(what, arg1, arg2, arg3)
	end
end

--- Getter.
-- @treturn {string,...} Unordered list of enemy type names.
function M.GetTypes ()
	local types = {}

	for k in pairs(EnemyList) do
		types[#types + 1] = k
	end

	return types
end

--- Kill all enemies on demand.
function M.KillAll ()
	for _, enemy in ipairs(Enemies) do
		Kill(enemy)
	end
end

-- Enemy alert method
local function AlertOthers (enemy, what, how)
	OmitArg = true

	_AlertEnemies_(what, enemy, how)
end

-- Dummy for reaction-less enemies --
local NoOp = function() end

-- Enemy situation <-> events bindings --
for _, v in ipairs{ "on_die", "on_wake" } do
	Events[v] = bind.BroadcastBuilder_Helper("loading_level")
end

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
-- A _result_ of **"dead"** will put _enemy_ into the killed state; if _other_ is non-**nil**,
-- it is assumed to be a physics object, its `getLinearVelocity` method is called, and the
-- results are assigned to _enemy_'s **m_vx** and **m_vy** fields.
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
-- * **ReactTo**: Function that takes _enemy_, _what_, and _arg_ as arguments, allowing the
-- enemy to react to various events.
--
-- * **Start**: Function used to prepare the enemy before it begins to phase in, called with
-- _enemy_ as argument.
--
-- **Do**, **Die**, and **Start** are each called within a coroutine context.
--
-- In order to generate the display object, _enemy_, one of the following must be provided:
--
-- * **image**: A filename, as per `display.newImage`.
-- * **sprite_factory**: A factory returned by @{corona_utils.sheet.NewSpriteFactory}.
-- @pgroup group Display group that will hold the enemy.
-- @ptable info Information about the new enemy. Required fields:
--
-- * **col**: Column on which enemy spawns.
-- * **row**: Row on which enemy spawns.
-- * **type**: Name of enemy type, q.v. _name_, above.
--
-- Optional elements include:
--
-- * **facing**: Direction enemy faces when it spawns.
-- * **prefers_left**: If true, the enemy prefers left turns, when available; otherwise,
-- it prefers right turns.
--
-- Instance-specific data may also be passed in other fields.
-- @see s3_utils.movement.NextDirection
function M.SpawnEnemy (group, info)
	local type_info = EnemyList[info.type]

	-- Make the enemy display object.
	local enemy

	if type_info.sprite_factory then
		enemy = type_info.sprite_factory:NewSprite(group)
	elseif type_info.image then
		enemy = display.newImage(group, type_info.image)	
	end

	enemy.ReactTo = type_info.ReactTo or NoOp

	Enemies[#Enemies + 1] = enemy

	--
	for k, event in pairs(Events) do
		event.Subscribe(enemy, info[k])
	end

	--
	for k in adaptive.IterSet(info.actions) do
		bind.Publish("loading_level", Actions[k](enemy), info.uid, k)
	end

	--- Allows an enemy to send an alert to other enemies.
	-- @function enemy:AlertOthers
	-- @string what Name of alert, passed to **ReactTo**.
	-- @string how As per @{AlertEnemies}, except the enemy itself is excluded as well.
	enemy.AlertOthers = AlertOthers

	-- Perform any create-time response.
	enemy:ReactTo("create")

	-- Find the start tile to (re)spawn the enemy there, and kick off its behavior. Unless
	-- fixed, this starting position may attach to an event block and be moved around.
	enemy.m_start = display.newCircle(group, 0, 0, 5)

	enemy.m_start.isVisible = false

	tile_maps.PutObjectAt(tile_maps.GetTileIndex(info.col, info.row), enemy.m_start)

	enemy.m_can_attach = not type_info.fixed

	local coro = wrapper.Wrap(function()
		return EnemyFunc(enemy, type_info, info)
	end)

	coro()

	Coros[#Coros + 1] = coro
end

--
local function TryConfigFunc (key, arg)
	local func = enemy_events[key]

	return func and func({
		alert_enemies = M.AlertEnemies, kill = Kill,

		-- Helper for getting hit by harmful things
		die_or_react = function(enemy, what, object)
			if not enemy:ReactTo(what, object) then
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

-- Add enemy-OBJECT collision handler.
collision.AddHandler("enemy", function(phase, enemy, other, other_type)
	-- Enemy touched enemy: delegate reaction to enemy.
	if other_type == "enemy" then
		enemy:ReactTo("touched_enemy", other, phase == "began")
	elseif OnCollision then
		OnCollision(phase, enemy, other, other_type)
	end
end)

-- ^^ Make these configable (with all args, DieOrReact)

-- Define enemy properties.
collision.AddInterfaces("enemy", "harmable")

-- Per-frame setup / update
local function OnEnterFrame ()
	for i = #Coros, 1, -1 do
		local coro = Coros[i]

		if wrapper.Status(coro) == "dead" or coro() == "done" then
			remove(Coros, i)
		end
	end
end

-- Listen to events.
local events = {
	-- Enter Level --
	enter_level = function()
		Coros, Enemies = {}, {}
	end,

	-- Event Block Setup --
	event_block_setup = function(event)
		local block = event.block

		for _, enemy in ipairs(Enemies) do
			if enemy.m_can_attach then
				local col, row = tile_maps.GetCell(enemy.m_tile)
				local cmin, cmax = block:GetColumns()
				local rmin, rmax = block:GetRows()

				if col >= cmin and col <= cmax and row >= rmin and row <= rmax then
					block:GetGroup():insert(enemy.m_start)

					enemy.m_can_attach = false
				end
			end
		end
	end,

	-- Leave Level --
	leave_level = function()
		_AlertEnemies_("about_to_leave")

		Coros, Enemies = nil

		Runtime:removeEventListener("enterFrame", OnEnterFrame)
	end,

	-- Reset Level --
	reset_level = function()
		_AlertEnemies_("about_to_reset")

		for i, enemy in ipairs(Enemies) do
			enemy.m_alive = false

			enemy_events.base_reset(enemy)

			enemy.isVisible = true

			local coro = Coros[i]

			if coro then
				wrapper.Reset(coro)
			end
		end
	end,

	-- Things Loaded --
	things_loaded = function()
		Runtime:addEventListener("enterFrame", OnEnterFrame)
	end
}

TryConfigFunc("add_listeners", events)

for k, v in pairs(events) do
	Runtime:addEventListener(k, v)
end

-- Install various types of enemies.
EnemyList = require_ex.DoList("config.Enemies")

-- TODO: Bosses too?

-- Cache module members.
_AlertEnemies_ = M.AlertEnemies

-- Export the module.
return M