#!/usr/bin/env python3
"""cognee — CLI client for the shared agent memory at cognee.otwell.dev.

Stdlib only (urllib), so it runs on any corpus host without extra deps.
Auth: X-Api-Key from $COGNEE_API_KEY or /run/secrets/cognee-api-key.
Endpoint: $COGNEE_URL (default https://cognee.otwell.dev).

Usage:
  cognee remember "fact or longer text"        # ingest + build graph (blocks)
  cognee remember --bg "text"                  # background ingest (returns run id)
  cognee remember --file notes.md [--file ...] # upload files
  cognee remember --dataset work "..."         # target a dataset
  cognee recall "question"                     # auto-routed query, brief answer
  cognee recall --context "question"           # retrieval only, no LLM answer
  cognee recall --datasets work,home "..."     # restrict datasets
  cognee status                                # /health + dataset status
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_URL = "https://cognee.otwell.dev"
KEY_FILE = "/run/secrets/cognee-api-key"


def base_url():
    return os.environ.get("COGNEE_URL", DEFAULT_URL).rstrip("/")


def api_key():
    key = os.environ.get("COGNEE_API_KEY", "").strip()
    if key:
        return key
    try:
        return Path(KEY_FILE).read_text().strip()
    except OSError:
        sys.exit(
            f"cognee: no API key — set $COGNEE_API_KEY or provision {KEY_FILE} "
            "(sops secret `cognee-api-key`)"
        )


def request(
    method: str,
    path: str,
    *,
    json_body=None,
    form_fields=None,
    files=None,
    timeout=900,
):
    """One HTTP call. json_body → application/json; form_fields/files → multipart."""
    url = base_url() + path
    headers = {"X-Api-Key": api_key()}
    data = None

    if json_body is not None:
        data = json.dumps(json_body).encode()
        headers["Content-Type"] = "application/json"
    elif form_fields or files:
        boundary = "cognee-cli-boundary-7351"
        parts = []
        for name, value in (form_fields or {}).items():
            parts.append(
                f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"'
                f"\r\n\r\n{value}\r\n".encode()
            )
        for name, (filename, blob) in (files or {}).items():
            parts.append(
                (
                    f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; '
                    f'filename="{filename}"\r\nContent-Type: application/octet-stream'
                    f"\r\n\r\n"
                ).encode()
                + blob
                + b"\r\n"
            )
        parts.append(f"--{boundary}--\r\n".encode())
        data = b"".join(parts)
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode()
            return json.loads(body) if body.strip() else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:500]
        sys.exit(f"cognee: HTTP {e.code} on {method} {path}\n{detail}")
    except urllib.error.URLError as e:
        sys.exit(f"cognee: cannot reach {url}: {e.reason}")


def cmd_remember(args):
    fields = {"datasetName": args.dataset}
    if args.bg:
        fields["run_in_background"] = "true"
    files = {}
    if args.file:
        for i, path in enumerate(args.file):
            blob = Path(path).read_bytes()
            files[f"data{i}"] = (Path(path).name, blob)
    elif args.text:
        fields["raw_data"] = args.text
    else:
        sys.exit("cognee remember: pass text or --file")
    result = request("POST", "/api/v1/remember", form_fields=fields, files=files)
    print(json.dumps(result, indent=2)[:2000])


def cmd_recall(args):
    body = {"query": args.query}
    if args.context:
        body["only_context"] = True
    if args.datasets:
        body["datasets"] = [d.strip() for d in args.datasets.split(",")]
    results = request("POST", "/api/v1/recall", json_body=body)
    if not isinstance(results, list):
        print(json.dumps(results, indent=2)[:2000])
        return
    for r in results:
        text = r.get("text") or r.get("answer") or json.dumps(r)[:300]
        print(text)
        if args.verbose:
            print(json.dumps(r, indent=2)[:1500])
            print("-" * 60)


def cmd_status(args):
    health = request("GET", "/health", timeout=15)
    print("health:", json.dumps(health))
    status = request("GET", "/api/v1/datasets/status", timeout=60)
    print("datasets:", json.dumps(status, indent=2)[:2000])


def main():
    parser = argparse.ArgumentParser(
        prog="cognee", description="CLI client for the shared agent memory (cognee.otwell.dev)"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("remember", help="ingest text/files and build the graph")
    p.add_argument("text", nargs="?", help="text to remember")
    p.add_argument("--file", action="append", help="file to upload (repeatable)")
    p.add_argument("--dataset", default="agent_memory", help="target dataset")
    p.add_argument("--bg", action="store_true", help="run in background")
    p.set_defaults(fn=cmd_remember)

    p = sub.add_parser("recall", help="query memory")
    p.add_argument("query")
    p.add_argument("--context", action="store_true", help="retrieval only, no LLM answer")
    p.add_argument("--datasets", help="comma-separated dataset names")
    p.add_argument("--verbose", action="store_true")
    p.set_defaults(fn=cmd_recall)

    p = sub.add_parser("status", help="health + dataset status")
    p.set_defaults(fn=cmd_status)

    args = parser.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
