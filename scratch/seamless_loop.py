"""Makes a steady loop (an engine held at one speed, a hum) loop without a click: the clip's first `--fade` seconds are
cross-faded into its last ones and cut off its start, so its end runs on into its new beginning (the sample that
followed them). Equal-power cross-fade (cos/sin: noise a fraction of a second apart is uncorrelated). The clip comes out
`--fade` seconds shorter. 16-bit PCM in and out, any channels; it prints the jump at the seam before and after.

For a clip that revs up along its length use make_engine_loop.py instead: a seamless seam won't hide the drop in pitch.

Usage: python3 scratch/seamless_loop.py in.wav out.wav [--fade=0.15]
"""
import sys
import wave

import numpy as np


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=") for a in sys.argv[1:] if a.startswith("--"))
    src, dst = args
    fade = float(opts.get("fade", 0.15))
    with wave.open(src, "rb") as w:
        ch = w.getnchannels()
        rate = w.getframerate()
        if w.getsampwidth() != 2:
            raise SystemExit("only 16-bit PCM")
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64).reshape(-1, ch)
    n = x.shape[0]
    f = int(round(fade * rate))
    if f <= 0 or 2 * f >= n:
        raise SystemExit("fade out of range")
    t = (np.arange(f) + 0.5) / f
    a = np.cos(t * np.pi * 0.5)[:, None]
    b = np.sin(t * np.pi * 0.5)[:, None]
    out = x[f:].copy()
    out[-f:] = x[n - f:] * a + x[:f] * b
    print("seam jump before: %.4f, after: %.4f (full scale 1)" % (
        np.abs(x[-1] - x[0]).max() / 32768.0, np.abs(out[-1] - out[0]).max() / 32768.0))
    out = np.clip(np.round(out), -32768, 32767).astype(np.int16)
    with wave.open(dst, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(out.tobytes())
    print("%s: %.3fs -> %s: %.3fs" % (src, n / rate, dst, out.shape[0] / rate))


if __name__ == "__main__":
    main()
