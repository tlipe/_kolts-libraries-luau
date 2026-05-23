--!optimize 2
--!native

--// @O_Kolt \\--

local Match = {}
Match.__index = Match

export type PredicateCase<T, R> = {
	predicate: (value: T) -> boolean,
	handler: (...any) -> R,
	priority: number
}

export type MatchConfig = {
	cacheSize: number?,
	enableCache: boolean?,
	predicateLimit: number?,
}

export type Match<T, K, R> = {
	_value: T,
	_cases: {[K]: (...any) -> R},
	_predicates: {PredicateCase<T, R>},
	_default: ((...any) -> R)?,

	_cache: {[string]: R}?,
	_cacheSize: number,
	_cacheCount: number,

	_config: MatchConfig,
	_compiled: boolean,

	case: (self: Match<T, K, R>, key: K | ((value: any) -> boolean), fn: (...any) -> R, priority: number?) -> Match<T, K, R>,
	default: (self: Match<T, K, R>, fn: (...any) -> R) -> Match<T, K, R>,
	run: (self: Match<T, K, R>) -> ((...any) -> R)?,
	execute: (self: Match<T, K, R>, ...any) -> R?,
	compile: (self: Match<T, K, R>) -> Match<T, K, R>,
	clear: (self: Match<T, K, R>) -> Match<T, K, R>,
	batch: (self: Match<T, K, R>, cases: {[K]: (...any) -> R}) -> Match<T, K, R>,
}

export type MatchModule = {
	match: <T>(value: T, config: MatchConfig?) -> Match<T, any, any>,
	cached: <T>(value: T) -> Match<T, any, any>,
	simple: <T>(value: T) -> Match<T, any, any>,
} & (<T>(value: T, useCache: boolean?) -> Match<T, any, any>)

local function getCacheKey(value: any, ...: any) : string
	local key = tostring(value)
	local n = select("#", ...)

	if n == 0 then
		return key
	end

	for i = 1, n do
		local arg = select(i, ...)
		key = `{key}:{tostring(arg)}`
	end

	return key
end

function Match:case<K, R>(
	key: K | ((value: any) -> boolean),
	fn: (...any) -> R,
	priority: number?
)
	if typeof(fn) ~= "function" then
		error("Match.case: handler must be a function")
	end

	if typeof(key) == "function" then
		local pred = key :: (any) -> boolean

		local predCase: PredicateCase<any, R> = {
			predicate = pred,
			handler = fn,
			priority = priority or (#self._predicates + 1),
		}

		self._predicates[#self._predicates + 1] = predCase

		if self._config.predicateLimit and #self._predicates > self._config.predicateLimit then
			warn(`Match: High predicate count ({#self._predicates})`)
		end
	else
		if key == nil then
			error("Match.case: key cannot be nil")
		end

		rawset(self._cases, key, fn)
	end

	self._compiled = false
	return self
end

function Match:default<R>(fn: (...any) -> R)
	if typeof(fn) ~= "function" then
		error("Match.default: fn must be a function")
	end

	self._default = fn
	return self
end

function Match:batch(cases: {[any]: (...any) -> any})
	for key, handler in cases do
		if key ~= nil and typeof(handler) == "function" then
			rawset(self._cases, key, handler)
		end
	end

	self._compiled = false
	return self
end

function Match:compile()
	if self._compiled then
		return self
	end

	if #self._predicates > 1 then
		table.sort(self._predicates, function(a, b)
			return a.priority < b.priority
		end)
	end

	self._compiled = true
	return self
end

function Match:run()
	local literalFn = rawget(self._cases, self._value)
	if literalFn then return literalFn end

	local predicateCount = #self._predicates

	if predicateCount > 0 then
		if not self._compiled then
			self:compile()
		end

		for i = 1, predicateCount do
			local p = self._predicates[i]
			if p.predicate(self._value) then
				return p.handler
			end
		end
	end

	return self._default
end

function Match:execute<R>(...: any) : R?
	local fn = self:run()
	if not fn then return nil end

	local hasArgs = select("#", ...) > 0

	local cache = self._cache
	local cacheKey: string?

	if cache then
		cacheKey = hasArgs and getCacheKey(self._value, ...) or getCacheKey(self._value)

		local cached = cache[cacheKey]
		if cached ~= nil then return cached end
	end

	local result: R?

	if hasArgs then
		result = (fn :: (...any) -> R)(...)
	else
		result = (fn :: (...any) -> R)(self._value)
	end

	if cache and cacheKey then
		cache[cacheKey] = result
		self._cacheCount += 1

		if self._cacheCount >= self._cacheSize then
			local removed = 0
			local target = math.floor(self._cacheSize / 2)

			for k in cache do
				cache[k] = nil
				removed += 1
				if removed >= target then break end
			end

			self._cacheCount -= removed
			if self._cacheCount < 0 then
				self._cacheCount = 0
			end
		end
	end

	return result
end

function Match:clear()
	if self._cache then
		table.clear(self._cache)
		self._cacheCount = 0
	end

	self._compiled = false
	return self
end

local function createMatch<T>(value: T, config: MatchConfig?)
	local finalConfig: MatchConfig = config or {}

	local enableCache = finalConfig.enableCache == true
	local cacheSize = finalConfig.cacheSize or 256
	local predicateLimit = finalConfig.predicateLimit or 50

	local self = {
		_value = value,
		_cases = {},
		_predicates = {},
		_default = nil,

		_cache = enableCache and {} or nil,
		_cacheSize = enableCache and cacheSize or 0,
		_cacheCount = 0,

		_config = {
			enableCache = enableCache,
			cacheSize = cacheSize,
			predicateLimit = predicateLimit,
		},

		_compiled = false,
	}

	return setmetatable(self, Match)
end

local MatchModule = {
	match = createMatch,

	cached = function<T>(value: T)
		return createMatch(value, {
			enableCache = true,
			cacheSize = 128,
		})
	end,

	simple = function<T>(value: T)
		return createMatch(value, {
			enableCache = false,
			predicateLimit = 10,
		})
	end,
}

setmetatable(MatchModule, {
	__call = function(_, value: any, useCache: boolean?)
		local enableCache = useCache == true

		return createMatch(value, {
			enableCache = enableCache,
			cacheSize = enableCache and 64 or 0,
		})
	end,
})

return table.freeze(MatchModule) :: MatchModule
