# PreToolUse hook (Bash / PowerShell / Write / Edit / MultiEdit / NotebookEdit), RimWorld play sessions only.
# User, 2026-10-16, after the play session wrapped send.ps1 in its own s.sh and piped the pause through `head -1`,
# which threw away every 6-hour reminder batch: "block agents from creating new powershells. they may only use what
# is on the folder." / "fix existing powershell so everything prints".
#   - No new or edited script files (.ps1 .psm1 .psd1 .bat .cmd .sh .bash .vbs), and no code file that calls
#     PowerShell or a skill script.
#   - A script may be run only when it already exists in the skill folder, or is one of the project scripts SKILL.md
#     names (assemble_router.ps1, check_router_sync.ps1, build.ps1).
#   - PowerShell runs only as `powershell -File <one of those>`: no -Command, no inline PowerShell. The PowerShell
#     tool may only call those scripts.
#   - The output of send.ps1 / play.ps1 / wait_for.ps1 is never piped, redirected or captured: it is read whole.
# Play session: RIMWORLD_PLAY=1 (play_here.ps1) or the session id in play_log\active_session.txt (as compact_due.ps1).
# Subagents carry their parent's session id. Exit 2 = block (stderr goes back to the model). Run with python -I.
import json
import os
import re
import sys

HOME = os.environ.get("USERPROFILE") or os.path.expanduser("~")
SKILL = os.path.join(HOME, ".claude", "skills", "rimworld-play")
P = os.path.join(HOME, ".claude", "projects", "RimWorld-LLM-Integration")
MARKER = os.path.join(HOME, "AppData", "LocalLow", "Ludeon Studios", "RimWorld by Ludeon Studios", "VerbalCommands", "play_sessions", "active_session.txt")
PROJECT_SCRIPTS = [
    os.path.join(P, "briefs", "23_run", "assemble_router.ps1"),
    os.path.join(P, "router_lab", "check_router_sync.ps1"),
    os.path.join(P, "build.ps1"),
]
SCRIPT_EXT = (".ps1", ".psm1", ".psd1", ".bat", ".cmd", ".sh", ".bash", ".vbs")
CODE_EXT = (".py", ".pyw", ".js", ".mjs", ".cjs", ".ts", ".rb", ".pl")
RESULT_SCRIPTS = ("send.ps1", "play.ps1", "wait_for.ps1", "vote.ps1")
# Hourly check votes (src\VerbalCommands\AgentHourlyCheck.cs, 2026-10-16; user: "that also means modifying hook."):
# written only by vote.ps1, never by hand. (The specialists' heartbeats in agents\ are gone since 2026-10-19: only the
# orchestrator votes.)
VOTE_PATH_RE = re.compile(r"verbalcommands[\\/]+(?:votes|agents)\b", re.IGNORECASE)
VOTE_MSG = "votes are written only by vote.ps1"
SCRIPT_RE = re.compile(r"[^\s\"'=;|&<>(){}\[\],`]+\.(?:ps1|psm1|psd1|bat|cmd|sh|bash|vbs)(?![\w.])", re.IGNORECASE)
WRAPPER_RE = re.compile(r"powershell|pwsh|send\.ps1|play\.ps1|wait_for\.ps1|rimworld-play", re.IGNORECASE)
PS_RE = re.compile(r"\b(?:powershell|pwsh)(?:\.exe)?\b", re.IGNORECASE)
PS_FILE_RE = re.compile(
    r"""^(?:\s+-(?:NoProfile|NonInteractive|NoLogo|ExecutionPolicy\s+\S+|WindowStyle\s+\S+))*\s+-File\s+("[^"]+"|'[^']+'|\S+)""",
    re.IGNORECASE)

# Speed cap (user, 2026-10-16: "STOP AGENTS PLAYING RIMWORLD PLAY TO RUN AT 2X SPEED AND 3X SPEED."): normal (1x) and
# paused only. Blocked: "set game speed to" fast / superfast / their other words (FormWave1.PlanGameSpeed); unpause /
# unpaused / resume / play, which go back to the speed before the pause (TickManager.TogglePaused), maybe 2x or 3x;
# a "run" sentence unless it says "at normal" (with no SPEED the mod runs at superfast, router.txt "run" forms); and
# play.ps1 -Run, which sends "run N hours." with no speed.
SPEED_FAST_RE = re.compile(
    r"set\s+(?:the\s+)?game\s+speed\s+to\s+(?:fast(?:est)?|super\s*fast|[23]x?|unpaused?|resume|play)\b", re.IGNORECASE)
