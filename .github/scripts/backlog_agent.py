#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys


def send(proc, msg):
    proc.stdin.write(json.dumps(msg) + "\n")
    proc.stdin.flush()


def recv(proc, expected_id):
    while True:
        line = proc.stdout.readline()
        if not line:
            return None
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "id" in msg and msg["id"] == expected_id:
            return msg


def call_tool(proc, msg_id, name, args):
    send(proc, {
        "jsonrpc": "2.0",
        "id": msg_id,
        "method": "tools/call",
        "params": {"name": name, "arguments": args},
    })
    return recv(proc, msg_id)


def text_of(resp):
    if resp is None:
        return None
    result = resp.get("result", {})
    if result.get("isError"):
        return None
    for item in result.get("content", []):
        if item.get("type") == "text":
            return item["text"]
    return None


def main():
    binary   = os.environ["BACKLOG_MCP_BIN"]
    root     = os.environ.get("BACKLOG_ROOT", "requirements")
    pr_num   = os.environ.get("PR_NUMBER", "")
    pr_title = os.environ.get("PR_TITLE", "")
    pr_branch = os.environ.get("PR_BRANCH", "")
    pr_action = os.environ.get("PR_ACTION", "")

    ids = {m.upper() for m in re.findall(r"STORY-\d+", pr_title + " " + pr_branch, re.I)}
    if not ids:
        print("No STORY-NNN IDs found in PR title or branch — nothing to do.")
        return 0

    print(f"Matched: {', '.join(sorted(ids))}")

    proc = subprocess.Popen(
        [binary],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=sys.stderr, text=True,
        env={**os.environ, "BACKLOG_ROOT": root},
    )

    try:
        send(proc, {
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "pr-backlog-agent", "version": "1.0"},
            },
        })
        recv(proc, 1)
        send(proc, {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})

        raw = text_of(call_tool(proc, 2, "list_stories", {}))
        stories = {s["story_id"]: s for s in (json.loads(raw) if raw else [])}

        mid = 3
        for story_id in sorted(ids):
            if story_id not in stories:
                print(f"{story_id}: not in index, skipping.")
                continue

            if pr_action == "opened" and stories[story_id]["status"] == "draft":
                call_tool(proc, mid, "set_story_status",
                          {"story_id": story_id, "status": "in-progress"})
                mid += 1
                print(f"{story_id}: → in-progress")

            call_tool(proc, mid, "add_story_note",
                      {"story_id": story_id, "note": f"PR #{pr_num}: {pr_title}"})
            mid += 1
            print(f"{story_id}: note added")

    finally:
        proc.stdin.close()
        proc.wait()

    return 0


if __name__ == "__main__":
    sys.exit(main())
