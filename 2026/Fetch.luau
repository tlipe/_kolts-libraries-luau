--!native
--!optimize 2

local HttpService = game:GetService('HttpService')

type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH' | 'HEAD'

type CancelToken = {Cancelled: boolean, _listeners: {() -> ()}}

type FetchOptions = {
	Method: HttpMethod?,
	Headers: {[string]: string}?,
	Body: any?,

	Retry: number?,
	RetryDelay: number?,

	Timeout: number?,

	CancelToken: CancelToken?,
	Debug: boolean?
}

type FetchResponse = {
	Ok: boolean,

	Status: number,
	StatusText: string,

	Headers: {[string]: string},
	BodyUsed: boolean,

	Text: () -> (string?, string?),
	Json: () -> (any?, string?)
}

local allowed: {[string]: boolean} = {
	GET = true, POST = true, PUT = true,
	DELETE = true, PATCH = true, HEAD = true
}

local function onCancel(token: CancelToken, fn: () -> ())
	if token.Cancelled then fn() return end
	table.insert(token._listeners, fn)
end

local function normalize(h: {[string]: string}?) : {[string]: string}
	if not h then return {} end

	local out: {[string]: string} = {}
	for k, v in h do
		out[string.lower(k)] = v
	end

	return out
end

local function delayCancelable(sec: number, token: CancelToken?) : boolean
	if sec <= 0 then return true end

	local thread = coroutine.running()
	local done = false

	local function resolve(v: boolean)
		if done then return end
		done = true

		task.spawn(thread, v)
	end

	task.delay(sec, function() resolve(true) end)

	if token then
		onCancel(token, function() resolve(false) end)
	end

	return coroutine.yield()
end

local function requestOnce(
	url: string,
	method: HttpMethod,
	headers: {[string]: string},
	body: any,
	timeout: number?,
	token: CancelToken?
) : (boolean, any?, string?)

	local thread = coroutine.running()
	local finished = false

	local function resolve(ok: boolean, res: any?, err: string?)
		if finished then return end
		finished = true
		task.spawn(thread, ok, res, err)
	end

	task.spawn(function()
		if token and token.Cancelled then
			resolve(false, nil, 'cancelled')
			return
		end

		local ok, res = pcall(HttpService.RequestAsync, HttpService, {
			Url = url,
			Method = method,
			Headers = headers,
			Body = body
		})

		if not ok then
			resolve(false, nil, tostring(res))
			return
		end

		resolve(true, res, nil)
	end)

	if timeout then
		task.delay(timeout, function()
			resolve(false, nil, 'timeout')
		end)
	end

	if token then
		onCancel(token, function()
			resolve(false, nil, 'cancelled')
		end)
	end

	return coroutine.yield()
end

return function(resourcePath: string, options: FetchOptions?) : FetchResponse
	if resourcePath == '' then
		error('FetchError: empty URL')
	end

	local method: HttpMethod = options and options.Method or 'GET'
	if not allowed[method] then
		error(`FetchError: invalid method {method}`)
	end

	local headers = normalize(options and options.Headers)
	local body = options and options.Body or nil

	if typeof(body) == 'table' then
		body = HttpService:JSONEncode(body)
		headers['content-type'] = headers['content-type'] or 'application/json'
	end

	local retries = math.max(0, options and options.Retry or 0)
	local baseDelay = options and options.RetryDelay or 0.5
	local timeout = options and options.Timeout

	local token = options and options.CancelToken
	local debug = options and options.Debug

	local response: any = nil
	local networkErr: string? = nil

	for attempt = 0, retries do
		if token and token.Cancelled then
			networkErr = 'cancelled'
			break
		end

		local ok, res, err = requestOnce(resourcePath, method, headers, body, timeout, token)

		if ok then
			response = res
			break
		end

		networkErr = err

		if attempt < retries then
			local delay = baseDelay * (2 ^ attempt)

			if not delayCancelable(delay, token) then
				networkErr = 'cancelled'
				break
			end
		end
	end

	if not response then
		return {
			Ok = false,
			Status = 0,
			StatusText = networkErr or 'network error',
			Headers = {},
			BodyUsed = false,

			Text = function() return nil, networkErr or 'network error' end,
			Json = function() return nil, networkErr or 'network error' end
		}
	end

	local respHeaders = normalize(response.Headers)
	local used = false

	local function consume(): (string?, string?)
		if used then
			return nil, 'body already used'
		end

		used = true
		return response.Body, nil
	end

	local fetchResponse: FetchResponse = {
		Ok = response.StatusCode >= 200 and response.StatusCode < 300,

		Status = response.StatusCode,
		StatusText = response.StatusMessage or tostring(response.StatusCode),

		Headers = respHeaders,
		BodyUsed = used,

		Text = function()
			local data, err = consume()
			fetchResponse.BodyUsed = used

			return data, err
		end,

		Json = function()
			local raw, err = consume()
			fetchResponse.BodyUsed = used

			if not raw then
				return nil, err
			end

			if raw == '' then
				return nil, 'empty body'
			end

			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			if not ok then
				if debug then return nil, `invalid json: {raw}` end
				return nil, 'invalid json'
			end

			return decoded, nil
		end
	}

	return fetchResponse
end
