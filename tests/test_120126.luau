--valve/tests/test_120126.luau

--// Services
local replicatedStorage		= game:GetService("ReplicatedStorage")

--// Libs
local valve					= require(replicatedStorage.replicated.packages.valve)

--// Constants
local DEFAULT_RATE			= 20
local DEFAULT_SIZE			= 16

--// Variables
local logTypes				=
{
	["info"]				= " [INFO] ",
	["warning"]				= " [WARNING] ",
	["error"]				= " [ERROR] ",
	["test"]				= " [TEST] "
}

--// Functions
local clk					= os.clock

function addZeroOn(v)
	if v < 10 then return "0"..tostring(v) end
	return v
end

function getDateAndTime()
	local dt			= DateTime.now():ToUniversalTime()

	local day			= addZeroOn(dt.Day)
	local month			= addZeroOn(dt.Month)
	local year			= dt.Year
	local hour			= (dt.Hour + 3)
	local fixedHour		= addZeroOn(hour)
	local minute		= addZeroOn(dt.Minute)
	local second		= addZeroOn(dt.Second)
	local milliSecond	= addZeroOn(dt.Millisecond)

	return day .. "/" .. month .. "/" .. year .. " " .. fixedHour .. ":" .. minute .. ":" .. second .. ":" .. milliSecond
end

function log(id : number, _type : string, text : string, time : boolean)
	local res = tostring(id)

	if logTypes[_type] then res = res .. logTypes[_type] else res = res .. " [UNKNOWN] " end
	if type(text) ~= "string" then text = " " end

	res = res .. text .. " "

	if time then
		res = res .. getDateAndTime()
	end 

	print(res)
end

function test()
	local testCount = 0
	local testsPassed = 0
	local testsFailed = 0

	print(string.rep("=", 32))
	print("Starting test_120126.luau")
	print(string.rep("=", 32))

	do
		log(1 ,"test", "Basic fifo & time & await test.", false)
		testCount += 1

		local myValve = valve.new(DEFAULT_RATE, DEFAULT_SIZE, false, false)

		local expectedTime = (1 / myValve.maxRate) * (myValve.queue.maxItems - 1)

		for i = 1, myValve.queue.maxItems do
			myValve:enqueue(function(...: any?): ...any? 
				log(1 ,"info", string.format("This is %d'th callback.", i), false)
			end, false)
		end

		local startTime = clk()
		myValve:run()
		myValve:awaitAndCall(function(...: any?): ...any? 
			log(1, "info", string.format("Expected to finish in %d seconds", expectedTime), false)
			log(1, "info", string.format("Actually took %d seconds.", clk() - startTime), false)
			log(1, "info", "PASSED", false)
			log(1, "info", "Done.", false)
			testsPassed += 1
		end)

		print(string.rep("=", 32))
	end
	do
		task.wait(2)

		log(2 ,"test", "Capacity test.", false)
		testCount += 1

		local myValve = valve.new(2, 2, false, false)

		for i = 1, 4 do
			myValve:enqueue(function(...: any?): ...any? 
				return 
			end, false)
		end

		log(2, "info", "There should be only 2 items in valve", false)
		log(2, "info", string.format("Actually there is %d items in valve", myValve.queue:size()), false)

		if myValve.queue:size() == 2 then
			log(2, "info", "PASSED", false)
			testsPassed += 1
			
			myValve:run() 
			myValve:await()
		else
			log(2, "error", "FAILED", false)
			testsFailed += 1
		end
		log(2, "info", "Done", false)

		print(string.rep("=", 32))
	end
	do
		task.wait(2)

		log(3, "test", "Error Resilience Test", false)
		testCount += 1
		
		local safeValve = valve.new(20, 10, false, false)
		local survived = false

		safeValve:enqueue(function()
			log(3, "warning", "A, Im going to crash.", false)
			error("Intentional Crash")
		end, true)

		safeValve:enqueue(function()
			survived = true
			log(3, "info", "B, ran.", false)
		end, true)

		safeValve:await()

		if survived then
			log(3, "info", "PASSED", false)
			testsPassed += 1
		else
			log(3, "error", "FAILED)", false)
			testsFailed += 1
		end
		log(3, "info", "Done", false)

		print(string.rep("=", 32))
	end
	do
		task.wait(2)
		log(4, "test", "Emergency Stop Test", false)
		testCount += 1

		local stopValve = valve.new(2, 10, false, false)
		local count = 0

		stopValve:enqueue(function() count += 1 end, true) -- 0.0s
		stopValve:enqueue(function() count += 1 end, true) -- 0.5s
		stopValve:enqueue(function() count += 1 end, true) -- 1.0s

		task.delay(0.7, function()
			log(4, "warning", "STOPPING VALVE", false)
			stopValve:stop()
		end)

		task.wait(2)

		log(4, "info", string.format("Tasks ran: %d (Expected: 2)", count), false)

		if count == 2 then
			log(4, "info", "PASSED", false)
			testsPassed += 1
		else
			log(4, "error", "FAILED", false)
			testsFailed += 1
		end
		log(4, "info", "Done", false)
	end

	task.wait(1)
	print(string.rep("=", 32))
	print(string.format("%d/%d TESTS PASSED", testsPassed, testCount))
	print(string.rep("=", 32))
end

--// Test
test()