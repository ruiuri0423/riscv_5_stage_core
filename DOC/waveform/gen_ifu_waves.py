# -*- coding: utf-8 -*-
"""Generate IFU spec v2.0 waveforms (Queue arch + drain-then-flush)."""
import sys, os, shutil
sys.path.insert(0, "/workspace/retrowave/src")
from retrowave.mcp_server import WaveSession

OUT = "/home/user/riscv_5_stage_core/DOC/waveform"
os.makedirs(OUT, exist_ok=True)


def check(r, what):
    if not r.get("ok", False):
        raise RuntimeError(f"{what}: {r}")
    return r


def build(name, periods, rows, groups=None, edges=None):
    s = WaveSession()
    check(s.new_document(), "new")
    if s.model.signals:
        check(s.remove_signals(list(range(len(s.model.signals)))), "clear demo")
    check(s.set_periods(periods), "periods")
    check(s.add_signals([{"name": n, "fill": f} for n, f, _ in rows]), "signals")
    for idx, (_, fill, cells) in enumerate(rows):
        for c in cells:
            if len(c) == 3:
                p0, p1, t = c
                txt = ""
            else:
                p0, p1, t, txt = c
            check(s.fill(idx, p0, p1, t, txt), f"fill {name}:{idx}")
    for g_idx, g_name in (groups or []):
        check(s.create_group(g_idx, g_name), f"group {g_name}")
    for (sig_a, per_a, edge_a), (sig_b, per_b, edge_b), label, style in (edges or []):
        na = check(s.add_anchor(sig_a, per_a, edge_a), "anchor")["nid"]
        nb = check(s.add_anchor(sig_b, per_b, edge_b), "anchor")["nid"]
        check(s.add_edge(na, nb, label, style), "edge")
    for fmt in ("svg", "png"):
        r = check(s.render(format=fmt, scale=2), f"render {fmt}")
        shutil.copy(r["path"], os.path.join(OUT, f"{name}.{fmt}"))
    print(f"{name}: ok")


def bus(seq):
    """seq: list of (period, text) or (period, None) for Unknown."""
    out = []
    for p, t in seq:
        out.append((p, p, "BUS", t) if t is not None else (p, p, "Unknown"))
    return out


def lvl(seq, base):
    """seq: list of 0/1 per period; emit fills only where != base."""
    out = []
    for p, v in enumerate(seq):
        t = "H" if v else "L"
        if t != base:
            out.append((p, p, t))
    return out


# =====================================================================
# WF1 : steady state, DEPTH=2 / L=1  ->  3 cycles deliver 2 (2/3 IPC)
#  T : 0    1    2    3    4    5    6    7
# cmd: 0    1    2    1    1    2    1    1     (registered, cycle start)
# dat: 0    0    1    1    0    1    1    0
# =====================================================================
#   AR issued at T0(A0) T1(A1) T3(A2) T4(A3) T6(T) T7(T+4)
#   BPU hits taken on A3 @T4 -> pc jumps to T
ARV = [1, 1, 0, 1, 1, 0, 1, 1]
ADR = ["A0", "A1", "A2", "A2", "A3", "T", "T", "T+4"]
RV = [0, 1, 1, 0, 1, 1, 0, 1]
RD = [None, "I(A0)", "I(A1)", None, "I(A2)", "I(A3)", None, "I(T)"]
IDV = [0, 0, 1, 1, 0, 1, 1, 0]
IDPC = [None, None, "A0", "A1", None, "A2", "A3", None]
IDNPC = [None, None, "A0+4", "A1+4", None, "A2+4", "T", None]
IDTKN = [0, 0, 0, 0, 0, 0, 1, 0]
CMD = ["0", "1", "2", "1", "1", "2", "1", "1"]
DAT = ["0", "0", "1", "1", "0", "1", "1", "0"]

