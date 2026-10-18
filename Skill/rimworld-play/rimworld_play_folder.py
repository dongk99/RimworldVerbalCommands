# PreToolUse hook (Read / Grep / Glob / Write / Edit / MultiEdit / NotebookEdit / Bash / PowerShell / Monitor), RimWorld
# play sessions only. User, 2026-10-16: "EDIT THE HOOKS SO MODEL PHYSICALLY CANNOT READ ANY FILES OUTSIDE ITS PROJECT
# FOLDER" / "models may not read reference playlog unless user explicitely allows it."
#   - Every path must be inside the project folder P. Outside it only: the skill's SKILL.md and scripts, this session's
#     own tool-results folder (.claude\projects\<slug>\<session id>\) and its scratchpad (Temp\claude\<slug>\<session id>\).
#   - The mod's picture (AgentPicture.cs: outbox\picture.png and its failure note), Read tool only, these two files only
#     (user, 2026-10-17, after the play session was refused picture.png: "Pls fix.").
#   - New sessions write to agent_player\play_sessions\ (archive_play_log.ps1 zips it to Desktop\play_log\archive\).
#   - Bash and Monitor may only run `powershell -File <script>`; the PowerShell tool only calls scripts
#     (rimworld_play_scripts.py). Every path written in a command is checked the same way.
# Play session: RIMWORLD_PLAY=1 (play_here.ps1) or the session id in play_sessions\active_session.txt.
# Subagents carry their parent's session id. Exit 2 = block (stderr goes back to the model). Run with python -I.
import json
import os
import re
import sys

HOME = os.environ.get("USERPROFILE") or os.path.expanduser("~")
SKILL = os.path.join(HOME, ".claude", "skills", "rimworld-play")
P = os.path.join(HOME, ".claude", "projects", "RimWorld-LLM-Integration")
SESSIONS = os.path.join(P, "agent_player", "play_sessions")
MARKER = os.path.join(HOME, "AppData", "LocalLow", "Ludeon Studios", "RimWorld by Ludeon Studios", "VerbalCommands", "play_sessions", "active_session.txt")
SCRIPT_EXT = (".ps1", ".psm1", ".psd1", ".bat", ".cmd")
TEMP = os.environ.get("TEMP") or os.path.join(HOME, "AppData", "Local", "Temp")
OUTBOX = os.path.join(HOME, "AppData", "LocalLow", "Ludeon Studios", "RimWorld by Ludeon Studios", "VerbalCommands",
                      "outbox")
PICTURE_FILES = (os.path.join(OUTBOX, "picture.png"), os.path.join(OUTBOX, "failed to make picture_png.md"))


def play_session(data):
    if os.environ.get("RIMWORLD_PLAY") == "1":
        return True
    try:
        with open(MARKER, encoding="utf-8-sig") as f:
            sid = f.readline().strip()
    except OSError:
        return False
    return bool(sid) and str(data.get("session_id", "")).strip() == sid


def real(p):
    return os.path.normcase(os.path.realpath(p))


def under(path, root):
    root = real(root)
    return path == root or path.startswith(root.rstrip("\\") + "\\")


def to_path(raw, cwd):
    p = raw.strip().strip("\"'")
    for var in ("${env:USERPROFILE}", "$env:USERPROFILE", "%USERPROFILE%", "${HOME}", "$HOME"):
        if p.lower().startswith(var.lower()):
            p = HOME + p[len(var):]
    if p.startswith("~"):
        p = HOME + p[1:]
    m = re.match(r"^/([a-zA-Z])(/.*)?$", p)
    if m:
        p = m.group(1) + ":" + (m.group(2) or "\\")
    p = p.replace("/", "\\")
    if not re.match(r"^[a-zA-Z]:\\", p):
        p = os.path.join(cwd or os.getcwd(), p)
    return real(p)


def allowed(path, sid, script=False):
    """None if allowed, else the reason."""
    if under(path, P):
        return None
    if under(path, SKILL):
        if path == real(os.path.join(SKILL, "SKILL.md")):
            return None
        if script and path.endswith(SCRIPT_EXT):
            return None
        return "only SKILL.md and the scripts of the skill folder"
    if sid:
        parts = path.split("\\")
        own = sid.lower() in parts
        if own and under(path, os.path.join(HOME, ".claude", "projects")):
            return None
        if own and under(path, os.path.join(TEMP, "claude")):
            return None
    return "outside the project folder"


