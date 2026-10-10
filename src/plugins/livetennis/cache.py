"""Share one durable free tennis snapshot across status workers."""
import argparse
import datetime
import fcntl
import http.client
import json
import math
import os
from pathlib import Path
import stat
import tempfile
import time
import unicodedata
import urllib.error
import urllib.request

URL = "https://api.livetennisapi.com/api/public/v1/matches?status=live&limit=200"
INTERVAL = 900  # At most 96 attempts per day, below the free allowance of 100.
MAX_BYTES = 2 * 1024 * 1024
TIMEOUT = 8


def clean(value, key="", limit=32):
    if not isinstance(value, str):
        return ""
    if key:
        value = value.replace(key, "[redacted]")
    value = "".join(" " if unicodedata.category(c).startswith("C") or c in "#|" else c
                    for c in value)
    return " ".join(value.split())[:limit]


def timestamp(value):
    return type(value) in (int, float) and 0 <= value <= 253402300799 and math.isfinite(value)


def score_text(score, key):
    if score is None:
        return "score unavailable"
    if (not isinstance(score, dict) or score.get("server") not in (None, 1, 2)
            or score.get("server") is not None and type(score["server"]) is not int):
        raise ValueError("score")
    games = score.get("games")
    if games is None or games == []:
        return "score unavailable"
    if (not isinstance(games, list) or len(games) != 2
            or any(not isinstance(side, list) for side in games)
            or len(games[0]) != len(games[1]) or not 1 <= len(games[0]) <= 5
            or any(type(n) is not int or not 0 <= n <= 1000 for side in games for n in side)):
        raise ValueError("games")
    result = " ".join("{}-{}".format(a, b) for a, b in zip(*games))
    points = score.get("points")
    if points is not None:
        if (not isinstance(points, list) or len(points) not in (0, 2)
                or any(p is not None and not isinstance(p, str) for p in points)):
            raise ValueError("points")
        if points:
            result += " ({})".format("-".join(clean(p, key, 8) or "?" for p in points))
    return (result + (" (tiebreak)" if score.get("is_tiebreak") is True else "")
            + (" (score stale)" if score.get("stale") is True else ""))


def snapshot(payload, key):
    if not isinstance(payload, dict) or not isinstance(payload.get("data"), list):
        raise ValueError("data")
    data, meta = payload["data"], payload.get("meta", {})
    if len(data) > 200 or not isinstance(meta, dict):
        raise ValueError("page")
    total, more = meta.get("total"), meta.get("has_more", False)
    if (type(more) is not bool or total is not None
            and (type(total) is not int or total < 0)):
        raise ValueError("metadata")
    rows = []
    for match in data:
        if not isinstance(match, dict):
            raise ValueError("match")
        if match.get("status") not in ("live", "upcoming", "completed", "cancelled"):
            raise ValueError("status")
        if match["status"] != "live":
            continue
        players = match.get("players") or {}
        if not isinstance(players, dict):
            raise ValueError("players")
        names = []
        for side in ("p1", "p2"):
            player = players.get(side) or {}
            if not isinstance(player, dict):
                raise ValueError("player")
            names.append(clean(player.get("name"), key, 128) or "Unknown player")
        rows.append({"name1": names[0], "name2": names[1],
                     "score": clean(score_text(match.get("score"), key), key, 80)})
    return rows, more or len(data) == 200 or total is not None and total > len(data)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def fetch(key):
    request = urllib.request.Request(URL, headers={"X-API-Key": key, "Accept": "application/json"})
    try:
        response = urllib.request.build_opener(NoRedirect()).open(request, timeout=TIMEOUT)
    except urllib.error.HTTPError as error:
        error.close()
        raise
    with response:
        if response.status != 200:
            raise ValueError("status")
        raw = response.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError("size")
    return snapshot(json.loads(raw), key)


def private_file(path, flags):
    descriptor = os.open(str(path), flags | os.O_NOFOLLOW, 0o600)
    info = os.fstat(descriptor)
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
        os.close(descriptor)
        raise OSError("unsafe file")
    os.fchmod(descriptor, 0o600)
    return descriptor


def read_state(path):
    with os.fdopen(private_file(path, os.O_RDONLY), "r", encoding="utf-8") as stream:
        state = json.loads(stream.read(MAX_BYTES + 1))
    required = {"version", "attempted_at", "snapshot_at", "rows", "partial", "last_error"}
    if (not isinstance(state, dict) or not required.issubset(state)
            or type(state.get("version")) is not int or state["version"] != 1
            or not timestamp(state.get("attempted_at"))
            or type(state.get("partial")) is not bool
            or state.get("last_error") not in (None, "pending", "request", "storage")
            or not isinstance(state.get("rows"), list) or len(state["rows"]) > 200
            or state.get("snapshot_at") is not None and not timestamp(state["snapshot_at"])):
        raise ValueError("state")
    if state["snapshot_at"] is None and state["rows"]:
        raise ValueError("snapshot")
    for row in state["rows"]:
        if not isinstance(row, dict) or any(not isinstance(row.get(k), str)
                                            for k in ("name1", "name2", "score")):
            raise ValueError("row")
    return state


