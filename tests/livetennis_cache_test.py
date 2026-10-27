import contextlib
import fcntl
import http.server
import importlib.util
import io
import json
import multiprocessing
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

HELPER = Path(__file__).resolve().parents[1] / "src/plugins/livetennis/cache.py"
spec = importlib.util.spec_from_file_location("livetennis_cache", str(HELPER))
cache = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cache)
KEY = "test-secret-never-persisted"


def payload(name1="Alcaraz", name2="Sinner", score=None, **meta):
    return {"data": [{"status": "live", "players": {"p1": {"name": name1},
                     "p2": {"name": name2}}, "score": score}], "meta": meta}


def child_collect(queue, player="", url=None):
    if url:
        cache.URL = url
    with mock.patch.object(cache.time, "time", return_value=1000):
        queue.put(cache.collect(player))


@contextlib.contextmanager
def server(body, status=200, redirect=False, delay=0, chunked=False):
    requests = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            requests.append((self.path, self.headers.get("X-API-Key")))
            time.sleep(delay)
            self.send_response(status)
            if redirect:
                self.send_header("Location", "/other")
            if chunked:
                self.send_header("Transfer-Encoding", "chunked")
            else:
                self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

    instance = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=instance.serve_forever, daemon=True)
    thread.start()
    url = "http://127.0.0.1:{}/matches?status=live&limit=200".format(instance.server_port)
    try:
        with mock.patch.object(cache, "URL", url):
            yield requests
    finally:
        instance.shutdown()
        instance.server_close()
        thread.join()


class CacheTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.env = mock.patch.dict(os.environ, {"XDG_STATE_HOME": self.temporary.name,
                                               "LIVETENNIS_API_KEY": KEY})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.clock = mock.patch.object(cache.time, "time", return_value=1000)
        self.now = self.clock.start()
        self.addCleanup(self.clock.stop)
        self.directory = Path(self.temporary.name) / "tmux-powerkit/livetennis"
        self.state = self.directory / "state.json"

    def success(self, response=None, player=""):
        rows = cache.snapshot(response or payload(), KEY)
        with mock.patch.object(cache, "fetch", return_value=rows) as fetch:
            result = cache.collect(player)
        return result, fetch

    def test_schema_names_player_major_scores_and_nullable_points(self):
        result, fetch = self.success(payload(score={"games": [[6, 3], [4, 4]],
                                                   "points": ["30", None], "server": 1}))
        self.assertIn("Alcaraz vs Sinner 6-4 3-4 (30-?)", result["text"])
        self.assertIn("00:16Z 0m old", result["text"])
        self.assertEqual((result["state"], result["health"], result["count"]), ("active", "ok", 1))
        fetch.assert_called_once_with(KEY)

    def test_absent_and_withheld_scores_stay_unknown(self):
        for score in (None, {}, {"games": None}, {"games": []}):
            self.assertEqual(cache.snapshot(payload(score=score), KEY)[0][0]["score"], "score unavailable")
        missing = {"data": [{"status": "live", "score": None}]}
        self.assertEqual(cache.snapshot(missing, KEY)[0][0]["name1"], "Unknown player")

    def test_players_use_the_documented_p1_and_p2_shape(self):
        value = {"data": [{"status": "live", "player1": {"name": "Wrong"}, "score": None}]}
        rows, partial = cache.snapshot(value, KEY)
        self.assertEqual(rows[0]["name1"], "Unknown player")
        self.assertFalse(partial)

    def test_one_attempt_across_keys_filters_and_the_exact_boundary(self):
        self.success()
        os.environ["LIVETENNIS_API_KEY"] = "different-key"
        self.now.return_value = 1899
        with mock.patch.object(cache, "fetch") as fetch:
            result = cache.collect("sINNeR")
        fetch.assert_not_called()
        self.assertIn("Alcaraz vs Sinner", result["text"])
        self.now.return_value = 1900
        _, fetch = self.success()
        fetch.assert_called_once()
        self.assertEqual(json.loads(self.state.read_text())["attempted_at"], 1900)

    def test_clock_rollback_preserves_the_reservation(self):
        self.success()
        self.now.return_value = 900
        with mock.patch.object(cache, "fetch") as fetch:
            result = cache.collect()
        fetch.assert_not_called()
        self.assertEqual(result["last_attempt"], 1000)
        self.assertEqual(result["state"], "degraded")
        self.assertTrue(result["stale"])

    def test_failed_first_attempt_and_process_reload_do_not_retry(self):
        with mock.patch.object(cache, "fetch", side_effect=OSError(KEY)) as fetch:
            first = cache.collect()
        self.assertEqual(first["state"], "failed")
        self.assertEqual(fetch.call_count, 1)
        reloaded = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(reloaded)
        with mock.patch.object(reloaded, "fetch") as fetch:
            self.assertEqual(reloaded.collect()["last_attempt"], 1000)
        fetch.assert_not_called()
        self.assertNotIn(KEY, self.state.read_text())

    def test_failed_refresh_preserves_previous_snapshot(self):
        self.success()
        self.now.return_value = 1900
        with mock.patch.object(cache, "fetch", side_effect=ValueError("bad response")):
            result = cache.collect()
        self.assertEqual(result["snapshot_at"], 1000)
        self.assertEqual(result["last_attempt"], 1900)
        self.assertIn("Alcaraz vs Sinner", result["text"])
        self.assertIn("stale", result["text"])
        self.assertEqual(result["health"], "warning")
        self.assertEqual(json.loads(self.state.read_text())["last_error"], "request")

    def test_completion_extends_the_floor_after_success_and_failure(self):
        def delayed(key):
            self.now.return_value = 1100
            return cache.snapshot(payload(), key)
        with mock.patch.object(cache, "fetch", side_effect=delayed):
            result = cache.collect()
        self.assertEqual(result["last_attempt"], 1100)
        self.now.return_value = 1999
        with mock.patch.object(cache, "fetch") as fetch:
            cache.collect()
        fetch.assert_not_called()
        self.now.return_value = 2000
        def failure(key):
            self.now.return_value = 2200
            raise OSError("delayed failure")
        with mock.patch.object(cache, "fetch", side_effect=failure):
            result = cache.collect()
        self.assertEqual(result["last_attempt"], 2200)
        self.assertEqual(result["snapshot_at"], 1100)
        self.now.return_value = 3099
        with mock.patch.object(cache, "fetch") as fetch:
            cache.collect()
        fetch.assert_not_called()

    def test_crash_after_reservation_spends_the_attempt(self):
        context = multiprocessing.get_context("fork")
        with mock.patch.object(cache, "fetch", side_effect=lambda key: os._exit(7)):
            process = context.Process(target=cache.collect)
            process.start()
            process.join(5)
        self.assertEqual(process.exitcode, 7)
        self.assertEqual(json.loads(self.state.read_text())["last_error"], "pending")
        with mock.patch.object(cache, "fetch") as fetch:
            self.assertEqual(cache.collect()["last_attempt"], 1000)
        fetch.assert_not_called()

    def test_concurrent_processes_make_one_real_http_request(self):
        context = multiprocessing.get_context("spawn")
        queue = context.Queue()
        with server(json.dumps(payload()).encode(), delay=0.15) as requests:
            processes = [context.Process(target=child_collect, args=(queue, query, cache.URL))
                         for query in ("", "sinner", "Alcaraz", "missing")]
            for process in processes:
                process.start()
            for process in processes:
                process.join(5)
                self.assertEqual(process.exitcode, 0)
            outputs = [queue.get(timeout=2) for _ in processes]
            self.assertEqual(requests, [("/matches?status=live&limit=200", KEY)])
        self.assertTrue(any(output["state"] == "active" for output in outputs))
        self.assertEqual(json.loads(self.state.read_text())["attempted_at"], 1000)
        queue.close()

    def test_busy_lock_returns_prior_snapshot_without_waiting(self):
        self.success()
        self.now.return_value = 1900
        with (self.directory / "quota.lock").open("r+") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            began = time.monotonic()
            with mock.patch.object(cache, "fetch") as fetch:
                result = cache.collect()
            elapsed = time.monotonic() - began
        fetch.assert_not_called()
        self.assertLess(elapsed, 0.5)
        self.assertIn("Alcaraz", result["text"])
        self.assertEqual(result["last_attempt"], 1000)

    def test_corrupt_or_missing_existing_state_never_resets_quota(self):
        self.success()
        for data in ("bad json", "{}", "[]", '{"version":1,"attempted_at":null}'):
            self.state.write_text(data)
            with mock.patch.object(cache, "fetch") as fetch:
                self.assertEqual(cache.collect()["state"], "failed")
            fetch.assert_not_called()
        self.state.unlink()
        with mock.patch.object(cache, "fetch") as fetch:
            self.assertEqual(cache.collect()["state"], "failed")
        fetch.assert_not_called()

    def test_unreadable_state_prevents_fetch(self):
        with mock.patch.object(cache, "read_state", side_effect=PermissionError()), \
                mock.patch.object(cache, "fetch") as fetch:
            self.assertEqual(cache.collect()["state"], "failed")
        fetch.assert_not_called()

    def test_missing_fields_and_invalid_timestamps_fail_without_fetch(self):
        self.success()
        valid = json.loads(self.state.read_text())
        damaged = [dict((k, v) for k, v in valid.items() if k != field) for field in valid]
        for field in ("attempted_at", "snapshot_at"):
            for value in (10 ** 1000, -1, True, float("inf"), "1000"):
                damaged.append(dict(valid, **{field: value}))
        damaged.append(dict(valid, version=True))
        for state in damaged:
            with self.subTest(state=state):
                self.state.write_text(json.dumps(state))
                with mock.patch.object(cache, "fetch") as fetch:
                    result = cache.collect()
                fetch.assert_not_called()
                self.assertEqual(result["state"], "failed")
                self.assertIsNone(result["snapshot_at"])

    def test_file_fsync_failure_prevents_http(self):
        with mock.patch.object(cache.os, "fsync", side_effect=OSError()), \
                mock.patch.object(cache, "fetch") as fetch:
            result = cache.collect()
        fetch.assert_not_called()
        self.assertEqual(result["state"], "failed")

    def test_directory_fsync_failure_prevents_http(self):
        original = cache.os.fsync
        def sync(descriptor):
            if stat.S_ISDIR(os.fstat(descriptor).st_mode):
                raise OSError("directory sync failed")
            original(descriptor)
        with mock.patch.object(cache.os, "fsync", side_effect=sync), \
                mock.patch.object(cache, "fetch") as fetch:
            cache.collect()
        fetch.assert_not_called()
        self.assertEqual(json.loads(self.state.read_text())["attempted_at"], 1000)
        with mock.patch.object(cache, "fetch") as fetch:
            cache.collect()
        fetch.assert_not_called()

    def test_private_permissions_and_stable_lock_inode(self):
        self.success()
        lock = self.directory / "quota.lock"
        inode = lock.stat().st_ino
        self.now.return_value = 1900
        self.success()
        self.assertEqual(lock.stat().st_ino, inode)
        self.assertEqual(stat.S_IMODE(self.directory.stat().st_mode), 0o700)
        for path in (self.state, lock):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_symlink_state_is_refused(self):
        self.success()
        self.state.unlink()
        target = Path(self.temporary.name) / "elsewhere"
        target.write_text("{}"); self.state.symlink_to(target)
        with mock.patch.object(cache, "fetch") as fetch:
            self.assertEqual(cache.collect()["state"], "failed")
        fetch.assert_not_called()
        self.assertEqual(target.read_text(), "{}")

    def test_missing_key_never_reads_a_cached_snapshot(self):
        self.success()
        del os.environ["LIVETENNIS_API_KEY"]
        with mock.patch.object(cache, "read_state") as read, mock.patch.object(cache, "fetch") as fetch:
            result = cache.collect()
        read.assert_not_called(); fetch.assert_not_called()
        self.assertFalse(result["configured"])
        self.assertIsNone(result["snapshot_at"])
        self.assertNotIn("Alcaraz", result["text"])

    def test_invalid_header_keys_are_not_sent_or_displayed(self):
        for key in ("secret\nvalue", "secret\rvalue", "secret\x00value", "secret value", "\u200dsecret"):
            environment = dict(os.environ, LIVETENNIS_API_KEY=key)
            with mock.patch.object(cache.os, "environ", environment), mock.patch.object(cache, "fetch") as fetch:
                result = cache.collect()
            fetch.assert_not_called()
            self.assertNotIn(key, json.dumps(result))
            self.assertEqual(result["state"], "failed")

    def test_partial_metadata_and_limit_do_not_fetch_more_pages(self):
        for metadata in ({"has_more": True}, {"total": 2}, {"has_more": False, "total": 2}):
            self.assertTrue(cache.snapshot(payload(**metadata), KEY)[1])
        page = {"data": payload()["data"] * 200, "meta": {"has_more": False, "total": 200}}
        result, fetch = self.success(page)
        fetch.assert_called_once()
        self.assertTrue(result["partial"])
        self.assertIn("200 live", result["text"])
        self.assertIn("partial", result["text"])

    def test_local_filter_uses_casefold_and_selects_first_match(self):
        page = {"data": payload("Straße", "One")["data"] + payload("STRASSE", "Two")["data"]}
        first, _ = self.success(page, "strasse")
        self.assertIn("Straße vs One", first["text"])
        with mock.patch.object(cache, "fetch") as fetch:
            other = cache.collect("No player")
        fetch.assert_not_called()
        self.assertIn("No matching live matches", other["text"])
        self.assertEqual(other["count"], 2)

    def test_filter_can_match_after_the_rendered_name_limit(self):
        name = "Long player name " * 3 + "Distinct surname"
        result, _ = self.success(payload(name, "Other"), "distinct SURNAME")
        self.assertNotIn("No matching", result["text"])
        self.assertEqual(json.loads(self.state.read_text())["rows"][0]["name1"], name)
        self.assertLess(len(result["text"]), 200)

    def test_snapshot_age_is_distinct_from_stale_score_content(self):
        result, _ = self.success(payload(score={"games": [[6], [4]], "stale": True}))
        self.assertIn("(score stale)", result["text"])
        self.assertIn("snapshot 00:16Z 0m old", result["text"])

    def test_deciding_match_tiebreak_is_marked_as_documented(self):
        result, _ = self.success(payload(score={"games": [[6, 4, 10], [4, 6, 5]],
                                               "is_tiebreak": True}))
        self.assertIn("6-4 4-6 10-5 (tiebreak)", result["text"])

    def test_empty_success_and_nonlive_rows(self):
        page = {"data": [{"status": "completed", "score": None}], "meta": {"has_more": False}}
        result, _ = self.success(page)
        self.assertIn("No live matches", result["text"])
        self.assertEqual(result["state"], "active")
        self.assertEqual(result["count"], 0)

    def test_malformed_responses_are_not_cached_as_empty_success(self):
        invalid = [[], {}, {"data": {}}, {"data": [None]}, {"data": [{}]},
                   {"data": [{"status": True}]}, {"data": [{"status": "unknown"}]}, payload(has_more="true"),
                   payload(total=True), payload(score={"games": [[6], [4, 4]]}),
                   payload(score={"games": [[True], [4]]}), payload(score={"server": 3}),
                   payload(score={"games": [[6], [4]], "points": ["40"]}),
                   {"data": payload()["data"] * 201}]
        for value in invalid:
            with self.assertRaises(ValueError):
                cache.snapshot(value, KEY)

    def test_malformed_status_does_not_replace_a_previous_snapshot(self):
        self.success()
        self.now.return_value = 1900
        with mock.patch.object(cache, "fetch", side_effect=lambda key: cache.snapshot({"data": [{}]}, key)):
            result = cache.collect()
        self.assertIn("Alcaraz vs Sinner", result["text"])
        self.assertEqual(result["snapshot_at"], 1000)
        self.assertEqual(result["health"], "warning")

    def test_secret_redaction_and_tmux_text_sanitization(self):
        name = KEY + "\n\x1b#(danger)|#{session_name}\u200d" + "x" * 300
        result, _ = self.success(payload(name, "Sinner|other"))
        for value in (result["text"], result["context"], self.state.read_text()):
            self.assertNotIn(KEY, value)
            self.assertNotIn("#", value)
            self.assertNotIn("|", value)
            self.assertNotIn("\x1b", value)
        self.assertLess(len(result["text"]), 200)
        self.assertEqual(sorted(p.name for p in self.directory.iterdir()), ["quota.lock", "state.json"])

    def test_redirects_are_not_followed_or_retried(self):
        with server(b"", status=302, redirect=True) as requests:
            result = cache.collect()
            cache.collect()
            self.assertEqual(requests, [("/matches?status=live&limit=200", KEY)])
        self.assertEqual(result["state"], "failed")

    def test_rejected_http_response_body_is_closed(self):
        body = io.BytesIO(b"request denied")
        error = cache.urllib.error.HTTPError(cache.URL, 403, "Denied", {}, body)
        opener = mock.Mock()
        opener.open.side_effect = error
        with mock.patch.object(cache.urllib.request, "build_opener", return_value=opener):
            with self.assertRaises(cache.urllib.error.HTTPError):
                cache.fetch(KEY)
        self.assertTrue(body.closed)
        self.assertEqual(opener.open.call_args[1]["timeout"], 8)

    def test_response_body_cap(self):
        with server(json.dumps(payload()).encode() + b" " * cache.MAX_BYTES) as requests:
            result = cache.collect()
        self.assertEqual(len(requests), 1)
        self.assertEqual(result["state"], "failed")
        self.assertIsNone(json.loads(self.state.read_text())["snapshot_at"])

    def test_truncated_chunked_body_preserves_snapshot_and_spends_attempt(self):
        self.success()
        self.now.return_value = 1900
        with server(b"10\r\nshort", chunked=True) as requests:
            result = cache.collect()
            cache.collect()
        self.assertEqual(len(requests), 1)
        self.assertEqual(result["snapshot_at"], 1000)
        self.assertEqual(result["last_attempt"], 1900)
        self.assertEqual(result["health"], "warning")
        self.assertEqual(json.loads(self.state.read_text())["last_error"], "request")

    def test_real_http_success_and_malformed_body_keep_secret_out_of_output(self):
        with server(json.dumps(payload()).encode()) as requests:
            result = cache.collect()
        self.assertEqual(len(requests), 1)
        self.assertEqual(result["health"], "ok")
        self.now.return_value = 1900
        with server(KEY.encode()) as requests, contextlib.redirect_stderr(io.StringIO()) as stderr:
            result = cache.collect()
        self.assertEqual(len(requests), 1)
        self.assertNotIn(KEY, json.dumps(result))
        self.assertEqual(stderr.getvalue(), "")
        self.assertEqual(result["health"], "warning")

    def test_cli_returns_successful_json_for_handled_errors_and_leading_dash_filter(self):
        self.success()
        self.state.write_text("corrupt")
        result = subprocess.run([sys.executable, str(HELPER), "--player=-dash"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stderr, "")
        self.assertNotIn(KEY, result.stdout)
        self.assertEqual(json.loads(result.stdout)["state"], "failed")


if __name__ == "__main__":
    unittest.main()
