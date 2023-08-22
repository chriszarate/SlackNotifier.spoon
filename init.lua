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

local icon = hs.image.imageFromASCII(iconAscii)

-- update the menu bar
local function updateCount(count)
	if count > 0 then
		obj.menu:setTitle(count)
	else
		obj.menu:setTitle('')
	end
end

-- on click, clear the count
local function onClick()
	updateCount(0)
end

-- process the response
local function onResponse(status, body)
	if status < 0 then
		return
	end

	-- parse json response
	local json = hs.json.decode(body)
	local count = 0

	-- reminders
	count = count + json.saved.uncompleted_overdue_count

	-- loop through channel badges and add em up
	for _, badge_count in pairs(json.channel_badges) do
		count = count + badge_count
	end

	-- update the menu bar
	updateCount(count)
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
		self.menu = hs.menubar.new():setClickCallback(onClick):setIcon(icon)
	end

	-- set timer to fetch periodically
	self.timer = hs.timer.new(interval, onInterval)
	self.timer:start()

	-- fetch immediately, too
	updateCount(0)
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