RUN_RE = re.compile(r"\brun\s+(?:until\s+event|\d+\s+(?:hours?|days?))\b([^.\n\"']*)", re.IGNORECASE)
PLAY_RUN_RE = re.compile(r"-Run\s+[\"']?0*[1-9]", re.IGNORECASE)
SPEED_HOW = "Use 'set game speed to normal.' (1x) to unpause, or 'set game speed to paused.'; 2x and 3x are not allowed."


def speed_problems(text):
    problems = []
    for m in SPEED_FAST_RE.finditer(text):
        problems.append("'" + m.group(0) + "': the game runs at normal (1x) only. " + SPEED_HOW)
    for m in RUN_RE.finditer(text):
        if not re.match(r"\s*at\s+normal\b", m.group(1) or "", re.IGNORECASE):
            problems.append("'" + m.group(0).strip() + "': a run must say 'at normal' (with no speed it goes at superfast, 3x). " + SPEED_HOW)
    if PLAY_RUN_RE.search(text) and re.search(r"play\.ps1", text, re.IGNORECASE):
        problems.append("play.ps1 -Run sends 'run N hours.' at superfast (3x). " + SPEED_HOW)
    return problems


HOW = ("Send orders only with the skill's own scripts, called by full path, e.g. "
       "powershell -File \"" + os.path.join(SKILL, "send.ps1") + "\" -Text \"show status.\" "
       "and read the whole output (tips and [REMINDER] lines included). "
       "No wrappers, no new scripts, no pipes or redirects on the result.")


def play_session(data):
    if os.environ.get("RIMWORLD_PLAY") == "1":
        return True
    try:
        with open(MARKER, encoding="utf-8-sig") as f:
            sid = f.readline().strip()
    except OSError:
        return False
    return bool(sid) and str(data.get("session_id", "")).strip() == sid


def norm(path, cwd):
    p = path.strip().strip("\"'")
    for var in ("${env:USERPROFILE}", "$env:USERPROFILE", "%USERPROFILE%", "$HOME", "${HOME}"):
        if p.lower().startswith(var.lower()):
            p = HOME + p[len(var):]
    if p.startswith("~"):
        p = HOME + p[1:]
    m = re.match(r"^/([a-zA-Z])/(.*)$", p)
    if m:
        p = m.group(1) + ":\\" + m.group(2)
    if "$" in p or "%" in p:
        return None
    p = p.replace("/", "\\")
    if not re.match(r"^[a-zA-Z]:\\", p):
        p = os.path.join(cwd or os.getcwd(), p)
    return os.path.normcase(os.path.normpath(p))


def allowed_scripts():
    out = set()
    try:
        for name in os.listdir(SKILL):
            full = os.path.join(SKILL, name)
            if os.path.isfile(full) and name.lower().endswith(SCRIPT_EXT):
                out.add(os.path.normcase(os.path.normpath(full)))
    except OSError:
        pass
    for s in PROJECT_SCRIPTS:
        if os.path.isfile(s):
            out.add(os.path.normcase(os.path.normpath(s)))
    return out


def script_tokens(cmd):
    toks = []
    for m in re.finditer(r'"([^"]*)"|\'([^\']*)\'', cmd):
        inner = m.group(1) if m.group(1) is not None else m.group(2)
        if inner.lower().rstrip().endswith(SCRIPT_EXT):
            toks.append(inner)
    stripped = re.sub(r'"[^"]*"|\'[^\']*\'', " ", cmd)
    toks += SCRIPT_RE.findall(stripped)
    return toks


