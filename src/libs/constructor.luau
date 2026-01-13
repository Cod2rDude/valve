--[[
	******************************************************************************
	* @file		: .../src/libs/constructor.lua
	* @author	: Cod2rDude
	* @date		: January 12 2026
	* @lastEdit	: January 12 2026 @ 16:44
	* @brief	: Valve constructor
	* @version	: 1.0.0
	******************************************************************************
	* @attention
	*
	* Copyright © 2026 Axon Corporation.
	* All rights reserved.
	*
	* This software is licensed under terms that can be found in the LICENSE file
	* in the root directory of this software component.
	* If no LICENSE file comes with this software, it is provided AS-IS.
	*
	******************************************************************************
--]]

--// Libs
local __log__ 			= require(script.Parent.Parent.__log__.__log__)
local dependecies		= require(script.Parent.Parent.dependecies)
local queues			= dependecies.queues

local types				= require(script.Parent.global.types)

--// Custom Type Definitions/Declerations
type iValve				= types.valve
type methods			=
{
	__index				: methods,
	run 				: (self : iValve) -> (),
	stop 				: (self : iValve) -> (),
	enqueue				: (self : iValve, callback : (...any?) -> (...any?), runImmediate : boolean) -> (),
	await				: (self : iValve) -> (),
	awaitAndCall		: (self : iValve, callback : (...any?) -> (...any?)) -> (),
}

--// Constants
local DEFAULT_MAX_RATE	= 0x20
local DEFAULT_QUEUE_SIZE= 0x80
local MAX_RATE			= 0x80
local MAX_QUEUE_SIZE	= 0x200
local MIN_RATE			= 0x1
local MIN_QUEUE_SIZE	= 0x2

--// Logs
local alreadyRunning	= 0x5
local cantRunWhenEmpty	= 0x6
local gotRuntimeError	= 0x7
local expectedFunction	= 0x8
local queueIsFull		= 0x9
local cantAwaitStopped	= 0xA

--// Lib Decleration
local constructor		= {}
constructor.__index		= constructor

--// Lib Types
export type valve		= typeof(setmetatable({} :: iValve, {} :: methods))

--// Lib Public Functions

--[[
	@params
	*	@param self : valve Valve to run.
	@brief Makes @param self start running.
]]
function constructor._run(self : valve)
	if self.runnerThread then
		__log__.new(alreadyRunning, {})
		return
	end

	if self.queue:isEmpty() then
		__log__.new(cantRunWhenEmpty, {})
		return
	end

	table.clear(self.outcomes)

	self.runnerThread = task.defer(function()
		while self.queue:size() > 0 do
			local callback : () -> () = self.queue:dequeue()

			if typeof(callback) == "function" then
				local success, o = xpcall(function() 
					return callback()
				end, function(err) 
					__log__.new(gotRuntimeError, err)
				end)

				if not success then
					if self.stopOnError then break end
				else
					if self.saveOutcomes then self.outcomes[#self.outcomes + 1] = o end
				end
			end

			if not self.queue:isEmpty() then task.wait(1 / self.maxRate) end
		end

		constructor._stop(self)
	end)
end

--[[
	@params
	*	@param self : valve Valve to stop.
	@brief Stops @param self.
]]
function constructor._stop(self : valve)
	local isThisRunner = (self.runnerThread == coroutine.running())

	if self.runnerThread and not isThisRunner then
		xpcall(task.cancel, function() return end, self.runnerThread)
	end

	self.runnerThread = nil

	if self.awaitingThread then
		task.spawn(self.awaitingThread)
		self.awaitingThread = nil
	end
end

--[[
	@params
	*	@param self : valve Valve to enqueue a new callback.
	*	@param callback : function Callback to enqueued on @param self 's queue.
	*	@param runImmediate : boolean Whatever if we should start running after enqueueing.
	@brief Adds a new callback to @param self 's queue.
]]
function constructor._enqueue(self : valve, callback : (...any?) -> (...any?), runImmediate : boolean)
	if typeof(callback) ~= "function" then
		__log__.new(expectedFunction, "Got: "..typeof(callback))
		return
	end

	if self.queue:isFull() then
		__log__.new(queueIsFull, {})
		return
	end

	self.queue:enqueue(callback)

	if runImmediate and not self.runnerThread then
		constructor._run(self)
	end
end

--[[
	@params
	*	@param self : valve Valve to wait for.
	@brief Yields current thread until @param self finishes.
]]
function constructor._await(self : valve)
	if not self.runnerThread then
		__log__.new(cantAwaitStopped, {})
		return
	end

	self.awaitingThread = coroutine.running()
	coroutine.yield()
end

--[[
	@params
	*	@param self : valve Valve to wait for.
	*	@param callback : function Callback to call when @param self finishes.
	@brief Yields current thread until @param self finishes and calls @param callback.
]]
function constructor._awaitAndCall(self : valve, callback : (...any?) -> (...any?))
	constructor._await(self)

	xpcall(callback, function(err) 
		__log__.new(gotRuntimeError, err)
	end)
end

--// Lib Constructor

--[[
	@params
	*	@param maxRate : maxRate Max callbacks per second.
	*	@param queueSize : number How many callbacks can it have once.
	*	@param stopOnError : boolean Whatever if we should stop or not when we got a runtime error.
	*	@param saveOutcomes : boolean Whatever if we should save our not the outcomes of callbacks in queue.
	@brief Creates a new valve.
	@returns
	*	@r1 valve Created valve object.
]]
constructor.new			= function(maxRate : number, queueSize : number, stopOnError : boolean, saveOutcomes : boolean) : valve
	maxRate = typeof(maxRate) == "number" and math.clamp(maxRate, MIN_RATE, MAX_RATE) or DEFAULT_MAX_RATE
	queueSize = typeof(queueSize) == "number" and math.clamp(queueSize, MIN_QUEUE_SIZE, MAX_QUEUE_SIZE) or DEFAULT_QUEUE_SIZE

	local data : iValve = {
		last			= 0,
		maxRate			= maxRate,
		stopOnError		= stopOnError,
		saveOutcomes	= saveOutcomes,

		queue			= queues.fifo.new(queueSize),
		runnerThread	= nil,
		awaitingThread	= nil,
		outcomes 		= {}
	}

	local self = setmetatable(data, constructor)

	return self
end

--// Lib Metamethods

--[[
	@brief Makes valve start running.
]]
function constructor:run()
	return constructor._run(self)
end

--[[
	@brief Stops valve.
]]
function constructor:stop()
	return constructor._stop(self)
end

--[[
	@params
	*	@param callback : function Callback to enqueued on valve's queue.
	*	@param runImmediate : boolean Whatever if we should start running after enqueueing.
	@brief Adds a new callback to valve's queue.
]]
function constructor:enqueue(callback : (...any?) -> (...any?), runImmediate : boolean)
	return constructor._enqueue(self, callback, runImmediate)
end

--[[
	@brief Yields current thread until valve finishes.
]]
function constructor:await()
	return constructor._await(self)
end

--[[
	@params
	*	@param callback : function Callback to call when @param self finishes.
	@brief Yields current thread until valve finishes and calls @param callback.
]]
function constructor:awaitAndCall(callback : (...any?) -> (...any?))
	return constructor._awaitAndCall(self, callback)
end

return constructor
