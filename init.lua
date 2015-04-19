local framework = require('./modules/framework.lua')
local Plugin = framework.Plugin
local DataSourcePoller = framework.DataSourcePoller
local WebRequestDataSource = framework.WebRequestDataSource
local PollerCollection = framework.PollerCollection
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

local params = framework.params
params.name = 'Boundary Http Check Plugin'
params.version = '1.1'

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