build(
    "ifu_steady", 8,
    rows=[
        ("CLK",           "CLK", []),
        # AXI AR
        ("ARVALID",       "H",   lvl(ARV, "H")),
        ("ARADDR",        "BUS", bus(list(enumerate(ADR)))),
        ("ARREADY",       "H",   []),
        # AXI R
        ("RVALID",        "L",   lvl(RV, "L")),
        ("RDATA",         "HiZ", bus([(p, t) for p, t in enumerate(RD) if t])),
        # BPU (combinational lookup, same cycle as AR handshake)
        ("if2bp_query",   "H",   lvl(ARV, "H")),
        ("if2bp_taken",   "L",   [(4, 4, "H")]),
        ("if2bp_npc",     "HiZ", bus([(4, "T")])),
        # queue occupancy
        ("cmd_q_cnt",     "BUS", bus(list(enumerate(CMD)))),
        ("data_q_cnt",    "BUS", bus(list(enumerate(DAT)))),
        # IF -> ID
        ("if2id_valid",   "L",   lvl(IDV, "L")),
        ("if2id_ready",   "H",   []),
        ("if2id_pc",      "HiZ", bus([(p, t) for p, t in enumerate(IDPC) if t])),
        ("if2id_taken",   "L",   lvl(IDTKN, "L")),
        ("if2id_npc",     "HiZ", bus([(p, t) for p, t in enumerate(IDNPC) if t])),
    ],
    groups=[([1, 2, 3], "AXI-AR"), ([4, 5], "AXI-R"),
            ([6, 7, 8], "BPU"), ([9, 10], "QUEUE"), ([11, 12, 13, 14, 15], "IF2ID")],
    edges=[
        ((2, 2, "mid"), (1, 2, "mid"), "cmd_q full: AR throttled", "single"),
        ((5, 4, "start"), (11, 5, "start"), "rok is registered: +1T", "single"),
        ((8, 4, "start"), (15, 6, "start"), "prediction rides cmd_q", "single"),
    ],
)

# =====================================================================
# WF2 : drain-then-flush redirect
#  T : 0    1    2    3    4    5    6    7
# cmd: 0    1    2    1    0    1    2    1
# dat: 0    0    1    1    0    0    1    1
#  T2 : ex2if_valid up, ongoing_cmd=1 -> ready=0  (drain wait)
#  T3 : counts level  -> ready=1 -> flush, queues cleared, pc<=Rpc
# =====================================================================
R_ARV = [1, 1, 0, 0, 1, 1, 0, 1]
R_ADR = ["X0", "X1", "X2", "X2", "Rpc", "R+4", "R+8", "R+8"]
R_RV = [0, 1, 1, 0, 0, 1, 1, 0]
R_RD = [None, "I(X0)", "I(X1)", None, None, "I(Rpc)", "I(R+4)", None]
R_IDV = [0, 0, 1, 1, 0, 0, 1, 1]
R_IDPC = [None, None, "X0", "X1", None, None, "Rpc", "R+4"]
R_CMD = ["0", "1", "2", "1", "0", "1", "2", "1"]
R_DAT = ["0", "0", "1", "1", "0", "0", "1", "1"]
ONG = [0, 1, 1, 0, 0, 1, 1, 0]
EXV = [0, 0, 1, 1, 0, 0, 0, 0]
EXR = [1, 0, 0, 1, 1, 0, 0, 1]

