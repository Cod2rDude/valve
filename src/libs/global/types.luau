--// Libs
local dependecies		= require(script.Parent.Parent.Parent.dependecies)
local queues			= dependecies.queues

--// Lib Decleration
local types				= {}

--// Lib Types
export type fifoQueue	= typeof(queues.fifo.new())

export type valve		= 
{
	last				: number,
	maxRate				: number,
	stopOnError			: boolean,
	saveOutcomes		: boolean,
	
	queue				: fifoQueue,
	runnerThread		: thread?,
	awaitingThreads		: {[thread] : boolean?},
	outcomes			: {any?},
	errors				: {any?}
}

return types