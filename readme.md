# Hammerspoon Slack notifier

Check the Slack API periodically and provide a count of unread DMs and mentions
in a menubar app. Click on the menubar icon to snooze.

![screenshot](https://zthings.files.wordpress.com/2020/02/screen-shot-2020-02-09-at-11.17.33-pm.png)

## Loading the spoon

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
- `cookieToken`: Token found in your cookies when authenticated against your Slack workspace in the browser (required)
  - Using Chrome devtools, go to Application > Cookies > https://app.slack.com
  - Copy the value for `d`. It should start with `xoxd-`.
  - If it contains URL-encoded characters (`%..`), you will need to URL-decode it: `copy( encodeURIComponent( 'token' ) )`.
- `workspaceToken`: Token found in request payload when authenticated against your Slack workspace in the browser (required).
  - Using Chrome devtools, go to Network, reload the page, and filter for `slack.com/api/`, select a `POST` request, and click the Payload tab.
  - Look for `token` in the payload. It should start with `xoxc-`.
