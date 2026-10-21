# Types /compact + Enter into the console of the Claude Code process -ClaudePid, as if the user typed it. Started hidden
# and detached by compact_stop.ps1 (Stop hook), which says why (user, 2026-10-20: "devise a way so that a /compact gets
# injected if theres a 2 day note, regardless of it being thresshhold for not.").
# It drops its own console, attaches to that process's console and writes key events into its input buffer (CONIN$).
# Nothing is typed when the attach fails.
# -Text: what is typed before Enter; resume_hook.ps1 passes the read line after an injected compaction.
param([int]$ClaudePid, [string]$Text = "/compact")
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CompactInject {
    [StructLayout(LayoutKind.Explicit, CharSet = CharSet.Unicode)]
    public struct KEY_EVENT_RECORD {
        [FieldOffset(0)] public int bKeyDown;
        [FieldOffset(4)] public ushort wRepeatCount;
        [FieldOffset(6)] public ushort wVirtualKeyCode;
        [FieldOffset(8)] public ushort wVirtualScanCode;
        [FieldOffset(10)] public char UnicodeChar;
        [FieldOffset(12)] public uint dwControlKeyState;
    }
    [StructLayout(LayoutKind.Explicit)]
    public struct INPUT_RECORD {
        [FieldOffset(0)] public ushort EventType;
        [FieldOffset(4)] public KEY_EVENT_RECORD KeyEvent;
    }
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool FreeConsole();
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateFileW(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool WriteConsoleInputW(IntPtr h, INPUT_RECORD[] recs, uint n, out uint written);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);

    public static bool Type(uint pid, string text) {
        FreeConsole();
        if (!AttachConsole(pid)) return false;
        // GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, OPEN_EXISTING
        IntPtr h = CreateFileW("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        if (h == new IntPtr(-1)) { FreeConsole(); return false; }
        INPUT_RECORD[] recs = new INPUT_RECORD[text.Length * 2];
        for (int i = 0; i < text.Length; i++) {
            char c = text[i];
            for (int d = 0; d < 2; d++) {
                INPUT_RECORD r = new INPUT_RECORD();
                r.EventType = 1;   // KEY_EVENT
                r.KeyEvent.bKeyDown = (d == 0) ? 1 : 0;
                r.KeyEvent.wRepeatCount = 1;
                r.KeyEvent.wVirtualKeyCode = (ushort)((c == '\r') ? 0x0D : 0);   // VK_RETURN for Enter
                r.KeyEvent.UnicodeChar = c;
                recs[i * 2 + d] = r;
            }
        }
        uint written;
        bool ok = WriteConsoleInputW(h, recs, (uint)recs.Length, out written);
        CloseHandle(h);
        FreeConsole();
        return ok;
    }
}
'@
[void][CompactInject]::Type([uint32]$ClaudePid, $Text + "`r")