def check_paths(tool, inp, cwd, sid):
    out = []
    keys = ("file_path", "notebook_path", "path")
    for k in keys:
        v = inp.get(k)
        if v:
            out.append((v, to_path(v, cwd)))
    if tool in ("Grep", "Glob") and not inp.get("path"):
        out.append((cwd or ".", to_path(cwd or ".", cwd)))
    if tool == "Glob":
        pat = inp.get("pattern") or ""
        fixed = re.split(r"[*?\[{]", pat, 1)[0]
        if fixed and (re.match(r"^([a-zA-Z]:|/|\\|~|\$|%)", fixed) or ".." in fixed):
            base = inp.get("path") or cwd
            out.append((pat, to_path(fixed if re.match(r"^([a-zA-Z]:|/|\\|~|\$|%)", fixed) else os.path.join(base or ".", fixed), cwd)))
    if tool == "Grep":
        g = inp.get("glob") or ""
        if ".." in g or re.match(r"^([a-zA-Z]:|/|\\|~)", g):
            out.append((g, None))
    problems = []
    pictures = [real(f) for f in PICTURE_FILES]
    for raw, p in out:
        if tool == "Read" and p in pictures:
            continue
        why = "a glob that leaves the search folder" if p is None else allowed(p, sid)
        if why:
            problems.append("'" + raw + "': " + why)
    return problems


PATH_TOKEN_RE = re.compile(
    r"""(?:"([^"]*)"|'([^']*)'|((?:[a-zA-Z]:[\\/]|/[a-zA-Z]/|~[\\/]|\$\{?env:USERPROFILE\}?|\$\{?HOME\}?|%USERPROFILE%|\.\.[\\/])[^\s"';|&<>()]*))""")
PS_CALL_RE = re.compile(
    r"""^(?:powershell|pwsh)(?:\.exe)?(?:\s+-(?:NoProfile|NonInteractive|NoLogo|ExecutionPolicy\s+\S+|WindowStyle\s+\S+))*\s+-File\s+("[^"]+"|'[^']+'|\S+)""",
    re.IGNORECASE)


def statements(cmd):
    out, cur, q = [], [], None
    i = 0
    while i < len(cmd):
        ch = cmd[i]
        if q:
            cur.append(ch)
            if ch == q:
                q = None
        elif ch in "\"'":
            q = ch
            cur.append(ch)
        elif ch in ";\n\r|&":
            if ch == "&" and i + 1 < len(cmd) and cmd[i + 1] == ">" or (ch == "&" and cmd[i - 1:i] == ">"):
                cur.append(ch)
            else:
                out.append("".join(cur).strip())
                cur = []
        else:
            cur.append(ch)
        i += 1
    out.append("".join(cur).strip())
    return [s for s in out if s]


def check_command(tool, cmd, cwd, sid):
    problems = []
    for m in PATH_TOKEN_RE.finditer(cmd):
        raw = next(g for g in m.groups() if g is not None)
        if m.group(3) is None:
            # A quoted string counts when it looks like a path.
            if not re.match(r"^\s*(?:[a-zA-Z]:[\\/]|/[a-zA-Z]/|~[\\/]|\$\{?env:USERPROFILE|\$\{?HOME|%USERPROFILE%|\.\.[\\/])", raw):
                continue
        p = to_path(raw, cwd)
        why = allowed(p, sid, script=True)
        if why:
            problems.append("'" + raw + "': " + why)
    if tool in ("Bash", "Monitor"):
        for s in statements(cmd):
            s2 = re.sub(r"\s*2>&1\s*$", "", s)
            if not PS_CALL_RE.match(s2):
                problems.append("'" + s[:80] + "': Bash and Monitor may only run 'powershell -File <script>'")
    return problems


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))
    except Exception:
        return 0
    if not play_session(data):
        return 0
    tool = data.get("tool_name", "")
    inp = data.get("tool_input") or {}
    cwd = data.get("cwd", "")
    sid = str(data.get("session_id", "")).strip()
    if tool in ("Bash", "PowerShell", "Monitor"):
        problems = check_command(tool, inp.get("command", "") or "", cwd, sid)
    elif tool in ("Read", "Grep", "Glob", "Write", "Edit", "MultiEdit", "NotebookEdit"):
        problems = check_paths(tool, inp, cwd, sid)
    else:
        return 0
    if not problems:
        return 0
    sys.stderr.write("BLOCKED by rimworld_play_folder.py (user rule: the play session reads and writes only inside "
                     + P + "):\n")
    for p in dict.fromkeys(problems):
        sys.stderr.write("  - " + p + "\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
