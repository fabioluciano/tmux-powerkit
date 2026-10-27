# Live tennis snapshots

The `livetennis` plugin shows the first live match in a shared snapshot.
It includes the players, set scores and snapshot time in UTC.
The current tiebreak is labeled when the API reports one.
Missing scores stay unknown. An optional player name filter selects a match locally.

Install Python 3.8 or later and jq. Both Linux and macOS use the same helper.
Set `LIVETENNIS_API_KEY` in the environment before starting the tmux server.
For a new server, Bash can read the credential without adding it to shell history:

```bash
read -rs -p 'Live Tennis API key: ' LIVETENNIS_API_KEY
export LIVETENNIS_API_KEY
tmux
```

An existing tmux server must receive that environment variable before the plugin can use it.
The plugin does not put the credential in command arguments or its cache.

Add `livetennis` to your configured plugins:

```tmux
set -g @powerkit_plugins "livetennis,datetime"
set -g @powerkit_plugin_livetennis_player ""
set -g @powerkit_plugin_livetennis_cache_ttl "60"
```

The `player` option matches either player's name without case sensitivity.
It does not make another API request.
The `cache_ttl` option controls how often PowerKit rereads the snapshot.
Changing it cannot shorten the API request limit.

## Request limits and freshness

The plugin uses `GET /matches?status=live&limit=200` with the `X-API-Key` header.
That endpoint works on the free plan.
All instances sharing the state directory reserve requests at least 900 seconds apart.
Failures and process restarts count. This allows at most 96 attempts per day, below the free plan's 100.
Other applications using the same account consume its remaining allowance.

Snapshot time stays visible. A failed refresh retains the previous snapshot and marks it stale.
A successful empty result says there are no live matches.
Only the first page is fetched. A partial result is labeled, so a missing player can also be outside that page.

Reservations and snapshots live in `${XDG_STATE_HOME:-~/.local/state}/tmux-powerkit/livetennis`.
PowerKit's display cache clear does not remove them.
A damaged reservation prevents new requests. Keep this state directory when restarting or updating PowerKit.

The payload fields and free endpoint are described in the [API specification](https://docs.livetennisapi.com/openapi.yaml).
