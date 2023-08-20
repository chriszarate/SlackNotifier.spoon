# Hammerspoon Slack notifier

Check the Slack API periodically and provide a count of unread DMs and mentions
in a menubar app. Click on the menubar icon to snooze.

![screenshot](https://zthings.files.wordpress.com/2020/02/screen-shot-2020-02-09-at-11.17.33-pm.png)

## Loading the sppon

Clone this repo in `~/.hammerspoon/Spoons/`. (After doing so, the path to this
readme should be `~/.hammerspoon/Spoons/SlackNotifier.spoon/readme.md`.

Now load the spoon from your Hammerspoon config:

```lua
hs.loadSpoon('SlackNotifier')
spoon.SlackNotifier:start({
  cookieToken = "xoxd-xxxx",
  workspaceToken = "xoxc-xxxx",
})
```

# Configuration

- `interval`: Interval in seconds to refresh the menu (default 60)
- `cookieToken`: Token found in your cookies when authenticated against your Slack workspace in the browser. Look for `d=` (required)
- `workspaceToken`: Token found in request payload when authenticated against your Slack workspace in the browser. Look for `token=` (required)
