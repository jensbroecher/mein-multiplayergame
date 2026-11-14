#!/usr/bin/env python3
"""The Tuk-Tuk's engine loop, synthesised (no recording, no ElevenLabs): a small single-cylinder auto-rickshaw engine
putting along through a tinny little exhaust, the bodywork rattling with it.

    python3 scratch/synth_engine_tuktuk.py [out.wav] [--rms=-18.0]

Everything repeats exactly every LOOP seconds (every frequency a whole number of cycles in it; the firing's per-cycle
variations drawn once for the loop's FIRES cycles and laid round it; every filter circular), so the loop has no seam.

At its loop pitch the engine fires F0 times a second (PlayerCart plays it at 0.8 to 1.35 of that, 1.5 with a boost: from
a lazy putt-putt to a busy chatter). Each firing is an exhaust thump (a damped low tone and a short crack) whose strength
and timing wander from one cycle to the next, as a single does; after it a tinny ring from the pipe and, now and then, a
small metallic rattle (the panels, the chain). The crank's turn hums under it. Rolled off from LP_HZ and cut over CUT_HZ,
so pitched up 1.5x it stays under about 7 kHz. Levelled by RMS (`--rms`, dBFS); the preset's engine_gain_db is -9.7
minus that.
"""
import sys
import wave

import numpy as np

RATE = 44100
LOOP = 2.0
F0 = 46.0
FIRES = int(round(F0 * LOOP))
LP_HZ = 2200.0
CUT_HZ = 4600.0


def lowpass(x, fc, order=4, cut=None):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    resp = 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))
    if cut:
        resp *= np.clip((cut * 1.15 - f) / (cut * 0.15), 0.0, 1.0)
    return np.fft.irfft(spec * resp, len(x))


def highpass(x, fc, order=2):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    resp = 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(spec * resp, len(x))


def add_wrapped(buf, start, chunk):
    """Adds `chunk` into `buf` from sample `start`, wrapping round the loop's end."""
    n = len(buf)
    idx = (start + np.arange(len(chunk))) % n
    np.add.at(buf, idx, chunk)


def main():
    out = "sounds/enginesounds/engine_tuktuk_loop.wav"
    rms_db = -18.0
    for a in sys.argv[1:]:
        if a.startswith("--rms="):
            rms_db = float(a[6:])
        else:
            out = a
    n = int(RATE * LOOP)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(11)

    thump = np.zeros(n)
    ring = np.zeros(n)
    rattle = np.zeros(n)
    period = 1.0 / F0
    tau = np.arange(int(RATE * 0.03)) / RATE
    for k in range(FIRES):
        jitter = rng.normal(0.0, 0.0007)
        amp = 1.0 + 0.22 * rng.standard_normal()
        amp = float(np.clip(amp, 0.55, 1.45))
        start = int(round((k * period + jitter) * RATE)) % n
        # The exhaust's thump: a damped low tone and a short crack of noise.
        crack = rng.standard_normal(len(tau)) * np.exp(-tau / 0.0009)
        pulse = np.exp(-tau / 0.0055) * np.sin(2 * np.pi * 150.0 * tau) \
            + 0.45 * np.exp(-tau / 0.0022) * np.sin(2 * np.pi * 410.0 * tau + 0.6) + 0.30 * crack
        add_wrapped(thump, start, amp * pulse)
        # The pipe's tinny ring after it.
        f_ring = 760.0 + 40.0 * rng.standard_normal()
        add_wrapped(ring, start + int(RATE * 0.0015), amp * np.exp(-tau / 0.0045) * np.sin(2 * np.pi * f_ring * tau))
        # Now and then a little metallic rattle a few milliseconds on.
        if rng.random() < 0.55:
            f_r = rng.uniform(1700.0, 2600.0)
            d = int(RATE * rng.uniform(0.005, 0.012))
            r = np.exp(-tau / 0.0025) * np.sin(2 * np.pi * f_r * tau) * rng.uniform(0.4, 1.0)
            add_wrapped(rattle, start + d, r)

    # The crank's hum: the firing's low harmonics, a little of the half order (the four-stroke's lope).
    body = np.zeros(n)
    for h, a in [(0.5, 0.10), (1, 0.45), (2, 0.30), (3, 0.16), (4, 0.08)]:
        body += a * np.sin(2 * np.pi * F0 * h * t + h * 1.1)

    engine = thump * 1.0 + ring * 0.22 + rattle * 0.10 + body * 0.35
    engine = highpass(engine, 35.0)
    mix = lowpass(engine, LP_HZ, 4, CUT_HZ)
    mix -= mix.mean()
    rms = np.sqrt(np.mean(mix ** 2))
    mix *= 10 ** (rms_db / 20.0) / rms
    peak = np.abs(mix).max()
    if peak > 0.89:
        mix *= 0.89 / peak
    data = (np.clip(mix, -1, 1) * 32767).astype(np.int16)
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    rms_out = 20 * np.log10(np.sqrt(np.mean((data / 32767.0) ** 2)))
    peak_out = 20 * np.log10(np.abs(data).max() / 32767.0)
    seam = abs(int(data[0]) - int(data[-1])) / 32767.0
    spec = np.abs(np.fft.rfft(data / 32767.0))
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    hi_share = 10 * np.log10(np.sum(spec[f > 3000] ** 2) / np.sum(spec ** 2) + 1e-12)
    print(f"{out}: {LOOP}s, RMS {rms_out:.1f} dBFS, peak {peak_out:.1f} dBFS, seam step {seam:.4f}, "
          f"energy over 3 kHz {hi_share:.1f} dB; engine_gain_db {-9.7 - rms_out:.1f}")


if __name__ == "__main__":
    main()
