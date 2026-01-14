--[[
	******************************************************************************
	* @file		: .../src/libs/constructor.lua
	* @author	: Cod2rDude
	* @date		: January 12 2026
	* @lastEdit	: January 14 2026 @ 10:31
	* @brief	: Valve constructor
	* @version	: 1.1.0
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
local MAX_RATE			= 0x3C
local MAX_QUEUE_SIZE	= 0x200
local MIN_RATE			= 0x1
local MIN_QUEUE_SIZE	= 0x2
local MAX_FALLBACK_TIME	= -0.1

--// Logs
local alreadyRunning	= 0x5
local cantRunWhenEmpty	= 0x6
local gotRuntimeError	= 0x7
local expectedFunction	= 0x8
local queueIsFull		= 0x9
local cantAwaitStopped	= 0xA

--// Functions
function split(success, ...)
	return success, success and table.pack(...) or ...
end

--// Lib Decleration
local constructor		= {}
constructor.__index		= constructor

--// Lib Types
export type valve		= typeof(setmetatable({} :: iValve, {} :: methods))

--// Lib Private Functions
function errorHandler(self : valve, err : any)
	self.errors[#self.errors + 1] = err
	__log__.new(gotRuntimeError, err)
end

function processTask(self : valve, callback : () -> ())
	if not self.saveOutcomes then
		local success = xpcall(callback, function(a0) errorHandler(self, a0) end)
		if not success and self.stopOnError then return false end
	else
		local success, results = split(xpcall(callback, function(a0) errorHandler(self, a0) end))

		if not success then
			if self.stopOnError then return false end
		else
			self.outcomes[#self.outcomes + 1] = results
		end
	end

	return true
end

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
	table.clear(self.errors)

	self.runnerThread = task.defer(function()
		local _, __ = xpcall(function()
			local debt = 0

			while self.queue:size() > 0 do
				local start = os.clock()
				local callback : () -> () = self.queue:dequeue()

				if typeof(callback) == "function" then 
					local result = processTask(self, callback)
					if not result then break end
				end

				local workDuration = os.clock() - start
				local requiredWait = 1/self.maxRate - workDuration

				debt += requiredWait

				if debt >= 1/60 then
					task.wait(debt)
					debt = 0
				elseif debt < MAX_FALLBACK_TIME then
					debt = 0
					task.wait(0)
				end
			end
		end, function(a0) errorHandler(self, a0) end)

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

	if next(self.awaitingThreads) ~= nil then
		local copy = table.clone(self.awaitingThreads)
		table.clear(self.awaitingThreads)

		for i : thread, v in pairs(copy) do
			copy[i] = nil

			if coroutine.status(i) == "suspended" then
				task.delay(0, i)
			end
		end
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

	local currentThread = coroutine.running()
	self.awaitingThreads[currentThread] = true
	coroutine.yield()
end

--[[
	@params
	*	@param self : valve Valve to wait for.
	*	@param callback : function Callback to call when @param self finishes.
	*	@param newThread : boolean Whatever to create a new thread to yield or use the current one.
	@brief If @param newThread is set to true it will create a new thread and
	*		yield it until @param self finishes and then call @param callback.
	*		If @param newThread is false it will yield the thread that called this function 
	*		and then call @param callback when @param self finishes. 
]]
function constructor._awaitAndCall(self : valve, callback : (...any?) -> (...any?), newThread : boolean)
	local function handler()
		constructor._await(self)

		xpcall(callback, function(err) 
			__log__.new(gotRuntimeError, err)
		end)
	end

	if newThread then
		task.spawn(handler)
		return
	end

	handler()
end

--[[
	@params
	*	@param self : valve Valve to run and wait for.
	@brief Runs @param self and yields current thread until @param self finishes and then returns outcomes.
	@returns
	*	@r1 : {any?} Outcomes of @param self.
]]
function constructor._runAndReturnOutcomes(self : valve) : {any?}
	if self.runnerThread then
		__log__.new(alreadyRunning, "From ._runAndReturnOutcomes")
		return {}
	end

	constructor._run(self)
	constructor._await(self)

	return self.saveOutcomes and self.outcomes or {}
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
		awaitingThreads	= {},
		outcomes 		= {},
		errors			= {}
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
	*	@param newThread : boolean Whatever to create a new thread to yield or use the current one.
	@brief If @param newThread is set to true it will create a new thread and
	*		yield it until @param self finishes and then call @param callback.
	*		If @param newThread is false it will yield the thread that called this function 
	*		and then call @param callback when @param self finishes. 
]]
function constructor:awaitAndCall(callback : (...any?) -> (...any?), newThread : boolean)
	return constructor._awaitAndCall(self, callback, newThread)
end

--[[
	@brief Runs valve and yields current thread until valve finishes and then returns outcomes.
	@returns
	*	@r1 : {any?} Outcomes of valve.
]]
function constructor:runAndReturnOutcomes() : {any?}
	return constructor._runAndReturnOutcomes(self)
end 

return constructor