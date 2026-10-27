# PostToolUse hook (every tool), RimWorld play sessions only, the main agent only (no subagents).
# User, 2026-10-19, after the playing agent wrote "his construction skill is unknown" and left it there: "if agent says
# "skill" a tip can fire that (if you want to know skills, you can say show [pawn] skills)." The router's sentence is
# "show skills of PAWN." (router_lab\parse_results.txt, "query skills"), so the hint says that. How often: "Once per
# compaction" (user, 2026-10-19).
#   Fires when the agent's own text since the last compaction says "skill" or "skills" and the hint is not yet in the
#   transcript since that compaction. No state file: the hint, once given, is in the transcript (hook context), and a
#   compaction starts a new stretch. Prints {"hookSpecificOutput": {..., "additionalContext": HINT}}. Run with python -I.
#   Settings gate (user, 2026-10-26): prints nothing while the mod setting Know-how tips is off (tips_off below).
import json
import os
import re
import sys

HOME = os.environ.get("USERPROFILE") or os.path.expanduser("~")
MARKER = os.path.join(HOME, "AppData", "LocalLow", "Ludeon Studios", "RimWorld by Ludeon Studios", "VerbalCommands", "play_sessions", "active_session.txt")
HINT = "if you want to know skills, you can say show skills of [pawn]"
WORD_RE = re.compile(r"\bskills?\b", re.IGNORECASE)


def play_session(data):
    # As rimworld_play_scripts.py: RIMWORLD_PLAY=1 or the session id in active_session.txt.
    if os.environ.get("RIMWORLD_PLAY") == "1":
        return True
    try:
        with open(MARKER, encoding="utf-8-sig") as f:
            sid = f.readline().strip()
    except OSError:
        return False
    return bool(sid) and str(data.get("session_id", "")).strip() == sid


def tips_off():
    # Settings gate (user, 2026-10-26): the mod setting "Know-how tips". The mod writes it as gates.tips in
    # <SaveData>\VerbalCommands\inbox_state.json; only an exact false counts as off. The file missing or unreadable, not JSON,
    # or no gates.tips in it counts as on.
    try:
        path = os.path.join(HOME, "AppData", "LocalLow", "Ludeon Studios", "RimWorld by Ludeon Studios", "VerbalCommands", "inbox_state.json")
        with open(path, encoding="utf-8-sig") as f:
            state = json.load(f)
        return state["gates"]["tips"] is False
    except Exception:
        return False


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if data.get("agent_id") or not play_session(data):
        return 0
    path = data.get("transcript_path") or ""
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except OSError:
        return 0
    # Only the stretch since the last compaction.
    cut = raw.rfind(b'"compact_boundary"')
    if cut >= 0:
        cut = raw.rfind(b"\n", 0, cut) + 1
        raw = raw[cut:]
    if HINT.encode("utf-8") in raw:
        return 0
    said = False
    for line in raw.decode("utf-8", "replace").splitlines():
        try:
            e = json.loads(line)
        except Exception:
            continue
        if e.get("type") != "assistant" or e.get("isSidechain"):
            continue
        for c in (e.get("message") or {}).get("content") or []:
            if isinstance(c, dict) and c.get("type") == "text" and WORD_RE.search(c.get("text", "")):
                said = True
                break
        if said:
            break
    if not said:
        return 0
    # Settings gate (user, 2026-10-26): Know-how tips off in the mod settings = no hint.
    if tips_off():
        return 0
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": HINT}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