def save_state(path, state):
    descriptor, temporary = tempfile.mkstemp(prefix=".snapshot-", dir=str(path.parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            os.fchmod(stream.fileno(), 0o600)
            json.dump(state, stream, ensure_ascii=True, allow_nan=False)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, str(path))
        directory = os.open(str(path.parent), os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def result(state, now, player, key, error="", configured=True):
    output = {"text": "Tennis snapshot unavailable", "state": "failed", "health": "error",
              "context": error, "count": 0, "partial": False, "snapshot_at": None,
              "last_attempt": None, "stale": False, "configured": configured}
    if not configured:
        output["text"] = "Set LIVETENNIS_API_KEY"
        return output
    if state is None:
        return output
    output["last_attempt"] = state["attempted_at"]
    if state["snapshot_at"] is None:
        return output
    age = max(0, int(now - state["snapshot_at"]))
    stale = bool(error or state["last_error"] or now < state["attempted_at"] or age >= INTERVAL)
    stamp = datetime.datetime.fromtimestamp(state["snapshot_at"], datetime.timezone.utc).strftime("%H:%MZ")
    rows = state["rows"]
    query = clean(player, key, 128).casefold()
    selected = next((r for r in rows if not query or query in r["name1"].casefold()
                     or query in r["name2"].casefold()), None)
    text = "No matching live matches" if rows and query else "No live matches"
    if selected:
        text = "{} vs {} {}".format(clean(selected["name1"], key), clean(selected["name2"], key),
                                    clean(selected["score"], key, 80))
    context = "{} live snapshot {} {}m old{}{}".format(len(rows), stamp, age // 60,
                                             " partial" if state["partial"] else "",
                                             " stale" if stale else "")
    output.update(text=text + " " + context, state="degraded" if stale else "active",
                  health="warning" if stale else "ok", context=context, count=len(rows),
                  partial=state["partial"], snapshot_at=state["snapshot_at"], stale=stale)
    return output


def collect(player=""):
    now, key = time.time(), os.environ.get("LIVETENNIS_API_KEY", "")
    if not key:
        return result(None, now, player, key, "missing key", False)
    if len(key) > 1024 or any(ord(c) < 33 or ord(c) > 126 for c in key):
        return result(None, now, player, "", "invalid key")
    base = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")
    directory = base / "tmux-powerkit" / "livetennis"
    state, descriptor = None, None
    try:
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if directory.is_symlink() or directory.stat().st_uid != os.getuid():
            raise OSError("unsafe directory")
        directory.chmod(0o700)
        path, lock = directory / "state.json", directory / "quota.lock"
        created = False
        try:
            descriptor = private_file(lock, os.O_CREAT | os.O_EXCL | os.O_RDWR)
            created = True
        except FileExistsError:
            descriptor = private_file(lock, os.O_RDWR)
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return result(read_state(path), now, player, key)
        try:
            state = read_state(path)
        except FileNotFoundError:
            if not created:
                raise
            state = {"version": 1, "attempted_at": 0, "snapshot_at": None,
                     "rows": [], "partial": False, "last_error": None}
        # Persist the reservation before sending. Crashes and failed requests spend it.
        now = time.time()
        if state["attempted_at"] and now - state["attempted_at"] < INTERVAL:
            return result(state, now, player, key)
        state["attempted_at"], state["last_error"] = now, "pending"
        save_state(path, state)
        try:
            rows, partial = fetch(key)
            state.update(rows=rows, partial=partial, snapshot_at=time.time(), last_error=None)
        except (OSError, ValueError, RecursionError, http.client.HTTPException, urllib.error.URLError):
            state["last_error"] = "request"
        # Start the next floor at completion, including a failed or delayed request.
        state["attempted_at"] = max(state["attempted_at"], time.time())
        save_state(path, state)
        return result(state, time.time(), player, key)
    except (OSError, ValueError, RecursionError):
        return result(state, now, player, key, "cache unavailable")
    finally:
        if descriptor is not None:
            os.close(descriptor)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--player", default="")
    options = parser.parse_args()
    print(json.dumps(collect(options.player), ensure_ascii=True))
