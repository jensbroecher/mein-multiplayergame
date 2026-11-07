"""Rebuilds an engine clip that revs up along its length (ElevenLabs' Meteor straight-eight did) into two loops in one
file, for PlayerCart's "engine_top_loop": the whole file loops while the car is below top speed, and only its last
`--tail` seconds once it is at top speed.

The file is P then Q, from the clip's steady part S (from `--from` seconds to `--to`, or the end):
  Q: S's last `--tail` seconds, made a seamless loop of its own: its last `--fade` seconds cross-fade into the audio
     just before its start, so its end runs on into its beginning.
  P: S up to where Q's material starts, so P's end runs on into Q's start as the clip did; its first `--wrap` seconds
     cross-fade from Q's opening into S's beginning, so the whole file's end (Q's end) runs on into P's start too:
     the drop from the revs at the end back to those at the beginning is a glide, not a cut.
So every join is seamless: P to Q (playing through), Q to Q (the top-speed loop), Q to P (the whole file's loop).
Cross-fades are equal-power (cos/sin: engine noise a second apart is uncorrelated). Prints the frames, and the
length of Q to put in the preset. 16-bit PCM in and out, any channels.

Pick Q where the clip holds its pitch: a stretch that still revs up sounds like a rev-up every pass, however short.
The Meteor's kept climbing to its very end (302 to 315 Hz over its last second) but held 285-288 Hz from 5.16 to 5.81s,
so its S ends there: --from=1.75 --to=5.81 --tail=0.65 (from the clip ElevenLabs made).

Usage: python3 scratch/make_engine_loop.py in.wav out.wav [--from=1.75] [--to=<end>] [--tail=1.0] [--fade=0.15]
    [--wrap=0.35]
"""
import sys
import wave

import numpy as np


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=") for a in sys.argv[1:] if a.startswith("--"))
    src, dst = args
    start = float(opts.get("from", 1.75))
    tail = float(opts.get("tail", 1.0))
    fade = float(opts.get("fade", 0.15))
    wrap = float(opts.get("wrap", 0.35))
    with wave.open(src, "rb") as w:
        ch = w.getnchannels()
        rate = w.getframerate()
        if w.getsampwidth() != 2:
            raise SystemExit("only 16-bit PCM")
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64).reshape(-1, ch) / 32768.0
    end = float(opts["to"]) if "to" in opts else x.shape[0] / rate
    s = x[int(start * rate):int(round(end * rate))]
    n = s.shape[0]
    t_n = int(round(tail * rate))
    f_n = int(round(fade * rate))
    w_n = int(round(wrap * rate))
    if w_n > t_n - f_n or t_n + f_n > n:
        raise SystemExit("the tail, fade and wrap don't fit the clip")
    # Q: the last tail seconds, its end cross-faded into the audio before its start.
    r = s[n - t_n - f_n:]
    q = r[f_n:f_n + t_n].copy()
    k = np.arange(f_n) / f_n
    fo = np.cos(k * np.pi / 2)[:, None]
    fi = np.sin(k * np.pi / 2)[:, None]
    q[t_n - f_n:] = r[t_n:t_n + f_n] * fo + r[:f_n] * fi
    # P: up to Q's start, its head cross-faded from Q's opening into S's beginning.
    p = s[:n - t_n].copy()
    k = np.arange(w_n) / w_n
    fo = np.cos(k * np.pi / 2)[:, None]
    fi = np.sin(k * np.pi / 2)[:, None]
    p[:w_n] = s[n - t_n:n - t_n + w_n] * fo + s[:w_n] * fi
    y = np.concatenate([p, q])
    out = (np.clip(y, -1.0, 32767.0 / 32768.0) * 32768.0).round().astype("<i2")
    with wave.open(dst, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(out.tobytes())

    def step(a, b):
        return float(np.abs(a - b).max())

    print("%s: %d frames (%.3fs); top-speed loop: the last %d frames (%.3fs) from frame %d" % (
        dst, y.shape[0], y.shape[0] / rate, t_n, t_n / rate, p.shape[0]))
    print("joins (largest sample step): P->Q %.4f, Q->Q %.4f, Q->P %.4f; typical step inside %.4f" % (
        step(p[-1], q[0]), step(q[-1], q[0]), step(q[-1], p[0]), float(np.abs(np.diff(y, axis=0)).mean())))


main()
