--!optimize 2
--!native

type Resolve<T> = (T) -> ()
type Reject = (any) -> ()

type ThenCallback<T, U> = (T) -> U
type CatchCallback<U> = (any) -> U

export type Promise<T> = {
	Then: <U>(self: Promise<T>, fn: ThenCallback<T, U>) -> Promise<U>,
	Catch: <U>(self: Promise<T>, fn: CatchCallback<U>) -> Promise<U>,
	_isPromise: true
}

export type PromiseModule = {
	all: <T>(list: {Promise<T>}) -> Promise<{T}>,
	__call: <T>(self: PromiseModule, executor: (Resolve<T>, Reject) -> ()) -> Promise<T>
}

local Pending: number = 0
local Fulfilled: number = 1
local Rejected: number = 2

local Promise = {} :: any

local function async(fn)
	task.defer(fn)
end

local function trace(err)
	return debug.traceback(tostring(err), 2)
end

local function exec(fn, ...) : (boolean, any)
	return xpcall(fn, trace, ...)
end

local function create<T>(executor: (Resolve<T>, Reject) -> ()) : Promise<T>
	local state: number = Pending
	local value: any

	local thenQueue = table.create(2)
	local catchQueue = table.create(2)

	local handled: boolean = false

	local function runQueue(queue, v)
		for i = 1, #queue do
			async(function()
				queue[i](v)
			end)
		end
	end

	local function resolve(v: T)
		if state ~= Pending then return end
		state = Fulfilled
		value = v

		runQueue(thenQueue, v)
	end

	local function reject(e: any)
		if state ~= Pending then return end

		state = Rejected
		value = e

		if #catchQueue == 0 then
			async(function()
				if not handled then
					warn(`[Unhandled Promise Rejection]\n{trace(e)}`)
				end
			end)
		end

		runQueue(catchQueue, e)
	end

	async(function()
		local ok: boolean, err: unknown = exec(executor, resolve, reject)
		if not ok then reject(err) end
	end)

	local self = {_isPromise = true}

	function self:Then<U>(fn: ThenCallback<T, U>) : Promise<U>
		return create(function(nextResolve, nextReject)
			local function handle(v: T)
				local ok: boolean, result: unknown = exec(fn, v)
				if not ok then
					nextReject(result)
					return
				end

				local r = result :: any
				if r and r._isPromise then
					(r :: Promise<U>):Then(nextResolve):Catch(nextReject)
					return
				end

				nextResolve(result)
			end

			if state == Fulfilled then
				async(function() handle(value) end)
			elseif state == Rejected then
				nextReject(value)
			else
				thenQueue[#thenQueue+1] = handle
				catchQueue[#catchQueue+1] = nextReject
			end
		end)
	end

	function self:Catch<U>(fn: CatchCallback<U>) : Promise<U>
		handled = true

		return create(function(nextResolve, nextReject)
			local function handle(e)
				local ok, result = exec(fn, e)
				if not ok then
					nextReject(result)
					return
				end

				nextResolve(result)
			end

			if state == Rejected then
				async(function() handle(value) end)
			elseif state == Fulfilled then
				nextResolve(value)
			else
				catchQueue[#catchQueue+1] = handle
				thenQueue[#thenQueue+1] = nextResolve
			end
		end)
	end

	return self
end

function Promise.all<T>(list: {Promise<T>}) : Promise<{T}>
	return create(function(resolve: Resolve<{T}>, reject: Reject)
		local total = #list
		if total == 0 then
			resolve({})
			return
		end

		local results: {any} = table.create(total)
		local remaining: number = total
		local settled: boolean = false

		for i = 1, total do
			list[i]
				:Then(function(v: T)
					if settled then return end
					results[i] = v
					remaining -= 1

					if remaining == 0 then
						settled = true
						resolve(results)
					end
				end)
				:Catch(function(err)
					if settled then return end
					settled = true

					reject(err)
				end)
		end
	end)
end

setmetatable(Promise, {
	__call = function<T>(_, executor: (Resolve<any>, Reject) -> ()) : Promise<T>
		return create(executor)
	end
})

return table.freeze(Promise) :: PromiseModule
