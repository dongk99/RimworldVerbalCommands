# Agent order log (user, 2026-10-22: "a logger that saves literally exactly what you did, EXCEPT THE DOMAIN (shit you
# made up), into CSV file. gating: a ticker option (mod settings) on colonyanalysys. One csv per save. Appends.
# output location: Desktop."). PostToolUse on PowerShell and Bash: when the command runs rimworld-play's send.ps1, one
# row per call is appended to the CSV named in <SaveData>\ColonyAnalysys\order_log_target.txt. ColonyAnalysys
# (OrderLog.cs) writes that file while its checkbox is on and the save has a name, and deletes it otherwise; no file,
# no row. Columns: ColonyAnalysys\ORDER_LOG_CSV.md. Runs once per call: no clock, no retry loop (user, 2026-10-22:
# "no fucking \"read every frame, x second\""). A CSV that can't be written (open in Excel) keeps its row in
# order_log_pending.jsonl, written first on the next send.ps1 call. Several agents send at once: a named mutex,
# waited on without a timeout, keeps their read + append apart. Nothing is blocked.
import csv
import ctypes
import glob
import io
import json
import os
import re
import sys

SAVEDATA = os.path.join(os.path.expanduser("~"), "AppData", "LocalLow", "Ludeon Studios", "RimWorld by Ludeon Studios")
TARGET = os.path.join(SAVEDATA, "ColonyAnalysys", "order_log_target.txt")
PENDING = os.path.join(SAVEDATA, "ColonyAnalysys", "order_log_pending.jsonl")
VC_SRC = os.path.join(os.path.expanduser("~"), ".claude", "projects", "RimWorld-LLM-Integration", "src", "VerbalCommands")
MUTEX = "Global\\ColonyAnalysysOrderLog"
HEADER = ["call", "session", "agent", "model", "tick", "time", "command", "result", "game", "code", "sequence", "ref"]
REPLY = re.compile(r"-Reply\s+['\"]?(apply|cancel)\b", re.I)
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
HOLE = re.compile(r"\{[^{}]*\}")
MIN_PIECE = 8


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


def agent_of(data):
    aid = data.get("agent_id")
    if aid:
        return str(aid)
    path = (data.get("transcript_path") or "").replace("/", "\\")
    if "\\subagents\\" in path:
        name = os.path.splitext(os.path.basename(path))[0]
        return name[len("agent-"):] if name.startswith("agent-") else name
    return "orchestrator"


