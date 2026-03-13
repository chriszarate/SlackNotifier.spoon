--- === SlackNotifier ===
---
--- Check Slack API periodically and provide a count of unread DMs and mentions
--- in a menubar app. Supports multiple Slack workspaces.

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

-- category icons for dropdown menu
local function createCanvasIcon(drawFn)
	local size = 12
	local c = hs.canvas.new({ x = 0, y = 0, w = size, h = size })
	drawFn(c, size)
	local img = c:imageFromCanvas()
	c:delete()
	return img:template(true)
end

local dmIcon = createCanvasIcon(function(c, s)
	c[1] = {
		type = 'segments',
		closed = true,
		coordinates = {
			{ x = 1, y = 2 },
			{ x = s - 1, y = 2 },
			{ x = s - 1, y = s - 4 },
			{ x = 5, y = s - 4 },
			{ x = 3, y = s },
			{ x = 3, y = s - 4 },
			{ x = 1, y = s - 4 },
		},
		action = 'fill',
		fillColor = { white = 0 },
	}
end)

local starredIcon = createCanvasIcon(function(c, s)
	local cx, cy, r = s / 2, s / 2, s / 2 - 1
	local ir = r * 0.38
	local coords = {}
	for i = 0, 4 do
		local oa = math.rad(-90 + i * 72)
		table.insert(coords, { x = cx + r * math.cos(oa), y = cy + r * math.sin(oa) })
		local ia = math.rad(-90 + i * 72 + 36)
		table.insert(coords, { x = cx + ir * math.cos(ia), y = cy + ir * math.sin(ia) })
	end
	c[1] = {
		type = 'segments',
		closed = true,
		coordinates = coords,
		action = 'fill',
		fillColor = { white = 0 },
	}
end)

local activityMenuIcon = createCanvasIcon(function(c, s)
	c[1] = {
		type = 'oval',
		frame = { x = 2, y = 2, w = s - 4, h = s - 4 },
		action = 'fill',
		fillColor = { white = 0 },
	}
end)

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

-- per-workspace counts: { [index] = { dmCount, activityCount, starredCount, err } }
local counts = {}

-- per-workspace starred channel IDs: { [index] = { [channelId] = true } }
local starredChannels = {}

-- aggregate counts across all workspaces and update the menu bar
local function updateMenu()
	local totalDm = 0
	local totalActivity = 0
	local allErr = true

	local totalStarred = 0

	for _, c in pairs(counts) do
		if not c.err then
			allErr = false
			totalDm = totalDm + c.dmCount
			totalActivity = totalActivity + c.activityCount
			totalStarred = totalStarred + c.starredCount
		end
	end

	if allErr then
		obj.menu:returnToMenuBar()
		obj.menu:setIcon(dimmedIcon, true):setTitle('?')
	elseif totalDm > 0 then
		obj.menu:returnToMenuBar()
		obj.menu:setIcon(activeIcon, true):setTitle(totalDm)
	elseif totalActivity > 0 or totalStarred > 0 then
		obj.menu:returnToMenuBar()
		obj.menu:setIcon(activeIcon, true):setTitle('')
	else
		obj.menu:removeFromMenuBar()
	end
end

-- build dropdown menu items, grouped by category
local function buildMenu()
	local dmItems = {}
	local starredItems = {}
	local actItems = {}

	for i, workspace in ipairs(obj.workspaces) do
		local c = counts[i]
		if not c.err then
			local name = workspace.name or ('Workspace ' .. i)

			if c.dmCount > 0 then
				table.insert(dmItems, {
					title = tostring(c.dmCount) .. '  ' .. name,
					disabled = true,
					image = dmIcon,
				})
			end

			if c.starredCount > 0 then
				table.insert(starredItems, {
					title = tostring(c.starredCount) .. '  ' .. name,
					disabled = true,
					image = starredIcon,
				})
			end

			if c.activityCount > 0 then
				table.insert(actItems, {
					title = tostring(c.activityCount) .. '  ' .. name,
					disabled = true,
					image = activityMenuIcon,
				})
			end
		end
	end

	-- combine sections with separators
	local items = {}
	local sections = { dmItems, starredItems, actItems }
	for _, section in ipairs(sections) do
		if #section > 0 then
			if #items > 0 then
				table.insert(items, { title = '-' })
			end
			for _, item in ipairs(section) do
				table.insert(items, item)
			end
		end
	end

	if #items == 0 then
		table.insert(items, { title = 'No new activity', disabled = true })
	end

	return items
end

-- create a handler for stars.list response for a specific workspace index
local function makeStarredHandler(index)
	return function(status, body)
		if status < 0 then
			return
		end

		local json = hs.json.decode(body)

		if not json.ok then
			return
		end

		local starred = {}
		for _, item in ipairs(json.items) do
			if item.type == 'channel' then
				starred[item.channel] = true
			end
		end

		starredChannels[index] = starred
	end
end

-- create a response handler for a specific workspace index
local function makeResponseHandler(index)
	return function(status, body)
		if status < 0 then
			return
		end

		-- parse json response
		local json = hs.json.decode(body)

		-- print('slack response:', tableToString(json))

		if not json.ok then
			counts[index] = { dmCount = 0, activityCount = 0, starredCount = 0, err = true }
			print('SlackNotifier: workspace ' .. index .. ' error: ' .. json.error)
			updateMenu()
			return
		end

		-- mentions and dms
		local dmCount = 0

		-- unread threads and reminders
		local activityCount = 0
		if json.saved then
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

		-- count starred channels with unreads
		local starredCount = 0
		if json.channels and starredChannels[index] then
			for _, channel in ipairs(json.channels) do
				if starredChannels[index][channel.id] and channel.has_unreads then
					starredCount = starredCount + 1
				end
			end
		end

		counts[index] = { dmCount = dmCount, activityCount = activityCount, starredCount = starredCount, err = false }
		updateMenu()
	end
end

-- timer callback, fetch all workspaces
local function onInterval()
	local countsUrl = 'https://slack.com/api/client.counts'
	local starsUrl = 'https://slack.com/api/stars.list'

	for i, workspace in ipairs(obj.workspaces) do
		local data = 'token=' .. workspace.workspaceToken
		local headers = {
			Cookie = 'd=' .. hs.http.encodeForQuery(workspace.cookieToken)
		}
		hs.http.asyncPost(starsUrl, data, headers, makeStarredHandler(i))
		hs.http.asyncPost(countsUrl, data, headers, makeResponseHandler(i))
	end
end

--- SlackNotifier:start(config)
--- Method
--- Start the spoon
---
--- Parameters:
---  * config - A table containing config values:
---             interval:   Interval in seconds to refresh the menu (default 60)
---             workspaces: Array of { name, cookieToken, workspaceToken } tables
---
---             For a single workspace, name, cookieToken, and workspaceToken
---             can be provided directly on the config table instead.
---
--- Returns:
---  * self (allow chaining)
function obj:start(config)
	local interval = config.interval or 60

	-- support both flat (single workspace) and array (multi-workspace) configs
	if config.workspaces then
		self.workspaces = config.workspaces
	else
		self.workspaces = {
			{ name = config.name, cookieToken = config.cookieToken, workspaceToken = config.workspaceToken }
		}
	end

	-- initialize per-workspace counts
	counts = {}
	for i = 1, #self.workspaces do
		counts[i] = { dmCount = 0, activityCount = 0, starredCount = 0, err = false }
	end

	-- create menubar (or restore it)
	if self.menu then
		self.menu:returnToMenuBar()
	else
		self.menu = hs.menubar.new():setMenu(buildMenu)
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