build(
    "ifu_redirect", 8,
    rows=[
        ("CLK",            "CLK", []),
        # redirect channel (EX -> IF)
        ("ex2if_valid",    "L",   lvl(EXV, "L")),
        ("ex2if_ready",    "L",   lvl(EXR, "L")),
        ("ex2if_flush",    "L",   lvl(EXV, "L")),
        ("ex2if_pc",       "HiZ", bus([(2, "Rpc"), (3, "Rpc")])),
        ("ex2if_cause",    "HiZ", bus([(2, "MISP"), (3, "MISP")])),
        # drain condition
        ("ongoing_cmd",    "L",   lvl(ONG, "L")),
        ("cmd_q_cnt",      "BUS", bus(list(enumerate(R_CMD)))),
        ("data_q_cnt",     "BUS", bus(list(enumerate(R_DAT)))),
        ("q_flush",        "L",   [(3, 3, "H")]),
        # AXI AR
        ("ARVALID",        "L",   lvl(R_ARV, "L")),
        ("ARADDR",         "BUS", bus(list(enumerate(R_ADR)))),
        # AXI R
        ("RVALID",         "L",   lvl(R_RV, "L")),
        ("RDATA",          "HiZ", bus([(p, t) for p, t in enumerate(R_RD) if t])),
        # IF -> ID
        ("if2id_valid",    "L",   lvl(R_IDV, "L")),
        ("if2id_pc",       "HiZ", bus([(p, t) for p, t in enumerate(R_IDPC) if t])),
    ],
    groups=[([1, 2, 3, 4, 5], "REDIRECT"), ([6, 7, 8, 9], "DRAIN"),
            ([10, 11], "AXI-AR"), ([12, 13], "AXI-R"), ([14, 15], "IF2ID")],
    edges=[
        ((6, 2, "mid"), (2, 2, "mid"), "in-flight: redirect held off", "single"),
        ((8, 3, "start"), (9, 3, "mid"), "counts level -> flush", "single"),
        ((9, 3, "mid"), (11, 4, "start"), "pc <= Rpc", "single"),
        ((14, 3, "mid"), (14, 3, "end"), "IFU-1: not masked", "single"),
    ],
)

# =====================================================================
# WF3 : ID backpressure
#  T : 0    1    2    3    4    5    6    7
# cmd: 0    1    2    2    2    2    1    1
# dat: 0    0    1    2    2    2    1    0
# =====================================================================
B_ARV = [1, 1, 0, 0, 0, 0, 1, 1]
B_ADR = ["A0", "A1", "A2", "A2", "A2", "A2", "A2", "A3"]
B_RV = [0, 1, 1, 0, 0, 0, 0, 1]
B_RD = [None, "I(A0)", "I(A1)", None, None, None, None, "I(A2)"]
B_RRDY = [1, 1, 1, 0, 0, 0, 1, 1]
B_IDV = [0, 0, 1, 1, 1, 1, 1, 0]
B_IDRDY = [1, 1, 0, 0, 0, 1, 1, 1]
B_IDPC = [None, None, "A0", "A0", "A0", "A0", "A1", None]
B_CMD = ["0", "1", "2", "2", "2", "2", "1", "1"]
B_DAT = ["0", "0", "1", "2", "2", "2", "1", "0"]

build(
    "ifu_backpressure", 8,
    rows=[
        ("CLK",           "CLK", []),
        # AXI AR
        ("ARVALID",       "L",   lvl(B_ARV, "L")),
        ("ARADDR",        "BUS", bus(list(enumerate(B_ADR)))),
        # AXI R
        ("RVALID",        "L",   lvl(B_RV, "L")),
        ("RDATA",         "HiZ", bus([(p, t) for p, t in enumerate(B_RD) if t])),
        ("RREADY",        "H",   lvl(B_RRDY, "H")),
        # queue occupancy
        ("cmd_q_cnt",     "BUS", bus(list(enumerate(B_CMD)))),
        ("data_q_cnt",    "BUS", bus(list(enumerate(B_DAT)))),
        # IF -> ID
        ("if2id_valid",   "L",   lvl(B_IDV, "L")),
        ("if2id_ready",   "H",   lvl(B_IDRDY, "H")),
        ("if2id_pc",      "HiZ", bus([(p, t) for p, t in enumerate(B_IDPC) if t])),
    ],
    groups=[([1, 2], "AXI-AR"), ([3, 4, 5], "AXI-R"),
            ([6, 7], "QUEUE"), ([8, 9, 10], "IF2ID")],
    edges=[
        ((9, 2, "start"), (1, 2, "mid"), "cmd_q full: AR off", "single"),
        ((7, 3, "start"), (5, 3, "start"), "data_q full: RREADY off", "single"),
        ((9, 5, "start"), (5, 6, "start"), "resume", "single"),
    ],
)

print("all done ->", OUT)
