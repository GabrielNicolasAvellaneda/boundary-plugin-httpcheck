local framework = require('framework')
local Plugin = framework.Plugin
local DataSource = framework.DataSource
local DataSourcePoller = framework.DataSourcePoller
local http = require('http')
local https = require('https')
local url = require('url')
local os = require('os')
local timer = require('timer')

local params = framework.params
params.name = 'LUA demo plugin'
params.version = '1.0'

local item = {}
item.uri = 'http://www.google.com.br' -- protocol, host, port and path
item.pollInterval = 5 -- seconds between polls

local options = url.parse(item.uri)
options.method = 'GET'
options.meta = 'this is the source'
options.postData = nil
p(item)

local WebRequestDataSource = DataSource:extend()
function WebRequestDataSource:initialize(params)
	local options = params
	if type(params) == 'string' then
		options = url.parse(params)
	end

	self.options = options
end

function WebRequestDataSource:fetch(context, callback)
	local headers = nil 
	local startTime = os.time()
	local data = ''
	local reqOptions = {
		host = self.options.host,
		port = self.options.port,
		path = self.options.path,
		headers = headers
	}

	local success = function (res) 
		p(res.headers)
		local fn = function(d)
			local elapsedTime = os.time() - startTime
			if callback then
				callback({data = d, elapsedTime = elapsedTime}, options.meta)
			end
		end
		
		res:on('end', function () p('end') end) 

		res:on('data', function (d) 
			data = data .. d
			p('data')
		end)

	end

	local req = http.request(reqOptions, success)
	req:propagate('error', self)
	req:done()
end

local dataSource = WebRequestDataSource:new(options)
dataSource:fetch(nil, function (result) p(result.elapsedTime) end)

local CustomPlugin = Plugin:extend()

function CustomPlugin:initialize(pollers)
	self.pollers = pollers
end

function createDataSource(options)
	return WebRequestDataSource:new(options)
end

function createPoller(pollInterval, dataSource)
	return DataSourcePoller:new(pollInterval, dataSource)
end

local pollers = fun.totable(fun.map(function (item) 
	return createPoller(tonumber(item.pollInterval)*1000, createDataSource(item)) end
, params.items))


local plugin = CustomPlugin:new(params, pollers)
function plugin:onParseValues(data)
	local result = {}
	result['BOUNDARY_LUA_SAMPLE'] = tonumber(data)

	return result 
end
function plugin:run()
	fun.each(function (poller) 
				poller:run()	
			end, pollers)	
end

--plugin:run()
timer.setTimeout(10000, function () p('finished') end)

