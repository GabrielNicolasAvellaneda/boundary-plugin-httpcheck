local framework = require('./modules/framework.lua')
local Plugin = framework.Plugin
local DataSource = framework.DataSource
local DataSourcePoller = framework.DataSourcePoller
local http = require('http')
local https = require('https')
local url = require('url')
local os = require('os')
local timer = require('timer')
local table = require('table')

local isEmpty = framework.string.isEmpty
local trim = framework.string.trim
local timed = framework.util.timed

local WebRequestDataSource = DataSource:extend()
function WebRequestDataSource:initialize(params)
	local options = params
	if type(params) == 'string' then
		options = url.parse(params)
	end

  self.wait_for_end = options.wait_for_end or false

	self.options = options
end

function WebRequestDataSource:request(reqOptions, callback)
  return http.get(reqOptions, callback)
end

function WebRequestDataSource:fetch(context, callback)
	local headers = nil 
	local buffer = ''
	local reqOptions = {
		host = self.options.host,
		port = self.options.port,
		path = self.options.path,
		headers = headers
	}

	local success = function (res) 
		res:on('end', function ()
  
      if self.wait_for_end then
        callback(buffer, self.meta)
      end
  
    end) 

    res:once('data', function (data)
      if not self.wait_for_end then
        callback(buffer, self.meta)
      end
    end)

		res:on('data', function (data) 
			buffer = buffer .. data
    end)

	end

	local req = self:request(reqOptions, success)
	req:propagate('error', self)
end

local params = framework.params
params.name = 'Boundary Http Check Plugin'
params.version = '1.1'

-- for each item create a WebRequestDataSource


function createPollers() 

  local pollers_list = {}

  for _,item in pairs(params.items) do

    local options = url.parse(item.url)
    options.protocol = options.protocol or item.protocol or 'http'
    options.auth = options.auth or (not isEmpty(item.username) and not isEmpty(item.password) and item.username .. ':' .. item.password)
    options.method = item.method
    options.meta = item.source
    options.post_data = item.postData

    options.wait_for_end = false

    p(options)

    local data_source = WebRequestDataSource:new(options)


    data_source:fetch(nil, timed(function () p('this is the callback') end)) 

    local time_interval = item.timeInterval or params.timeInterval
    local poller = DataSourcePoller(time_interval, data_source)
    table.insert(pollers_list, poller)
  end

  return pollers_list
end





--[[

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
]]
