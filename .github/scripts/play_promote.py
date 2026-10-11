#!/usr/bin/env python3
"""Promote the tested release candidate from a Play testing track to production.

    play_promote.py find    1.9.0   # print the rc tag on the testing track
    play_promote.py promote 1.9.0   # move that rc to production, 100 %

Production never gets a fresh build: it gets the exact bundle testers ran.
The candidate is the release on the testing track named `v1.9.0-rc.N`
(the release workflow names each upload after its tag); with several, the
highest N wins. No candidate is an error, so a version that skipped testing
cannot reach production.

`promote` reuses the candidate's version codes, release notes and in-app
update priority, names the production release `v1.9.0`, and commits the edit,
which sends it to Google's review. With managed publishing off in Play
Console, it goes live as soon as review passes.

Credentials come from Application Default Credentials — in CI the
Workload Identity Federation file google-github-actions/auth exports via
GOOGLE_APPLICATION_CREDENTIALS, locally `gcloud auth application-default
login` as an account with Play access.

Environment: PACKAGE_NAME, and optionally FROM_TRACK (default alpha) and
GITHUB_OUTPUT (gets rc_tag=...).
"""

import os
import re
import sys

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
LIVE_STATUSES = {"completed", "inProgress"}


def pick_candidate(track: dict, version: str) -> dict | None:
    """The live `v<version>-rc.N` release with the highest N, if any."""
    pattern = re.compile(rf"^v{re.escape(version)}-rc\.(\d+)$")
    best, best_n = None, -1
    for release in track.get("releases", []):
        match = pattern.match(release.get("name", ""))
        if not match or release.get("status") not in LIVE_STATUSES:
            continue
        n = int(match.group(1))
        if n > best_n:
            best, best_n = release, n
    return best


def production_release(candidate: dict, version: str) -> dict:
    release = {
        "name": f"v{version}",
        "versionCodes": candidate["versionCodes"],
        "status": "completed",
    }
    for key in ("releaseNotes", "inAppUpdatePriority"):
        if key in candidate:
            release[key] = candidate[key]
    return release


class Play:
    def __init__(self, package: str):
        import google.auth
        import google.auth.transport.requests
        import requests

        creds, _ = google.auth.default(scopes=[SCOPE])
        creds.refresh(google.auth.transport.requests.Request())
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bearer {creds.token}"
        self.base = f"{API}/{package}/edits"

    def call(self, method: str, path: str = "", **kwargs) -> dict:
        response = self.session.request(method, self.base + path, **kwargs)
        if not response.ok:
            raise SystemExit(
                f"{method} {path or '/edits'} -> {response.status_code}\n{response.text}"
            )
        return response.json() if response.content else {}


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[0] not in ("find", "promote"):
        print(__doc__, file=sys.stderr)
        return 2
    mode, version = argv
    from_track = os.environ.get("FROM_TRACK", "alpha")

    play = Play(os.environ["PACKAGE_NAME"])
    edit_id = play.call("POST")["id"]
    track = play.call("GET", f"/{edit_id}/tracks/{from_track}")
    candidate = pick_candidate(track, version)
    if candidate is None:
        names = [r.get("name") for r in track.get("releases", [])]
        print(
            f"No live v{version}-rc.N release on '{from_track}' (found: {names}). "
            f"Push a v{version}-rc.N tag and let testers run it first.",
            file=sys.stderr,
        )
        play.call("DELETE", f"/{edit_id}")
        return 1

    rc_tag = candidate["name"]
    print(f"candidate: {rc_tag} versionCodes={candidate['versionCodes']}")
    if output := os.environ.get("GITHUB_OUTPUT"):
        with open(output, "a", encoding="utf-8") as f:
            f.write(f"rc_tag={rc_tag}\n")

    if mode == "find":
        play.call("DELETE", f"/{edit_id}")
        return 0

    release = production_release(candidate, version)
    play.call(
        "PUT",
        f"/{edit_id}/tracks/production",
        json={"track": "production", "releases": [release]},
    )
    play.call("POST", f"/{edit_id}:commit")
    print(f"promoted {rc_tag} to production as v{version} (100 %), sent for review")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
