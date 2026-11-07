"""Finds seamless loop points in a WAV (16-bit PCM, any channels): for a loop that ends at the clip's end, the start
whose lead-in sounds most like the clip's last moments, so the jump from the end back to it is not heard.

The match is the normalised cross-correlation of the `--win` seconds before the end with the same length before each
candidate start (mono mix), plus how close the two windows' levels are. Also prints the clip's level over time and how
well the plain loop (end back to 0) joins, to tell a bad seam from a clip that changes along its length.

Usage: python3 scratch/find_loop_point.py file.wav [--tail=0.8,1.4] [--head=0,0.6] [--win=0.04] [--top=5]
  --tail: where to look for a start, seconds before the end (the short loop: its length's range)
  --head: where to look for a start from the clip's beginning (the full loop's start instead of 0)
"""
import sys
import wave

import numpy as np


def load(path):
    with wave.open(path, "rb") as w:
        ch = w.getnchannels()
        rate = w.getframerate()
        if w.getsampwidth() != 2:
            raise SystemExit("%s: only 16-bit PCM" % path)
        data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    return data.reshape(-1, ch).mean(axis=1), rate


def score(x, a, b, n):
    """How alike x[a-n:a] and x[b-n:b] are: correlation (1 best) less the level mismatch in dB / 20."""
    u = x[a - n:a]
    v = x[b - n:b]
    du = u - u.mean()
    dv = v - v.mean()
    den = np.sqrt((du * du).sum() * (dv * dv).sum())
    corr = (du * dv).sum() / den if den > 0 else 0.0
    ru = np.sqrt((u * u).mean()) + 1e-9
    rv = np.sqrt((v * v).mean()) + 1e-9
    return corr - abs(20.0 * np.log10(ru / rv)) / 20.0, corr


def main():
    path = None
    tail = (0.8, 1.4)
    head = (0.0, 0.6)
    win = 0.04
    top = 5
    for a in sys.argv[1:]:
        if a.startswith("--tail="):
            tail = tuple(float(v) for v in a[7:].split(","))
        elif a.startswith("--head="):
            head = tuple(float(v) for v in a[7:].split(","))
        elif a.startswith("--win="):
            win = float(a[6:])
        elif a.startswith("--top="):
            top = int(a[6:])
        else:
            path = a
    x, rate = load(path)
    n = x.size
    w = int(win * rate)
    print("%s: %.3fs at %d Hz" % (path, n / rate, rate))
    # Level along the clip, a quarter second at a time.
    rms = [20 * np.log10(np.sqrt((x[k:k + rate // 4] ** 2).mean()) + 1e-9) for k in range(0, n - rate // 4, rate // 4)]
    print("level (dBFS, per 0.25s): " + " ".join("%.1f" % r for r in rms))
    # The plain loop: the last window against the one before the clip wraps round (the end's lead-in against the
    # start's own first window is all there is: compare the end with the start's first window, as continuation).
    s0, c0 = score(np.concatenate([x, x[:w]]), n, n + w, w)
    jump = abs(x[-1] - x[0])
    print("plain loop end->0: sample jump %.4f, end vs start window corr %.3f" % (jump, c0))
    # The short loop's start: the end's lead-in against each candidate's.
    best = []
    lo = int(n - tail[1] * rate)
    hi = int(n - tail[0] * rate)
    for b in range(max(lo, w), hi):
        s, c = score(x, n, b, w)
        best.append((s, c, b))
    best.sort(reverse=True)
    print("tail loop starts (end -> start):")
    for s, c, b in best[:top]:
        print("  start %8d frames = %.4fs (%.3fs before the end)  score %.3f corr %.3f  step %.4f" % (
            b, b / rate, (n - b) / rate, s, c, abs(x[-1] - x[b])))
    # The full loop's start near the beginning.
    best = []
    for b in range(max(int(head[0] * rate), w), int(head[1] * rate)):
        s, c = score(x, n, b, w)
        best.append((s, c, b))
    best.sort(reverse=True)
    print("full loop starts (end -> start):")
    for s, c, b in best[:top]:
        print("  start %8d frames = %.4fs  score %.3f corr %.3f  step %.4f" % (b, b / rate, s, c, abs(x[-1] - x[b])))


main()
