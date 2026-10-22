# Vagueprompts (user, 2026-10-21: "see that "FAILED"? Yeah." / "And whatever the model actually sent to powershell." /
# "Log only" / "get rid of whatever detection mechanism current colonyanalysys uses." / "the update will be immediate").
# PostToolUse on PowerShell and Bash: when the command runs rimworld-play's send.ps1 and the reply's result is "failed",
# one line goes at once into <SaveData>\VerbalCommands\guess\agent_sends.jsonl: tick, when, what = the command exactly as
# the model sent it, detail = the reasons. The file is an inbox: ColonyAnalysys' GuessRecord takes its lines into the
# loaded save's .rws and deletes them (user, 2026-10-22: "embedded in .RWS of same savefiles"). Nothing is blocked.
import json
import os
import sys

OUT = os.path.join(os.path.expanduser("~"), "AppData", "LocalLow", "Ludeon Studios", "RimWorld by Ludeon Studios",
                   "VerbalCommands", "guess", "agent_sends.jsonl")


def output_text(resp):
    if isinstance(resp, str):
        return resp
    if isinstance(resp, dict):
        for k in ("stdout", "output", "result", "content"):
            v = resp.get(k)
            if isinstance(v, str) and "{" in v:
                return v
        return json.dumps(resp)
    if isinstance(resp, list):
        return "\n".join(output_text(x) for x in resp)
    return ""


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    if data.get("tool_name") not in ("PowerShell", "Bash"):
        return
    command = (data.get("tool_input") or {}).get("command") or ""
    if "send.ps1" not in command:
        return
    text = output_text(data.get("tool_response"))
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end <= start:
        return
    try:
        reply = json.loads(text[start:end + 1])
    except Exception:
        return
    if not isinstance(reply, dict) or reply.get("result") != "failed":
        return
    game = reply.get("game_end") or {}
    tick = game.get("tick") or 0
    day = game.get("day")
    hour = game.get("hour")
    when = "Day %s, %sh" % (day + 1, hour) if isinstance(day, int) and hour is not None else ""
    reasons = reply.get("reasons") or []
    entry = {
        "tick": tick,
        "when": when,
        "what": command,
        "detail": " / ".join(str(r) for r in reasons),
        "problems": [],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "a", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
