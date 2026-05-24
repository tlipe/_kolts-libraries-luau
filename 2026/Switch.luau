--!strict
--!native

--// @O_Kolt \\--

export type Switch = {
	case: (self: Switch, key: any, fn: (...any) -> any) -> Switch,
	default: (self: Switch, fn: (...any) -> any, ...any) -> any,
}

local function declare(conexp: true | string) : () 
	if conexp ~= true then error(conexp) end
end

return function(key: any)
	declare(key ~= nil or "Switch: key is required")

	local self = {}
	local cases: {[any]: (...any) -> any} = {}

	function self:case(k: any, fn: (...any) -> any) : Switch
		if k ~= nil and fn ~= nil then cases[k] = fn end
		return self
	end

	function self:default(fn: (...any) -> any, ...: any) : any
		local selected = cases[key] or fn
		if not selected then return nil end

		return selected(...)
	end

	return self :: Switch
end