def model_of(data):
    # The last assistant record of the sender's own transcript (a subagent's is <session>\subagents\agent-<id>.jsonl).
    path = data.get("transcript_path") or ""
    aid = data.get("agent_id")
    if aid and path:
        sub = os.path.join(os.path.splitext(path)[0], "subagents", "agent-%s.jsonl" % aid)
        if os.path.exists(sub):
            path = sub
    try:
        with open(path, "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - 4 * 1024 * 1024))
            lines = f.read().decode("utf-8", "replace").splitlines()
    except Exception:
        return ""
    for line in reversed(lines):
        if '"assistant"' not in line:
            continue
        try:
            rec = json.loads(line)
        except Exception:
            continue
        model = ((rec.get("message") or {}).get("model")) if rec.get("type") == "assistant" else None
        if model:
            return model
    return ""


def game_lines(reply):
    out = []
    for key in ("reasons", "answers", "plan_lines", "actions"):
        for v in reply.get(key) or []:
            out.append(v if isinstance(v, str) else json.dumps(v, ensure_ascii=False))
    return out


def unescape(s):
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t").replace("\\\\", "\\")


def literal_pieces():
    pieces = []
    for path in glob.glob(os.path.join(VC_SRC, "*.cs")):
        name = os.path.basename(path)
        try:
            with open(path, encoding="utf-8-sig", errors="replace") as f:
                for n, line in enumerate(f, 1):
                    if line.lstrip().startswith("//"):
                        continue
                    for m in LITERAL.finditer(line):
                        for piece in HOLE.split(unescape(m.group(1))):
                            piece = piece.strip()
                            if len(piece) >= MIN_PIECE:
                                pieces.append((piece, "%s:%d" % (name, n)))
        except Exception:
            continue
    pieces.sort(key=lambda p: -len(p[0]))
    return pieces


def code_of(lines):
    # Per game line, the longest VerbalCommands string literal piece it contains.
    if not lines:
        return ""
    pieces = literal_pieces()
    found = []
    for text in lines:
        for piece, where in pieces:
            if piece in text:
                if where not in found:
                    found.append(where)
                break
    return "; ".join(found)


def read_rows(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.reader(f))
    return rows[1:] if rows and rows[0] == HEADER else rows


def replay(rows):
    # Per (session, agent): the last planned call and the open replan chain (its last call).
    planned, chain = {}, {}
    for r in rows:
        if len(r) < len(HEADER):
            continue
        step(planned, chain, r[1], r[2], int(r[0]) if r[0].isdigit() else 0, r[6], r[7])
    return planned, chain


def step(planned, chain, session, agent, call, command, result):
    key = (session, agent)
    labels, ref = [], ""
    m = REPLY.search(command)
    if m:
        labels.append(m.group(1).lower())
        if key in planned:
            ref = str(planned[key])
    elif key in chain:
        labels.append("replan")
        ref = str(chain[key])
    if result == "planned":
        labels.insert(0, "plan")
        planned[key] = call
    if result == "failed" or (result == "answer" and key in chain):
        chain[key] = call
    else:
        chain.pop(key, None)
    return "+".join(labels), ref


def append(path, entry):
    rows = read_rows(path)
    planned, chain = replay(rows)
    call = len(rows) + 1
    sequence, ref = step(planned, chain, entry["session"], entry["agent"], call, entry["command"], entry["result"])
    row = [str(call), entry["session"], entry["agent"], entry["model"], entry["tick"], entry["time"], entry["command"],
           entry["result"], entry["game"], entry["code"], sequence, ref]
    buf = io.StringIO()
    w = csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator="\r\n")
    new = not os.path.exists(path) or os.path.getsize(path) == 0
    if new:
        w.writerow(HEADER)
    w.writerow(row)
    with open(path, "a", encoding="utf-8-sig" if new else "utf-8", newline="") as f:
        f.write(buf.getvalue())


def write_all(entries):
    # Returns the entries that could not be written (CSV locked).
    left = []
    for e in entries:
        try:
            append(e["csv"], e)
        except Exception:
            left.append(e)
    return left


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
    try:
        with open(TARGET, encoding="utf-8") as f:
            target = f.read().strip()
    except Exception:
        return
    if not target:
        return
    text = output_text(data.get("tool_response"))
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end <= start:
        return
    try:
        reply = json.loads(text[start:end + 1])
    except Exception:
        return
    if not isinstance(reply, dict):
        return
    game = reply.get("game_end") or {}
    day, hour = game.get("day"), game.get("hour")
    lines = game_lines(reply)
    entry = {
        "csv": target,
        "session": str(data.get("session_id") or ""),
        "agent": agent_of(data),
        "model": model_of(data),
        "tick": str(game.get("tick") if game.get("tick") is not None else ""),
        "time": "%02d-%02d" % (hour, day) if isinstance(day, int) and isinstance(hour, int) else "",
        "command": command,
        "result": str(reply.get("result") or ""),
        "game": "\n".join(lines),
        "code": code_of(lines),
    }

    kernel = ctypes.windll.kernel32
    handle = kernel.CreateMutexW(None, False, MUTEX)
    if handle:
        kernel.WaitForSingleObject(handle, 0xFFFFFFFF)
    try:
        pending = []
        if os.path.exists(PENDING):
            with open(PENDING, encoding="utf-8") as f:
                pending = [json.loads(l) for l in f if l.strip()]
        left = write_all(pending + [entry])
        if left:
            with open(PENDING, "w", encoding="utf-8", newline="\n") as f:
                for e in left:
                    f.write(json.dumps(e, ensure_ascii=False) + "\n")
        elif os.path.exists(PENDING):
            os.remove(PENDING)
    finally:
        if handle:
            kernel.ReleaseMutex(handle)
            kernel.CloseHandle(handle)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
