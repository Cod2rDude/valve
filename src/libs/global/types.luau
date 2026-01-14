--// Libs
local dependecies		= require(script.Parent.Parent.Parent.dependecies)
local queues			= dependecies.queues

--// Lib Decleration
local types				= {}

--// Lib Types
export type enumObject	= {value : number, name : string}

export type fifoQueue	= typeof(queues.fifo.new())

export type valve		= 
{
	maxRate				: number,
	stopOnError			: boolean,
	saveOutcomes		: boolean,
	state				: enumObject,
	
	queue				: fifoQueue,
	runnerThread		: thread?,
	awaitingThreads		: {[thread] : boolean?},
	outcomes			: {any?},
	errors				: {any?},
	debt				: number
}

return types