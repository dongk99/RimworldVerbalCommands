# PreToolUse hook (Bash / PowerShell). User, 2026-10-21, after the play session (transcript 9dff3c40, after its compaction)
# read ORCHESTRATOR.md, COMMON.md and the status files but not SKILL.md or PLAYBOOK.md, then sent guessed sentences
# ("show building at 119, 154.", "show orders for refuel.") through send.ps1: "block ANY tooling into ps1 from
# proceeding UNTIL the orchestrator reads ALL OF THE REQUIRED FILE. with hooks."
#   - A command that names a .ps1 is blocked (exit 2) until the ORCHESTRATOR's transcript shows every file listed in
#     skills\rimworld-play\required_reads.txt read in full, in the current context: entries after the last compaction
#     summary (isCompactSummary), or the whole transcript when there was none.
#   - Only the main transcript counts (transcript_path), never a subagent's file: a specialist's send.ps1 waits for the
#     orchestrator's reads too.
#   - A read is: a Read tool call (offset/limit ranges are added up; a Read with no range covers 2000 lines), a file
#     attachment entry (Claude Code re-attaches files after a compaction), or a Bash/PowerShell cat / Get-Content / type
#     of the path with no head/tail/sed/-TotalCount range. An image needs one Read.
#   - Scope: a play session (RIMWORLD_PLAY=1 or play_sessions\active_session.txt = session id), any .ps1; any session,
#     a .ps1 inside skills\rimworld-play.
#   - The block lists every missing file by full path.
# required_reads.txt: one entry per line, '#' comments; '~' = home, 'P' alone at the start = the project folder;
# '*' globs; 'newest N <glob>' = the N newest by name. Run with python -I.
import glob
import json
import os
import re
import sys

HOME = os.environ.get("USERPROFILE") or os.path.expanduser("~")
SKILL = r"{YOUR DIRECTORY HERE}"   # the folder holding the rimworld-play scripts and required_reads.txt (user, 2026-10-21: mod copies point at no directory)
P = r"{YOUR DIRECTORY HERE}"       # the project folder: 'P\...' entries of required_reads.txt hang off it
MARKER = os.path.join(HOME, "AppData", "LocalLow", "Ludeon Studios", "RimWorld by Ludeon Studios", "VerbalCommands", "play_sessions", "active_session.txt")
LIST = os.path.join(SKILL, "required_reads.txt")
IMAGE_EXT = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")
DEFAULT_READ_LINES = 2000
PS1_RE = re.compile(r"\"[^\"]*\.ps1\"|'[^']*\.ps1'|[^\s\"'=;|&<>(){}\[\],`]+\.ps1(?![\w.])", re.IGNORECASE)
READ_WORD_RE = re.compile(r"(?<![\w-])(?:cat|get-content|gc|type)(?![\w-])", re.IGNORECASE)
RANGE_WORD_RE = re.compile(r"(?<![\w-])(?:head|tail|sed|-TotalCount|-Tail|Select-Object|-First|-Last)(?![\w-])",
                           re.IGNORECASE)
WRITE_SHAPE_RE = re.compile(r"<<|(?<![2&])>(?!&)")  # heredoc, or a redirect other than 2>&1


def key(path):
    return os.path.normcase(os.path.normpath(str(path or "").strip().strip("\"'")))


def play_session(data):
    if os.environ.get("RIMWORLD_PLAY") == "1":
        return True
    try:
        with open(MARKER, encoding="utf-8-sig") as f:
            sid = f.readline().strip()
    except OSError:
        return False
    return bool(sid) and str(data.get("session_id", "")).strip() == sid


def ps1_names(command):
    return [m.group(0).strip("\"'") for m in PS1_RE.finditer(command)]


def in_scope(data, command):
    names = ps1_names(command)
    if not names:
        return False
    if play_session(data):
        return True
    skill_key = key(SKILL) + os.sep
    return any(key(n).startswith(skill_key) or "rimworld-play" in n.lower() for n in names)


def expand_entry(line):
    line = line.strip()
    if not line or line.startswith("#"):
        return []
    newest = None
    m = re.match(r"^newest\s+(\d+)\s+(.+)$", line, re.IGNORECASE)
    if m:
        newest, line = int(m.group(1)), m.group(2).strip()
    if line.startswith("~"):
        line = HOME + line[1:]
    elif line == "P" or line.startswith("P\\") or line.startswith("P/"):
        line = P + line[1:]
    line = line.replace("/", "\\")
    found = sorted(glob.glob(line)) if ("*" in line or "?" in line) else [line]
    if newest is not None:
        found = sorted(found, key=lambda p: os.path.basename(p).lower())[-newest:]
    return found


