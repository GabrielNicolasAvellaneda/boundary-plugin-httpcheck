local boundary = require('boundary')
local httpchecker = require('httpchecker')
local timer = require('timer')
local string = require('string')

-- Default params
local __pgk = "Boundary HTTPCheck Plugin"
local __ver = "Version 1.1"
local items = {}
local pollInterval = 2000

-- Fetching params
if (boundary.param ~= nil) then
  items = boundary.param.items or items
  pollInterval = boundary.param.pollInterval or pollInterval
end

print("_bevent:%s : %s UP|t:info|tags:lua,plugin")

local httpcheck = httpchecker:new()

local function poll()
	for index, item in ipairs(items) do
		timer.setTimeout(tonumber(item.pollInterval), function ()
			httpcheck:request(item['method'], item['protocol'], item['url'], item['username'], item['password'], item['postdata'], function(response)
				print(string.format("HTTP_RESPONSETIME %s %s", response['exec_time'], item.source))
			end)
		end)
	end
end

timer.setInterval(pollInterval, function ()
	poll()
end)
