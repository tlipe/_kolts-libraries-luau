--// @O_Kolt \\--

local Players = game:GetService('Players')

local function declare(conexp: true | string) : ()
	if conexp ~= true then error(conexp) end
end

return function(...: (Vector3 | number)) : ()
	local player: Player = Players.LocalPlayer

	local args: {Vector3} = {...}
	local timeout: number? = nil

	if typeof(args[#args]) == 'number' then
		timeout = args[#args]
		args[#args] = nil
	end

	for _, pos: Vector3 in args do
		declare(typeof(pos) == 'Vector3' or 'expected Vector3')
		player:RequestStreamAroundAsync(pos, timeout or 0)
	end
end
