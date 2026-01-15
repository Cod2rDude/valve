return {
	[0x1] = {
		type = "warning";
		message = {
			[1] = "Logger";
			[2] = "Can not find message in given id. Please check if given index is valid.";
		};
	};
	[0x2] = {
		type = "warning";
		message = {
			[1] = "Logger";
			[2] = "Given message partition is not a string.";
		};
	};
	[0x3] = {
		type = "warning";
		message = {
			[1] = "Logger";
			[2] = "Message is empty.";
		};
	};
	[0x4] = {
		type = "warning";
		message = {
			[1] = "Logger";
			[2] = "While given message is an error, it does not include a level. Did you forget it?";
		};
	};
	[0x5] = {
		type = "warning";
		message = {
			[1] = "Can only run when in waiting state.";
		};
	};
	[0x6] = {
		type = "warning";
		message = {
			[1] = "Can't run when queue is empty.";
		};
	};
	[0x7] = {
		type = "warning";
		message = {
			[1] = "Got runtime error.";
		};
	};
	[0x8] = {
		type = "warning";
		message = {
			[1] = "Expected a function to enqueue.";
		};
	};
	[0x9] = {
		type = "warning";
		message = {
			[1] = "Can't add anything when queue is full.";
		};
	};
	[0xA] = {
		type = "warning";
		message = {
			[1] = "Can't await when valve is stopped.";
		};
	};
	[0xB] = {
		type = "warning";
		message = {
			[1] = "Valve is already stopped.";
		};
	};
	[0xC] = {
		type = "warning";
		message = {
			[1] = "Can not pause a valve that doesn't run.";
		};
	};
	[0xD] = {
		type = "warning";
		message = {
			[1] = "Can not resumea  valve that isn't paused.";
		};
	};
}