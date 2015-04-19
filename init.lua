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
local Emitter = require('core').Emitter

local isEmpty = framework.string.isEmpty
local trim = framework.string.trim
local timed = framework.util.timed

local PollerCollection = Emitter:extend()

function PollerCollection:initialize(pollers) 
  self.pollers = pollers or {}

end

function PollerCollection:add(poller)
  table.insert(self.pollers, poller)
end

function PollerCollection:run(callback) 
  if self.running then
    return
  end

  self.running = true
  for _,p in pairs(self.pollers) do
    p:run(callback)
  end

end

local WebRequestDataSource = DataSource:extend()
function WebRequestDataSource:initialize(params)
	local options = params
	if type(params) == 'string' then
		options = url.parse(params)
	end

  self.wait_for_end = options.wait_for_end or false

	self.options = options
  self.info = options.meta
end

function WebRequestDataSource:request(reqOptions, callback)
  return http.get(reqOptions, callback)
end

function WebRequestDataSource:fetch(context, callback)
  assert(callback, 'WebRequestDataSource:fetch: callback is required')

	local headers = nil 
	local buffer = ''
	local reqOptions = {
		host = self.options.host,
		port = self.options.port,
		path = self.options.path,
		headers = headers
	}

	local success = function (res) 

    if self.wait_for_end then
		  res:on('end', function ()
        callback(buffer, self.info)
      end)
    else 
      res:once('data', function (data)
        if not self.wait_for_end then
          callback(buffer, self.info)
        end
      end)
    end 

		res:on('data', function (data) 
			buffer = buffer .. data
    end)

    res:propagate('error', self)
	end

	local req = self:request(reqOptions, success)
	req:propagate('error', self)
end

local params = framework.params
params.name = 'Boundary Http Check Plugin'
params.version = '1.1'

-- for each item create a DataSourcePoller for a WebRequestDataSource
-- todo create a special table for collections
function createPollers(params) 
  local pollers = PollerCollection:new() 

  for _,item in pairs(params.items) do

    local options = url.parse(item.url)
    options.protocol = options.protocol or item.protocol or 'http'
    options.auth = options.auth or (not isEmpty(item.username) and not isEmpty(item.password) and item.username .. ':' .. item.password)
    options.method = item.method
    options.meta = item.source
    options.post_data = item.postData

    options.wait_for_end = false

    local data_source = WebRequestDataSource:new(options)

    local time_interval = tonumber((item.pollInterval or params.pollInterval)) * 1000
    local poller = DataSourcePoller:new(time_interval, data_source)
    
    pollers:add(poller)
  end

  return pollers
end

local pollers = createPollers(params)

local plugin = Plugin:new(params, pollers)
function plugin:onParseValues(data, info)
  local result = {}
  result['HTTP_RESPONSETIME'] = {value = 1.0, source = info} 

  return result
end
plugin:run()

