# compact_read_first.py - PreToolUse hook (matcher *), project scope only: register it in the project's .claude\settings.json
# (and in agent_player\.claude\settings.json if you have one), never in the global settings
# (user, 2026-10-21: "Im not gonna have non session project related fire that off outside a project.").
# Mod copy (portable): the skill folder is this script's own folder, compact_state.json lives in
# <SaveData>\VerbalCommands\play_sessions, and there is no agent_player\.claude\settings.json entry.
#
# User, 2026-10-21: "when any of the agent *READ*, yes, READ, or *WRITE* into ANY of the compaction powershell/files in
# rimworldllm, all of their actions get BLOCKED by saying 'GO READ OTHER COMPACT RELEVANT FILES, ESPECIALLY IF YOU ARE
# WRITING. I DONT CARE IF YOU ARE READING EITHER.' And you list the relevant files that they MUST go read."
# Why: on 2026-10-21 the agent diagnosed the play session's compaction from settings.json and the compact_*.ps1 hooks
# without opening play_here.ps1, whose CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=20 was the real trigger.
#
# A "touch" is any tool call whose input names a compaction file (a Read, a Write/Edit, or a shell command containing the
# name), in any folder. From the first touch on (this call, or any earlier call in the transcript) every tool call is
# blocked until each MUST_READ file was opened with the Read tool; the only calls that still pass are Reads of a MUST_READ
# file or of its .mmd. Reads through the shell (cat, Get-Content) do not count.
import json
import os
import re
import sys

HOME = os.path.expanduser("~")
SKILL = os.path.dirname(os.path.abspath(__file__))
SAVE = os.path.join(HOME, r"AppData\LocalLow\Ludeon Studios\RimWorld by Ludeon Studios\VerbalCommands")

MUST_READ = [
    os.path.join(SKILL, "play_here.ps1"),                      # CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, idle-compact env
    r"{YOUR DIRECTORY HERE}\settings.json",                    # the harness settings: autoCompactWindow, autoCompactEnabled, hook registrations
    os.path.join(SKILL, "compact_limits.json"),
    os.path.join(SKILL, "compact_limits.md"),
    os.path.join(SAVE, r"play_sessions\compact_state.json"),
    os.path.join(SKILL, "compact_common.ps1"),
    os.path.join(SKILL, "compact_gate.ps1"),
    os.path.join(SKILL, "compact_block.ps1"),
    os.path.join(SKILL, "compact_stop.ps1"),
    os.path.join(SKILL, "compact_inject.ps1"),
    os.path.join(SKILL, "compact_warn.ps1"),
    os.path.join(SKILL, "resume_hook.ps1"),
]

TOUCH = re.compile(r"(compact_[a-z_]+\.(ps1|json|md)|resume_hook\.ps1|play_here\.ps1)", re.I)

MESSAGE = ("GO READ OTHER COMPACT RELEVANT FILES, ESPECIALLY IF YOU ARE WRITING. "
           "I DONT CARE IF YOU ARE READING EITHER.")


def norm(path):
    try:
        return os.path.normcase(os.path.normpath(os.path.abspath(str(path))))
    except Exception:
        return ""


def scan(transcript_path):
    """(touched_before, set of normalized paths opened with the Read tool) over the whole transcript."""
    touched = False
    read = set()
    if not transcript_path or not os.path.isfile(transcript_path):
        return touched, read
    with open(transcript_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if '"tool_use"' not in line:
                continue
            try:
                o = json.loads(line)
            except Exception:
                continue
            if o.get("type") != "assistant":
                continue
            content = (o.get("message") or {}).get("content") or []
            for item in content:
                if not isinstance(item, dict) or item.get("type") != "tool_use":
                    continue
                inp = item.get("input") or {}
                if TOUCH.search(json.dumps(inp)):
                    touched = True
                if item.get("name") == "Read":
                    read.add(norm(inp.get("file_path", "")))
    return touched, read


def main():
    try:
        hook_in = json.load(sys.stdin)
    except Exception:
        return 0
    tool = hook_in.get("tool_name") or ""
    tool_input = hook_in.get("tool_input") or {}

    this_touch = bool(TOUCH.search(json.dumps(tool_input)))
    touched_before, read = scan(hook_in.get("transcript_path"))
    if not (this_touch or touched_before):
        return 0

    must = [p for p in MUST_READ if norm(p) not in read]
    if not must:
        return 0

    if tool == "Read":
        fp = norm(tool_input.get("file_path", ""))
        allowed = {norm(p) for p in MUST_READ} | {norm(p + ".mmd") for p in MUST_READ}
        if fp in allowed:
            return 0

    sys.stderr.write(MESSAGE + "\nRead each of these with the Read tool before anything else:\n"
                     + "".join("  " + p + "\n" for p in must))
    return 2


if __name__ == "__main__":
    sys.exit(main())
