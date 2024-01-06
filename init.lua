--- === SlackNotifier ===
---
--- Check Slack API periodically and provide a count of unread DMs and mentions
--- in a menubar app. This spoon requires a Slack legacy app token to be
--- provided to the :start method:
---
--- https://api.slack.com/legacy/custom-integrations/legacy-tokens

-- luacheck: globals hs

local obj = {}

-- Metadata
obj.name = 'SlackNotifier'
obj.version = '1.0'
obj.author = 'Chris Zarate <chris@zarate.org>'
obj.homepage = 'https://github.com/chriszarate/SlackNotifier.spoon'
obj.license = 'MIT - https://opensource.org/licenses/MIT'

-- create the icon
-- http://xqt2.com/asciiIcons.html
local iconAscii = [[ASCII:
............
....AD......
.........PQ.
.F..........
.I..........
...........G
...........H
K...........
N...........
..........L.
..........M.
.BC.........
......SR....
............
]]

local activeIcon = hs.image.imageFromASCII(iconAscii)
local dimmedIcon = hs.image.imageFromASCII(iconAscii,
	{ { fillColor = { alpha = 0.5 }, strokeColor = { alpha = 0.5 } } })

-- debug helper
local function tableToString(o)
	if type(o) == 'table' then
		local s = '{ '
		for k, v in pairs(o) do
			if type(k) ~= 'number' then k = '"' .. k .. '"' end
			s = s .. '[' .. k .. '] = ' .. tableToString(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

-- update the menu bar
local function updateCount(dmCount, activityCount, err)
	if err then
		obj.menu:setIcon(dimmedIcon, true):setTitle('?')
	elseif dmCount > 0 then
		obj.menu:setIcon(activeIcon, true):setTitle(dmCount)
	elseif activityCount > 0 then
		obj.menu:setIcon(activeIcon, true):setTitle('')
	else
		obj.menu:setIcon(dimmedIcon, true):setTitle('')
	end
end

-- on click, clear the count
local function onClick()
	updateCount(0, 0, false)
end

-- process the response
local function onResponse(status, body)
	if status < 0 then
		return
	end

	-- parse json response
	local json = hs.json.decode(body)

	-- print('slack response:', tableToString(json))

	if not json.ok then
		updateCount(0, 0, true)
		print('SlackNotifier: error: ' .. json.error)
		return
	end

	-- mentions and dms
	local dmCount = 0

	-- unread threads and reminders
	local activityCount = 0
	if (json.saved) then
		activityCount = json.saved.uncompleted_overdue_count
	end

	-- loop through channel badges and add em up
	for type, badge_count in pairs(json.channel_badges) do
		if type == 'app_dms' or type == 'thread_unreads' then
			activityCount = activityCount + badge_count
		else
			dmCount = dmCount + badge_count
		end
	end

	-- update the menu bar
	updateCount(dmCount, activityCount, false)
end

-- timer callback, fetch response
local function onInterval()
	local data = 'token=' .. obj.config.workspaceToken
	local headers = {
		Cookie = 'd=' .. hs.http.encodeForQuery(obj.config.cookieToken)
	}
	local fetchUrl = 'https://slack.com/api/client.counts'

	hs.http.asyncPost(fetchUrl, data, headers, onResponse)
end

--- SlackNotifier:start(config)
--- Method
--- Start the spoon
---
--- Parameters:
---  * config - A table containing config values:
--              interval: Interval in seconds to refresh the menu (default 60)
--              token:    Slack legacy API token (required)
---
--- Returns:
---  * self (allow chaining)
function obj:start(config)
	self.config = config

	local interval = config.interval or 60

	-- create menubar (or restore it)
	if self.menu then
		self.menu:returnToMenuBar()
	else
		self.menu = hs.menubar.new():setClickCallback(onClick)
	end

	-- set timer to fetch periodically
	self.timer = hs.timer.new(interval, onInterval)
	self.timer:start()

	-- fetch immediately, too
	onInterval()

	return self
end

--- SlackNotifier:stop()
--- Method
--- Stop the spoon
---
--- Parameters: none
---
--- Returns:
---  * self (allow chaining)
function obj:stop()
	if self.menu then
		self.menu:removeFromMenuBar()
	end

	if self.timer then
		self.timer:stop()
	end

	return self
end

return obj
