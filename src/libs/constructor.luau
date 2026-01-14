--[[
	******************************************************************************
	* @file		: .../src/libs/constructor.lua
	* @author	: Cod2rDude
	* @date		: January 12 2026
	* @lastEdit	: January 14 2026 @ 15:40
	* @brief	: Valve constructor
	* @version	: 1.2.0
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
local __log__ 				= require(script.Parent.Parent.__log__.__log__)
local dependecies			= require(script.Parent.Parent.dependecies)
local queues				= dependecies.queues

local types					= require(script.Parent.global.types)
local enums					= require(script.Parent.global.enums)

--// Custom Type Definitions/Declerations
type iValve					= types.valve
type methods				=
	{
		__index				: methods,
		run 				: (self : iValve) -> (),
		stop 				: (self : iValve) -> (),
		enqueue				: (self : iValve, callback : (...any?) -> (...any?), runImmediate : boolean) -> (),
		await				: (self : iValve) -> (),
		awaitAndCall		: (self : iValve, callback : (...any?) -> (...any?)) -> (),
	}

--// Constants
local DEFAULT_MAX_RATE		= 0x20
local DEFAULT_QUEUE_SIZE	= 0x80
local MAX_RATE				= 0x3C
local MAX_QUEUE_SIZE		= 0x200
local MIN_RATE				= 0x1
local MIN_QUEUE_SIZE		= 0x2
local MAX_FALLBACK_TIME		= -0.1

--// Logs
local canOnlyRunWaiting		= 0x5
local cantRunWhenEmpty		= 0x6
local gotRuntimeError		= 0x7
local expectedFunction		= 0x8
local queueIsFull			= 0x9
local cantAwaitStopped		= 0xA
local alreadyStopped		= 0xB
local cantPauseNonRunning	= 0xC
local cantResumeIfNotPaused	= 0xD

--// Functions
function split(success, ...)
	return success, success and table.pack(...) or ...
end

--// Lib Decleration
local constructor			= {}
constructor.__index			= constructor

--// Lib Types
export type valve			= typeof(setmetatable({} :: iValve, {} :: methods))

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
	*	@param self : valve ;; Valve to run.
	*	@param resetDebt : boolean ;; Whatever to reset debt or not.
	*	@param resetOldValues : boolean ;; Whatever to reset old values from previous run.
	@brief Makes @param self start running.
]]
function constructor._run(self : valve, resetDebt : boolean, resetOldValues : boolean)
	if self.state == enums.valveState.running then
		__log__.new(canOnlyRunWaiting, {"Real state:", self.state.name})
		return
	end

	if self.queue:isEmpty() then
		__log__.new(cantRunWhenEmpty, {})
		return
	end

	self.state = enums.valveState.running

	if resetOldValues then
		table.clear(self.outcomes)
		table.clear(self.errors)
	end

	self.debt = resetDebt and 0 or self.debt

	self.runnerThread = task.defer(function()
		local _, __ = xpcall(function()
			while self.queue:size() > 0 and self.state == enums.valveState.running do
				local start = os.clock()
				local callback : () -> () = self.queue:dequeue()

				if typeof(callback) == "function" then 
					local result = processTask(self, callback)
					if not result then break end
				end

				local workDuration = os.clock() - start
				local requiredWait = 1/self.maxRate - workDuration

				self.debt += requiredWait

				if self.debt >= 1/60 then
					task.wait(self.debt)
					self.debt = 0
				elseif self.debt < MAX_FALLBACK_TIME then
					self.debt = 0
					task.wait(0)
				end
			end
		end, function(a0) errorHandler(self, a0) end)

		if self.state ~= enums.valveState.running then return end
		constructor._stop(self)
	end)
end

--[[
	@params
	*	@param self : valve ;; Valve to stop.
	@brief Stops @param self.
]]
function constructor._stop(self : valve)
	if self.state == enums.valveState.waiting then 
		__log__.new(alreadyStopped, {})
		return 
	end

	self.state = enums.valveState.waiting

	local isThisRunner = (self.runnerThread == coroutine.running())

	if self.runnerThread and not isThisRunner then
		xpcall(task.cancel, function() return end, self.runnerThread)
	end

	self.runnerThread = nil

	if next(self.awaitingThreads) == nil then return end

	local copy = table.clone(self.awaitingThreads)
	table.clear(self.awaitingThreads)

	for i : thread, v in pairs(copy) do
		copy[i] = nil
		if coroutine.status(i) ~= "suspended" then continue end
		task.delay(0, i)
	end
end

