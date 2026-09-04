#!/usr/bin/env python3
"""
SCADA / PI Bridge — Reference POC (Phase 5)

Polls OSIsoft/AVEVA PI Web API for stream snapshots/interpolated values, shapes each
reading into the SCADA envelope, signs the exact request body with HMAC-SHA256, and
POSTs it to the Salesforce SCADA ingestion endpoint.

This is a *reference implementation* to show the on-prem operator the full loop:
    poll PI Web API  ->  build readings[]  ->  sign raw body  ->  POST
Only stdlib is required (no pip installs). Adapt the PI Web API calls to your
site's AF server/webId layout.

Usage:
    cp scada_bridge.env.example scada_bridge.env   # then fill in values
    python bridge_poc.py                            # single poll + send cycle
"""

import hashlib
import hmac
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.environ.get("SCADA_BRIDGE_ENV", os.path.join(BASE_DIR, "scada_bridge.env"))

CHUNK_SIZE = 5000  # must stay in sync with SCADAIngestionAPI.CHUNK_SIZE
INTERVAL_MINUTES = 10  # poll cadence


def load_env(path: str) -> dict:
    env = {}
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            env[key.strip()] = val.strip()
    return env


def sign_body(body_bytes: bytes, secret: str) -> str:
    """hex(HMAC-SHA256(raw body bytes, secret)) -- must match receiver exactly."""
    return hmac.new(secret.encode("utf-8"), body_bytes, hashlib.sha256).hexdigest()


def post_measurements(env: dict, readings: list) -> tuple:
    """POSTs the readings envelope, returning (http_status, parsed_response)."""
    payload = {"readings": readings}
    body = json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    sig = sign_body(body, env["SCADA_SHARED_SECRET"])

    headers = {
        "Content-Type": "application/json",
        "X-SCADA-Signature": sig,
    }
    # The org has no public guest site, so an authenticated bearer token is required.
    token = env.get("SCADA_ACCESS_TOKEN", "")
    if token:
        headers["Authorization"] = "Bearer " + token

    req = urllib.request.Request(
        env["SCADA_ENDPOINT"],
        data=body,
        method="POST",
        headers=headers,
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        detail = err.read().decode("utf-8", errors="replace")
        return err.code, {"error": detail}
    except urllib.error.URLError as err:
        return None, {"error": str(err.reason)}


def poll_pi_streams(env: dict) -> list:
    """
    Placeholder PI Web API poller.

    Per tag, request interpolated values since the last run:
        GET {PIWEBAPI_URL}/streams/{webId}/interpolated?startTime=-20m&endTime=now&interval=1m

    Returns a list of raw stream values {tag, timestamp, value}. Replace this body with
    real PI Web API calls (Basic auth via PIWEBAPI_USER/PIWEBAPI_PASS) keyed to your AF
    element/webIds. The final shape (`readings[]`) is what matters to the receiver.
    """
    # Example static demo data so the POC runs end-to-end without a live PI system.
    now = datetime.utcnow()
    return [
        {
            "tag": "WELL-TEST.OIL_FLOW",
            "timestamp": (now - timedelta(minutes=90)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "value": 100,
            "measurementType": "Oil Flow",
        },
        {
            "tag": "WELL-TEST.GAS_FLOW",
            "timestamp": (now - timedelta(minutes=90)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "value": 40,
            "measurementType": "Gas Flow",
        },
    ]


def main() -> None:
    if not os.path.exists(ENV_FILE):
        raise SystemExit(f"Env file not found: {ENV_FILE} (copy scada_bridge.env.example first)")

    env = load_env(ENV_FILE)
    if not env.get("SCADA_SHARED_SECRET") or not env.get("SCADA_ENDPOINT"):
        raise SystemExit("SCADA_SHARED_SECRET / SCADA_ENDPOINT must be set in the env file.")

    readings = poll_pi_streams(env)
    if not readings:
        print("No readings to send.")
        return

    # Chunk to <=5000 readings per request (receiver can take more but stays tidy).
    for i in range(0, len(readings), CHUNK_SIZE):
        chunk = readings[i : i + CHUNK_SIZE]
        status, resp = post_measurements(env, chunk)
        print(f"status={status} chunk {i // CHUNK_SIZE + 1} readings={len(chunk)}")
        print(json.dumps(resp, indent=2))


if __name__ == "__main__":
    main()