def check_command(cmd, cwd, tool):
    ok = allowed_scripts()
    problems = []
    used = []
    for t in script_tokens(cmd):
        n = norm(t, cwd)
        if n is None or n not in ok:
            problems.append("'" + t + "' is not one of the scripts in the folder (write the script's full path; "
                            "new scripts are not allowed)")
        else:
            used.append(os.path.basename(n).lower())
    for m in PS_RE.finditer(cmd):
        rest = cmd[m.end():]
        f = PS_FILE_RE.match(rest)
        if not f:
            problems.append("PowerShell may only run as 'powershell -File <script in the folder>' (no -Command, no inline PowerShell)")
            continue
        n = norm(f.group(1), cwd)
        if n is None or n not in ok:
            problems.append("'" + f.group(1) + "' is not one of the scripts in the folder")
    problems += speed_problems(cmd)
    if VOTE_PATH_RE.search(cmd):
        problems.append(VOTE_MSG)
    if re.search(r"\bchmod\b", cmd):
        problems.append("chmod: no new executables")
    unquoted = re.sub(r'"[^"]*"|\'[^\']*\'', " ", cmd)
    for m in re.finditer(r"(?:^|[;&|(]\s*)(?:bash|sh|zsh|source|\.)\s+(?!-)([^\s;&|]+)", unquoted):
        n = norm(m.group(1), cwd)
        if n is None or n not in ok:
            problems.append("running '" + m.group(1) + "' as a shell script: only scripts in the folder")
    if any(u in RESULT_SCRIPTS for u in used):
        bare = re.sub(r'"[^"]*"|\'[^\']*\'', " ", cmd)
        bare = re.sub(r"2>&1", " ", bare)
        if re.search(r"\||>|\$\(|`", bare):
            problems.append("the result of send.ps1 / play.ps1 / wait_for.ps1 is read whole: no pipe, redirect or capture")
    if tool == "PowerShell":
        # Only calls of the scripts, `& "<script>" args` or `powershell -File "<script>" args`, one per statement, and
        # nothing piped or redirected.
        bare = re.sub(r"2>&1", " ", re.sub(r'"[^"]*"|\'[^\']*\'', " ", cmd))
        if re.search(r"\||>|\$\(", bare):
            problems.append("the PowerShell tool may only call the scripts in the folder: no pipe, redirect or capture")
        for s in statements(cmd):
            if s.startswith("&"):
                m = re.match(r"""&\s*("[^"]+"|'[^']+'|\S+)""", s)
                n = norm(m.group(1), cwd) if m else None
                if n is None or n not in ok:
                    problems.append("the PowerShell tool may only call the scripts in the folder ('" + s[:80] + "' is not one)")
            elif not PS_RE.match(s):
                problems.append("the PowerShell tool may only call the scripts in the folder ('" + s[:80] + "' is not one)")
    return problems


def statements(cmd):
    out, cur, q = [], [], None
    for ch in cmd:
        if q:
            cur.append(ch)
            if ch == q:
                q = None
        elif ch in "\"'":
            q = ch
            cur.append(ch)
        elif ch in ";\n\r":
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur).strip())
    return [s for s in out if s]


def check_write(tool, inp):
    path = inp.get("file_path") or inp.get("notebook_path") or ""
    low = path.lower()
    if VOTE_PATH_RE.search(path):
        return [VOTE_MSG]
    if "verbalcommands" in low and "inbox" in low:
        # An order file written straight into the mod's inbox: the speed cap holds there too.
        texts = [inp.get("content", ""), inp.get("new_string", "")] + [e.get("new_string", "") for e in inp.get("edits", [])]
        found = speed_problems("\n".join(t or "" for t in texts))
        if found:
            return found
    if low.endswith(SCRIPT_EXT):
        return ["writing or editing a script ('" + path + "'): agents may only use the scripts already in the folder"]
    if low.endswith(CODE_EXT):
        if tool == "Write":
            texts = [inp.get("content", "")]
        elif tool == "Edit":
            texts = [inp.get("new_string", "")]
        elif tool == "MultiEdit":
            texts = [e.get("new_string", "") for e in inp.get("edits", [])]
        else:
            texts = [inp.get("new_source", "")]
        if any(WRAPPER_RE.search(t or "") for t in texts):
            return ["'" + path + "' would call PowerShell or a skill script: no wrappers around the folder's scripts"]
    return []


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if not play_session(data):
        return 0
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}
    if tool in ("Bash", "PowerShell", "Monitor"):
        problems = check_command(inp.get("command", "") or "", data.get("cwd", ""), tool)
    elif tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        problems = check_write(tool, inp)
    else:
        return 0
    if not problems:
        return 0
    sys.stderr.write("BLOCKED by rimworld_play_scripts.py (user rule: agents may only use the scripts already in "
                     + SKILL + "; results print whole):\n")
    for p in dict.fromkeys(problems):
        sys.stderr.write("  - " + p + "\n")
    sys.stderr.write(HOW + "\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
