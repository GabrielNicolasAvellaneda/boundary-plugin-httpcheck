--------------------------------------------------------------------------
-- Module to Http Check URL for Boundary Lua HttpCheck Plugin
--
-- Author: Yegor Dia
-- Email: yegordia at gmail.com
--
--------------------------------------------------------------------------

local object = require('core').Object
local http = require('http')
local https = require('https')
local string = require('string')
local table = require('table')
local timer = require('timer')
local os = require('os')

function string:split( inSplitPattern, outResults )
	if not outResults then
		outResults = { }
	end
	local theStart = 1
	local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
	while theSplitStart do
		table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
		theStart = theSplitEnd + 1
		theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
	end
	table.insert( outResults, string.sub( self, theStart ) )
	return outResults
end

local function callIfNotNil(callback, ...)
    if callback ~= nil then
        callback(...)
    end
end

local HttpCheck = object:extend()

--[[ Initialize HttpCheck
]]
function HttpCheck:initialize()
	return self
end


--[[ Process parameters
]]
function HttpCheck:process_params(method, protocol, url, username, password, postdata)
	local params = {}
	
	local _method = "GET"
	local _protocol = "http"
	local _url = "127.0.0.1"
	local _username = nil
	local _password = nil
	local _port = 80
	local _body = ""
	local _path = "/"
	local _headers = {}

	if (string.find(url, "http") ~= nil) then
		error("URL cannot include protocol.")
		return
	end
	
	if method ~= nil and method ~= "GET" then
		_method = method
	end
	
	if protocol ~= nil and protocol ~= "http" and protocol == "https" then
		_protocol = protocol
	end
	
	local splitted = url:split('/')
	if table.getn(splitted) > 1 then
		_host = splitted[1]
		_path = "/" .. splitted[2]
		if table.getn(splitted) > 2 then
			for i=3, table.getn(splitted) do
				_path = _path .. "/" .. splitted[i]
			end
		end
	else
		_host = splitted[1]
	end
	
	splitted = _host:split(':')
	if table.getn(splitted) > 1 then
		_host = splitted[1]
		_port = tonumber(splitted[2])
	end
	
	if username ~= nil then
		if string.len(username) > 1 then
			local _password = password or ""
			_host = username .. ":" .. _password .. "@" .. _host
		end
	end
	
	if postdata ~= nil and table.getn(postdata) > 0 then
		_body = table.concat(postdata, '&')
		_headers['Content-Type'] = 'application/x-www-form-urlencoded'
		_headers['Content-Length'] = string.len(_body)
	end
	_headers['User-Agent'] = 'Boundary Meter <support@boundary.com>'
	
	params['method'] = _method
	params['host'] = _host
	params['port'] = _port
	params['protocol'] = _protocol
	params['headers'] = _headers
	params['body'] = _body
	params['path'] = _path
	
	return params
end

--[[ Runs test server to test plugin
]]
function HttpCheck:run_test_server()

	local HOST = "127.0.0.1"
	local PORT = process.env.PORT or 10080
	local server = nil
	local client = nil

	server = http.createServer(function(request, response)
	  local postBuffer = ''
	  
	  request:on('data', function(chunk)
		postBuffer = postBuffer .. chunk
	  end)
	  
	  request:on('end', function()
		response:finish()
		server:close()
	  end)
	  
	end)

	server:listen(PORT, HOST, function()
	end)
	
	return HOST .. ":" .. PORT
end

local function duration (seconds)
	local shift = 10 ^ 2
	local result = math.floor(seconds * 1000 * shift + 0.5) / shift
	return result
end

--[[ Get response time and status code of URL with parameters
]]
function HttpCheck:request(method, protocol, url, username, password, postdata, callback)
	
	local params = self:process_params(method, protocol, url, username, password, postdata)
	
	local _status_code = 404
	local _exec_time = 0
	
	local start_time = os.clock()
	
	if params['protocol'] == 'http' then
		local req = http.request({
		  host = params['host'],
		  port = params['port'],
		  path = params['path'],
		  method = params['method'],
		  headers = params['headers']
		}, function (res)

		  res:on("error", function(err)
			msg = tostring(err)
		  end)

		  res:on("data", function (chunk)
			_status_code = res.status_code
			_exec_time = os.clock() - start_time
			callIfNotNil(callback, { status_code = _status_code, exec_time = duration(_exec_time) })
		  end)

		  res:on("end", function ()

			res:destroy()
		  end)
		end)

		req:on("error", function(err)
		  msg = tostring(err)
		  process.stderr:write("Error while sending a request: " .. msg)
		end)
		if string.len(params['body']) > 0 then
			req:write(params['body'])
		end
		req:done()
	end
	
	if params['protocol'] == 'https' then
		local req = http.request({
		  host = params['host'],
		  port = params['port'],
		  path = params['path'],
		  method = params['method'],
		  headers = params['headers']
		}, function (res)
			
		  res:on("error", function(err)
			msg = tostring(err)
		  end)

		  res:on("data", function (chunk)
			_status_code = res.status_code
			_exec_time = os.clock() - start_time
			callIfNotNil(callback, { status_code = _status_code, exec_time = duration(_exec_time) })
		  end)

		  res:on("end", function ()

			res:destroy()
		  end)
		end)

		req:on("error", function(err)
		  msg = tostring(err)
		  process.stderr:write("Error while sending a request: " .. msg)
		end)
		if string.len(params['body']) > 0 then
			req:write(params['body'])
		end
		req:done()
	end
	
end


return HttpCheck
