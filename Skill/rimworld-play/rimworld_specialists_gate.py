# PreToolUse hook (Bash / PowerShell), the RimWorld play session only, the orchestrator only (a call with agent_id is a
# specialist's own and always runs). User, 2026-10-22: "Hook: blocks unpause after compaction. hook does not lift until:
# 8 subagents have been spawned in session. Hook also blocks from orchestrator from playing unless: 8 subagents are
# actually working in a session." Picked: "8 always" (hostile_watch counts too), "Every game order" (send.ps1, play.ps1,
# vote.ps1), working = not ended.
#   - Read from the play session's own transcript, in order (meta.json flags stay set after an agent goes on, seen in
#     session 398f777b on 2026-10-22):
#     launch: the Agent tool_result "Async agent launched" with its agentId; the role comes from the Agent description.
#     end: a task-notification with status completed / killed / failed. "is waiting on its own background work" is not
#     an end (the agent goes on by itself).
#     resume: a SendMessage to the agentId makes it working again.
#     compaction: the last compact_boundary line.
#   - Fewer than 8 roles working: every game order is refused (exit 2).
#   - After a compaction, an unpause order (speed / normal / unpause) also needs all 8 roles launched after it.
import json
import os
import re
import sys

PLAY_LOG = os.path.join(os.path.expanduser("~"), ".claude", "projects", "RimWorld-LLM-Integration",
                        "agent_player", "play_sessions")
ROLES = [("schedule", "schedule"), ("work_priority", "work.?priority"), ("drafter_mover", "draft"),
         ("equipment_config", "equipment"), ("bills", "bill"), ("storage_zones", "storage"),
         ("hostile_watch", "hostile"), ("expediter", "expedit")]
GAME = re.compile(r"(?i)\b(send|play|vote)\.ps1\b")
UNPAUSE = re.compile(r"(?i)\b(speed|normal|unpause)\b")
NOTIF = re.compile(r"<task-notification>.*?</task-notification>", re.S)
KEYS = ('"name":"Agent"', "Async agent launched", "task-notification", '"name":"SendMessage"', "compact_boundary")


def play_session(data):
    if os.environ.get("RIMWORLD_PLAY") == "1":
        return True
    marker = os.path.join(PLAY_LOG, "active_session.txt")
    try:
        with open(marker, encoding="utf-8-sig") as f:
            return str(data.get("session_id") or "") == f.readline().strip()
    except OSError:
        return False


def role_of(desc):
    d = (desc or "").lower()
    for name, pat in ROLES:
        if re.search(pat, d):
            return name
    return None


def texts(content):
    if isinstance(content, str):
        return [content]
    out = []
    if isinstance(content, list):
        for x in content:
            if not isinstance(x, dict):
                continue
            if isinstance(x.get("text"), str):
                out.append(x["text"])
            if "content" in x:
                out.extend(texts(x["content"]))
    return out


def scan(path):
    desc = {}        # Agent tool_use id -> description
    role = {}        # agentId -> role
    working = {}     # agentId -> bool
    launched = []    # (line number, role)
    boundary = -1
    seen = set()     # task-notifications are written several times (queue, attachment, user line): once each
    with open(path, encoding="utf-8", errors="replace") as f:
        for n, line in enumerate(f):
            if not any(k in line for k in KEYS):
                continue
            try:
                o = json.loads(line)
            except ValueError:
                continue
            t = o.get("type")
            if o.get("subtype") == "compact_boundary":
                boundary = n
                continue
            if t == "api-request-blob":
                continue
            msg = o.get("message") or {}
            content = msg.get("content")
            if t == "assistant" and isinstance(content, list):
                for x in content:
                    if not isinstance(x, dict) or x.get("type") != "tool_use":
                        continue
                    inp = x.get("input") or {}
                    if x.get("name") == "Agent":
                        desc[x.get("id")] = inp.get("description", "")
                    elif x.get("name") == "SendMessage":
                        to = str(inp.get("to") or "")
                        if to in role:
                            working[to] = True
                continue
            parts = []
            if t == "queue-operation" and o.get("operation") == "enqueue":
                parts = [str(o.get("content") or "")]
            elif t == "attachment":
                parts = [str((o.get("attachment") or {}).get("prompt") or "")]
            elif t == "user":
                if isinstance(content, list):
                    for x in content:
                        if isinstance(x, dict) and x.get("type") == "tool_result":
                            body = "\n".join(texts(x.get("content")))
                            m = re.search(r"Async agent launched.*?agentId:\s*([A-Za-z0-9]+)", body, re.S)
                            if m and x.get("tool_use_id") in desc:
                                r = role_of(desc[x.get("tool_use_id")])
                                if r:
                                    role[m.group(1)] = r
                                    working[m.group(1)] = True
                                    launched.append((n, r))
                parts = texts(content)
            for p in parts:
                for block in NOTIF.findall(p):
                    if block in seen:
                        continue
                    seen.add(block)
                    tid = re.search(r"<task-id>\s*([A-Za-z0-9]+)\s*</task-id>", block)
                    st = re.search(r"<status>\s*(\w+)\s*</status>", block)
                    if not tid or not st or tid.group(1) not in role:
                        continue
                    if "waiting on its own background work" in block:
                        continue
                    if st.group(1).lower() in ("completed", "killed", "failed"):
                        working[tid.group(1)] = False
    now = {role[a] for a, w in working.items() if w}
    since = {r for n, r in launched if n > boundary}
    return now, since, boundary >= 0


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode("utf-8", errors="replace") or "{}")
    except ValueError:
        return 0
    if data.get("agent_id") or not play_session(data):
        return 0
    cmd = str((data.get("tool_input") or {}).get("command") or "")
    if not GAME.search(cmd):
        return 0
    path = str(data.get("transcript_path") or "")
    if not os.path.isfile(path):
        return 0
    now, since, compacted = scan(path)
    all8 = [name for name, _ in ROLES]
    missing = [r for r in all8 if r not in now]
    if missing:
        sys.stderr.write("8 specialists must be working before any game order. working: %s. not working: %s.\n"
                         % (", ".join(r for r in all8 if r in now) or "none", ", ".join(missing)))
        return 2
    if compacted and UNPAUSE.search(cmd):
        gone = [r for r in all8 if r not in since]
        if gone:
            sys.stderr.write("after compaction, spawn all 8 specialists before unpausing. spawned since compaction: "
                             "%s. missing: %s.\n" % (", ".join(r for r in all8 if r in since) or "none",
                                                     ", ".join(gone)))
            return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception:
        sys.exit(0)
