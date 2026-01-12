--// Services
local replicatedStorage	= game:GetService("ReplicatedStorage")

--// Libs
local _queues			= require(replicatedStorage.replicated.packages.queues)

--// Custom Type Definitions/Declerations
export type dependecies =
{
	queues 				: typeof(_queues),
}

return {
	queues				= _queues
} :: dependecies