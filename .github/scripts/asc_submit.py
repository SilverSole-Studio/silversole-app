#!/usr/bin/env python3
"""Submit the tested TestFlight build of a version to App Store review.

    asc_submit.py 1.9.0 BUILD_NUMBER WHATSNEW_DIR

The iOS counterpart of `play_promote.py promote`: the App Store never gets a
fresh build either. Every v1.9.0-rc.N run uploads an IPA to TestFlight with
the run number as its build number, the same number as that run's Android
version code. Given the version code of the rc that `play_promote.py find`
picked, this script:

1. finds that build (version 1.9.0, build BUILD_NUMBER) and waits until Apple
   has finished processing it;
2. finds or creates the 1.9.0 App Store version, set to release as soon as
   review passes (like Play, which goes live on approval);
3. writes "What's New" for every localization from WHATSNEW_DIR (the
   whatsnew-zh-TW / whatsnew-en-US files play_whatsnew.py makes): zh-Hant
   and zh-TW get the Chinese text, every other language the English one;
4. attaches the build and submits the version for review.

A version that is already waiting for or in review, or already approved,
is left alone (re-running the workflow is safe).

Credentials: an App Store Connect Team API key, the same one the TestFlight
upload uses. Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (the .p8
file) and BUNDLE_ID.
"""

import os
import pathlib
import sys
import time

import jwt
import requests

API = "https://api.appstoreconnect.apple.com/v1"
# States where the version is already on its way; submitting again would fail.
SUBMITTED = {
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "PENDING_DEVELOPER_RELEASE",
    "PENDING_APPLE_RELEASE",
    "PROCESSING_FOR_APP_STORE",
    "READY_FOR_SALE",
    "READY_FOR_DISTRIBUTION",
}
EDITABLE = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}
WAIT_PROCESSING_S = 45 * 60


class Asc:
    def __init__(self, key_id: str, issuer: str, key_path: str):
        self.key_id = key_id
        self.issuer = issuer
        self.key = pathlib.Path(key_path).read_text()
        self.token = ""
        self.token_exp = 0

    def headers(self) -> dict:
        now = int(time.time())
        if now > self.token_exp - 60:
            self.token_exp = now + 15 * 60  # Apple's maximum is 20 minutes
            self.token = jwt.encode(
                {"iss": self.issuer, "iat": now, "exp": self.token_exp, "aud": "appstoreconnect-v1"},
                self.key,
                algorithm="ES256",
                headers={"kid": self.key_id, "typ": "JWT"},
            )
        return {"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"}

    def call(self, method: str, path: str, **kwargs) -> dict:
        r = requests.request(method, API + path, headers=self.headers(), timeout=60, **kwargs)
        if r.status_code >= 400:
            raise SystemExit(f"{method} {path} -> {r.status_code}: {r.text}")
        return r.json() if r.content else {}


def whats_new(directory: pathlib.Path) -> tuple[str, str]:
    zh = (directory / "whatsnew-zh-TW").read_text(encoding="utf-8").strip()
    en = (directory / "whatsnew-en-US").read_text(encoding="utf-8").strip()
    return zh, en


def find_build(asc: Asc, app_id: str, version: str, build_number: str) -> str:
    deadline = time.time() + WAIT_PROCESSING_S
    while True:
        data = asc.call(
            "GET",
            "/builds",
            params={
                "filter[app]": app_id,
                "filter[version]": build_number,
                "filter[preReleaseVersion.version]": version,
                "fields[builds]": "version,processingState,expired",
            },
        )["data"]
        if data:
            build = data[0]
            state = build["attributes"]["processingState"]
            if build["attributes"].get("expired"):
                raise SystemExit(f"Build {version} ({build_number}) has expired in TestFlight.")
            if state == "VALID":
                return build["id"]
            if state in ("FAILED", "INVALID"):
                raise SystemExit(f"Build {version} ({build_number}) is {state}; push a new rc.")
            print(f"build {version} ({build_number}) is {state}, waiting")
        else:
            print(f"build {version} ({build_number}) not in App Store Connect yet, waiting")
        if time.time() > deadline:
            raise SystemExit(
                f"Build {version} ({build_number}) was not ready within {WAIT_PROCESSING_S // 60} min. "
                "Re-run this job once TestFlight shows it."
            )
        time.sleep(60)


def find_or_create_version(asc: Asc, app_id: str, version: str) -> tuple[str, str]:
    data = asc.call(
        "GET",
        f"/apps/{app_id}/appStoreVersions",
        params={"filter[platform]": "IOS", "filter[versionString]": version},
    )["data"]
    if data:
        v = data[0]
        return v["id"], v["attributes"]["appStoreState"]
    v = asc.call(
        "POST",
        "/appStoreVersions",
        json={
            "data": {
                "type": "appStoreVersions",
                "attributes": {"platform": "IOS", "versionString": version, "releaseType": "AFTER_APPROVAL"},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
    )["data"]
    print(f"created App Store version {version}")
    return v["id"], v["attributes"]["appStoreState"]


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    version, build_number, notes_dir = argv[1], argv[2], pathlib.Path(argv[3])
    zh, en = whats_new(notes_dir)
    asc = Asc(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"])

    apps = asc.call("GET", "/apps", params={"filter[bundleId]": os.environ["BUNDLE_ID"]})["data"]
    if not apps:
        raise SystemExit(f"No app with bundle id {os.environ['BUNDLE_ID']} in App Store Connect.")
    app_id = apps[0]["id"]

    version_id, state = find_or_create_version(asc, app_id, version)
    if state in SUBMITTED:
        print(f"App Store version {version} is already {state}; nothing to do")
        return 0
    if state not in EDITABLE:
        raise SystemExit(f"App Store version {version} is {state}; check App Store Connect.")

    build_id = find_build(asc, app_id, version, build_number)

    asc.call(
        "PATCH",
        f"/appStoreVersions/{version_id}",
        json={"data": {"type": "appStoreVersions", "id": version_id, "attributes": {"releaseType": "AFTER_APPROVAL"}}},
    )
    for loc in asc.call("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]:
        locale = loc["attributes"]["locale"]
        text = zh if locale.startswith("zh") else en
        asc.call(
            "PATCH",
            f"/appStoreVersionLocalizations/{loc['id']}",
            json={"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": text}}},
        )
        print(f"what's new set for {locale}")

    asc.call(
        "PATCH",
        f"/appStoreVersions/{version_id}/relationships/build",
        json={"data": {"type": "builds", "id": build_id}},
    )
    print(f"attached build {build_number}")

    # A run that stopped half way leaves an unsubmitted submission behind; reuse it.
    open_subs = asc.call(
        "GET",
        "/reviewSubmissions",
        params={"filter[app]": app_id, "filter[platform]": "IOS", "filter[state]": "READY_FOR_REVIEW"},
    )["data"]
    if open_subs:
        submission = open_subs[0]
    else:
        submission = asc.call(
            "POST",
            "/reviewSubmissions",
            json={
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": "IOS"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )["data"]
    items = asc.call("GET", f"/reviewSubmissions/{submission['id']}/items", params={"include": "appStoreVersion"})["data"]
    has_version = any(
        (i.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id") == version_id for i in items
    )
    if not has_version:
        asc.call(
            "POST",
            "/reviewSubmissionItems",
            json={
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                    },
                }
            },
        )
    asc.call(
        "PATCH",
        f"/reviewSubmissions/{submission['id']}",
        json={"data": {"type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}}},
    )
    print(f"submitted {version} ({build_number}) for App Store review; releases on approval")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
