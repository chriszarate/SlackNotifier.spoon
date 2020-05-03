# Hammerspoon Slack notifier

Check the Slack API periodically and provide a count of unread DMs and mentions
in a menubar app. This spoon requires a [Slack legacy app token][token].

![screenshot](https://zthings.files.wordpress.com/2020/02/screen-shot-2020-02-09-at-11.17.33-pm.png)

## Loading the sppon

Clone this repo in `~/.hammerspoon/Spoons/`. (After doing so, the path to this
readme should `~/.hammerspoon/Spoons/SlackNotifier.spoon/readme.md`.

Now load the spoon from your Hammerspoon config:

```lua
hs.loadSpoon('SlackNotifier')
spoon.SlackNotifier:start({token = "xoxp-xxxx"})
```

# Configuration

- `interval`: Interval in seconds to refresh the menu (default 60)
- `token`: Slack legacy API token (required)

[token]: https://api.slack.com/legacy/custom-integrations/legacy-tokens
