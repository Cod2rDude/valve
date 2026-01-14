--// Libs
local types				= require(script.Parent.types)

--// Custom Type Definitions
export type enumObject	= types.enumObject

--// Enums
local enums				= {
	valveState			=
	{
		waiting			= {name = "waiting", value = 1} :: enumObject,
		running			= {name = "running", value = 2} :: enumObject,
		paused			= {name = "paused", value = 3} :: enumObject,

		[1]				= "waiting",
		[2]				= "running",
		[3]				= "paused",
	}
}

--// Lib
return enums