def required_files():
    out = []
    try:
        with open(LIST, encoding="utf-8-sig") as f:
            for line in f:
                out += expand_entry(line)
    except OSError:
        return []
    seen = set()
    result = []
    for p in out:
        k = key(p)
        if k not in seen:
            seen.add(k)
            result.append(p)
    return result


def line_count(path):
    try:
        with open(path, "rb") as f:
            n = sum(1 for _ in f)
    except OSError:
        return 0
    return max(n, 1)


def entries(path):
    out = []
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except OSError:
        return out
    for line in raw.decode("utf-8", "replace").splitlines():
        try:
            out.append(json.loads(line))
        except Exception:
            continue
    return out


def since_last_compaction(items):
    start = 0
    for i, e in enumerate(items):
        if e.get("isCompactSummary"):
            start = i
    return items[start:]


def blocks(entry):
    c = (entry.get("message") or {}).get("content")
    if isinstance(c, list):
        return [b for b in c if isinstance(b, dict)]
    return []


def failed_ids(items):
    bad = set()
    for e in items:
        for b in blocks(e):
            if b.get("type") == "tool_result" and b.get("is_error"):
                bad.add(b.get("tool_use_id"))
    return bad


def shell_reads(cmd, required):
    """Required files a cat / Get-Content / type command reads whole."""
    # A cat with a redirect or a heredoc ("cat > file <<EOF") writes; it reads nothing (found 2026-10-21 when the
    # heredoc that wrote required_reads.txt counted as a read of every file it lists).
    if not READ_WORD_RE.search(cmd) or RANGE_WORD_RE.search(cmd) or WRITE_SHAPE_RE.search(cmd):
        return []
    flat = cmd.lower().replace("/", "\\")
    out = []
    for req in required:
        r = req.lower().replace("/", "\\")
        tail = "\\".join(r.split("\\")[-2:])  # parent folder + name
        if r in flat or tail in flat:
            out.append(req)
    return out


def reads(items, required):
    """{file key: [(first line, last line)]}; (0, 0) = whole file."""
    found = {}
    bad = failed_ids(items)

    def add(path, rng):
        found.setdefault(key(path), []).append(rng)

    for e in items:
        att = e.get("attachment") if e.get("type") == "attachment" else None
        if isinstance(att, dict) and att.get("type") == "file":
            fi = ((att.get("content") or {}).get("file") or {})
            path = att.get("filename") or fi.get("filePath")
            start = int(fi.get("startLine") or 1)
            num = fi.get("numLines")
            if path:
                add(path, (start, start + int(num) - 1) if num else (0, 0))
            continue
        if e.get("type") != "assistant":
            continue
        for b in blocks(e):
            if b.get("type") != "tool_use" or b.get("id") in bad:
                continue
            name = b.get("name")
            inp = b.get("input") or {}
            if name == "Write" and inp.get("file_path"):
                add(inp["file_path"], (0, 0))  # the orchestrator wrote it: it knows the whole file
            elif name == "Read" and inp.get("file_path"):
                off, lim = inp.get("offset"), inp.get("limit")
                if off is None and lim is None:
                    add(inp["file_path"], (1, DEFAULT_READ_LINES))
                else:
                    start = int(off or 1)
                    add(inp["file_path"], (start, start + int(lim or DEFAULT_READ_LINES) - 1))
            elif name in ("Bash", "PowerShell"):
                for req in shell_reads(str(inp.get("command") or ""), required):
                    add(req, (0, 0))
    return found


def covered(ranges, total):
    if any(r == (0, 0) for r in ranges):
        return True
    need = 1
    for a, b in sorted(ranges):
        if a > need:
            return False
        need = max(need, b + 1)
        if need > total:
            return True
    return need > total


def missing(required, found):
    out = []
    for req in required:
        ranges = found.get(key(req), [])
        if not ranges:
            out.append(req)
        elif not req.lower().endswith(IMAGE_EXT) and not covered(ranges, line_count(req)):
            out.append(req + " (not read to its last line)")
    return out


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if data.get("tool_name") not in ("Bash", "PowerShell"):
        return 0
    command = str((data.get("tool_input") or {}).get("command") or "")
    if not in_scope(data, command):
        return 0
    required = required_files()
    if not required:
        return 0
    path = str(data.get("transcript_path") or "")
    items = since_last_compaction(entries(path)) if os.path.isfile(path) else []
    gaps = missing(required, reads(items, required))
    if not gaps:
        return 0
    sys.stderr.write("BLOCKED by rimworld_required_reads.py (user, 2026-10-21: no .ps1 runs until the orchestrator has read "
                     "ALL required files in this context). Not read in full since the last compaction:\n")
    for g in gaps:
        sys.stderr.write("  - " + g + "\n")
    sys.stderr.write("Read each of them in full with the Read tool (the orchestrator, not a subagent), then send again. "
                     "The list is " + LIST + ".\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