--[[
	@params
	*	@param self : valve ;; Valve to enqueue a new callback.
	*	@param callback : function ;; Callback to enqueued on @param self 's queue.
	*	@param runImmediate : boolean ;; Whatever if we should start running after enqueueing.
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

	if runImmediate and self.state ~= enums.valveState.running then
		constructor._run(self, true, true)
	end
end

--[[
	@params
	*	@param self : valve ;; Valve to wait for.
	@brief Yields current thread until @param self finishes.
]]
function constructor._await(self : valve)
	if self.state ~= enums.valveState.running then
		__log__.new(cantAwaitStopped, {"Real state:", self.state.name})
		return
	end

	local currentThread = coroutine.running()
	self.awaitingThreads[currentThread] = true
	coroutine.yield()
end

--[[
	@params
	*	@param self : valve ;; Valve to wait for.
	*	@param callback : function ;; Callback to call when @param self finishes.
	*	@param newThread : boolean ;; Whatever to create a new thread to yield or use the current one.
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
	*	@param self : valve ;; Valve to run and wait for.
	@brief Runs @param self and yields current thread until @param self finishes and then returns outcomes.
	@returns
	*	@r1 : {any?} ;; Outcomes of @param self.
	*	@r2 : {any} ;; Errors if there are any.
]]
function constructor._runAndReturnOutcomes(self : valve) : ({any?}, {}?)
	if self.state == enums.valveState.running then
		__log__.new(canOnlyRunWaiting, "From ._runAndReturnOutcomes")
		return {}, {}
	end

	constructor._run(self, true, true)
	constructor._await(self)

	return self.saveOutcomes and self.outcomes or {}, #self.errors ~= 0 and self.errors or {}
end

--[[
	@params
	*	@param self : valve ;; Valve to pause
	*	@param releaseAwaitingThreads : boolean ;; Whatever to stop yielding awaiting threads.
	@brief Pauses @param self, it doesn't reset its outcomes or errors table.
]]
function constructor._pause(self : valve, releaseAwaitingThreads : boolean)
	if self.state ~= enums.valveState.running then
		__log__.new(cantPauseNonRunning, {})
		return
	end

	self.state = enums.valveState.paused

	if not releaseAwaitingThreads or next(self.awaitingThreads) == nil then return end

	local copy = table.clone(self.awaitingThreads)
	table.clear(self.awaitingThreads)

	for i : thread, v in pairs(copy) do
		if coroutine.status(i) ~= "suspended" then continue end
		task.delay(0, i)
	end
end

--[[
	@params
	*	@param self : valve ;; Valve to pause
	*	@param reyieldAwaitingThreads : boolean ;; Whatever to reyield awaiting threads that were 
	*			normally yielded but now running.
	@brief Resumes @param self which is paused.
]]
function constructor._resume(self : valve)
	if self.state ~= enums.valveState.paused then
		__log__.new(cantResumeIfNotPaused, {"Real state:", self.state.name})
		return
	end

	constructor._run(self, false, false)
end

--// Lib Constructor

--[[
	@params
	*	@param maxRate : maxRate ;; Max callbacks per second.
	*	@param queueSize : number ;; How many callbacks can it have once.
	*	@param stopOnError : boolean ;; Whatever if we should stop or not when we got a runtime error.
	*	@param saveOutcomes : boolean ;; Whatever if we should save our not the outcomes of callbacks in queue.
	@brief Creates a new valve.
	@returns
	*	@r1 valve Created valve object.
]]
constructor.new				= function(maxRate : number, queueSize : number, stopOnError : boolean, saveOutcomes : boolean) : valve
	maxRate = typeof(maxRate) == "number" and math.clamp(maxRate, MIN_RATE, MAX_RATE) or DEFAULT_MAX_RATE
	queueSize = typeof(queueSize) == "number" and math.clamp(queueSize, MIN_QUEUE_SIZE, MAX_QUEUE_SIZE) or DEFAULT_QUEUE_SIZE

	local data : iValve 	= {
		maxRate				= maxRate,
		stopOnError			= stopOnError,
		saveOutcomes		= saveOutcomes,
		state				= enums.valveState.waiting,

		queue				= queues.fifo.new(queueSize),
		runnerThread		= nil,
		awaitingThreads		= {},
		outcomes 			= {},
		errors				= {},
		debt				= 0
	}

	local self = setmetatable(data, constructor)

	return self
end

--// Lib Metamethods

--[[
	@brief Makes valve start running.
]]
function constructor:run()
	return constructor._run(self, true, true)
end

--[[
	@brief Stops valve.
]]
function constructor:stop()
	return constructor._stop(self)
end

--[[
	@params
	*	@param callback : function ;; Callback to enqueued on valve's queue.
	*	@param runImmediate : boolean ;; Whatever if we should start running after enqueueing.
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
	*	@param callback : function ;; Callback to call when @param self finishes.
	*	@param newThread : boolean ;; Whatever to create a new thread to yield or use the current one.
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
	*	@r1 : {any?} ;; Outcomes of valve.
	*	@r2 : {any} ;; Errors if there are any.
]]
function constructor:runAndReturnOutcomes() : {any?}
	return constructor._runAndReturnOutcomes(self)
end 

--[[
	@params
	*	@param releaseAwaitingThreads : boolean ;; Whatever to stop yielding awaiting threads.
	@brief Pauses a valve, it doesn't reset its outcomes or errors table.
]]
function constructor:pause(releaseAwaitingThreads : boolean)
	return constructor._pause(self, releaseAwaitingThreads)
end

--[[
	@brief Resumes a paused valve.
]]
function constructor:resume()
	return constructor._resume(self)
end

return constructor