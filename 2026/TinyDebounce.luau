--!strict
--!native

return function()
	local db: boolean = false

	local function lock() : boolean
		if db then return false end
		db = true

		return true
	end

	local function unlock(delayTime: number) : ()
		task.delay(delayTime, function(): ()
			db = false
		end)
	end

	return {
		lock = lock,
		unlock = unlock
	}
end
