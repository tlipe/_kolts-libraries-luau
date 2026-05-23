--!optimize 2
--!strict
--!native

return table.freeze {
	declare = function(conexp: true | string) : ()
		if conexp ~= true then error(conexp) end
	end,

	affirm = function(condition: boolean, message: string?) : ()
		if condition ~= true then error(message or 'assertion failed', 2) end
	end,

	silent = function(condition: boolean) : ()
		if condition ~= true then error() end
	end,
	
	never = function(message: string?) : ()
		error(message or 'this code should never be reached', 2)
	end,
	
	assertType = function(value: any, expectedType: string, message: string?) : ()
		if typeof(value) ~= expectedType then
			error(message or `expected type '{expectedType}', got '{value}'`, 2)
		end
	end,

	unsafe = function(condition: any, message: string?) : ()
		if not condition then error(message or 'assertion failed', 2) end
	end,

	expect = function(actual: any, expected: any, message: string?) : ()
		if actual ~= expected then
			error(message or `expected {expected}, got {actual}`, 2)
		end
	end,
	
	to_do = function(message: string?) : ()
		error(message or 'TODO: not implemented yet', 2)
	end,
}

--[[
	--------------// For copy to use in yours scripts:
	
	--> More fast is 'declare()'.
	
	local function declare(conexp: true | string) : () 
		if conexp ~= true then error(conexp) end
	end


	local function affirm(condition: boolean, message: string?) : ()
		if condition ~= true then error(message or 'assertion failed', 2) end
	end
	

	local function silent(condition: boolean) : ()
		if condition ~= true then error() end
	end
	
	
	local function never(message: string?) : ()
		error(message or 'this code should never be reached', 2)
	end
	
	
	local function assertType(value: any, expectedType: string, message: string?) : ()
		if typeof(value) ~= expectedType then
			error(message or `expected type '{expectedType}', got '{value}'`, 2)
		end
	end


	local function unsafe(condition: any, message: string?) : ()
		if not condition then error(message or 'assertion failed', 2) end
	end


	local function expect(actual: any, expected: any, message: string?) : ()
		if actual ~= expected then
			error(message or `expected {expected}, got {actual}`, 2)
		end
	end

	local function to_do(message: string?) : ()
		error(message or 'TODO: not implemented yet', 2)
	end

	--------------------------------------------------------------
]]
