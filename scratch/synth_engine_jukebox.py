#!/usr/bin/env python3
"""The Jukebox's engine loop, synthesised (no recording, no ElevenLabs): a big, lazy cross-plane V8 breathing
through twin pipes.

    python3 scratch/synth_engine_jukebox.py [out.wav] [--rms=-18.0]

Everything repeats exactly every LOOP seconds (a whole number of engine cycles in it; the noise made in the
frequency domain; every filter circular), so the loop has no seam. Kept deep and round: the pulses are soft, the mix is
low-passed (a gentle fourth-order roll-off from LP_HZ) and anything over 4 kHz is cut, so even pitched up 1.5x
(PlayerCart's top with a boost) it stays under about 6 kHz.

The engine at its loop pitch fires FIRE_HZ times a second (eight cylinders, about 1,450 rpm: unhurried). What makes
it a V8 and not a buzz is the burble: the firing order (BANKS) sends the pulses down the two pipes unevenly, two in a
row on one side, then two on the other, so each pipe carries a lumpy rhythm at half and a quarter of the firing rate.
The two pipes differ a little in level and tone, the cylinders a little in strength, and the firing drifts slowly (a
whole number of wobbles per loop). Levelled by RMS (`--rms`, dBFS); the preset's engine_gain_db is -9.7 minus that.
"""
import sys
import wave

import numpy as np

RATE = 44100
LOOP = 2.0
FIRE_HZ = 96.0
# Which pipe each of the eight firings in a cycle goes down (a cross-plane crank: L R L L R L R R).
BANKS = [0, 1, 0, 0, 1, 0, 1, 1]
# Each cylinder's strength (fixed, so the cycle repeats).
CYL = [1.00, 0.86, 0.94, 0.80, 0.97, 0.84, 0.90, 0.78]
LP_HZ = 1500.0
CUT_HZ = 4000.0


def lowpass(x, fc, order=4, cut=None):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / RATE)
    resp = 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))
    if cut:
        resp *= np.clip((cut * 1.15 - f) / (cut * 0.15), 0.0, 1.0)
    return np.fft.irfft(spec * resp, len(x))


def band_noise(n, lo, hi, rng):
    f = np.fft.rfftfreq(n, 1.0 / RATE)
    mag = ((f > lo) & (f < hi)).astype(float)
    mag *= 1.0 / np.maximum(f, 1.0) ** 0.5
    phase = rng.uniform(0, 2 * np.pi, len(f))
    x = np.fft.irfft(mag * np.exp(1j * phase), n)
    return x / (np.abs(x).max() + 1e-9)


def main():
    out = "sounds/enginesounds/engine_jukebox_loop.wav"
    rms_db = -18.0
    for a in sys.argv[1:]:
        if a.startswith("--rms="):
            rms_db = float(a[6:])
        else:
            out = a
    n = int(RATE * LOOP)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(59)
    cycles = FIRE_HZ * LOOP / 8.0
    assert abs(cycles - round(cycles)) < 1e-9, "a whole number of engine cycles must fit the loop"

    # Firing: soft pulses (damped low tones) at FIRE_HZ, the times drifting a little (periodic in LOOP).
    drift = 0.0022 * np.sin(2 * np.pi * 0.5 * t) + 0.0010 * np.sin(2 * np.pi * 1.5 * t + 1.0)
    phase = (t + drift) * FIRE_HZ
    k_of = np.floor(phase).astype(int)
    tau = (phase - k_of) / FIRE_HZ
    cyl = k_of % 8
    amp = np.array(CYL)[cyl]
    bank = np.array(BANKS)[cyl]
    # Each pipe's pulse: a thump and a higher ring. The pulses overlap their neighbours' tails only through the
    # low-pass, which is circular, so the loop stays seamless.
    pipes = []
    for side, (thump_hz, ring_hz, gain) in enumerate([(124.0, 340.0, 1.0), (140.0, 390.0, 0.74)]):
        on = (bank == side).astype(float) * amp
        pulse = on * (np.exp(-tau / 0.0046) * np.sin(2 * np.pi * thump_hz * tau)
                      + 0.80 * np.exp(-tau / 0.0022) * np.sin(2 * np.pi * ring_hz * tau))
        # The gas rushing out behind each pulse.
        hiss = band_noise(n, 200.0, 2200.0, rng) * on * np.exp(-tau / 0.0040)
        pipes.append(gain * (pulse + 0.40 * hiss))
    exhaust = lowpass(pipes[0] + pipes[1], LP_HZ, 4, CUT_HZ)

    # The block's rumble under it: the firing rate, and the half and quarter orders the uneven pipes make.
    body = np.zeros(n)
    for h, a in [(0.25, 0.06), (0.5, 0.20), (1.0, 0.45), (1.5, 0.16), (2.0, 0.30), (3.0, 0.16), (4.0, 0.08)]:
        body += a * np.sin(2 * np.pi * FIRE_HZ * h * t + h * 1.9)
    body = lowpass(body, 600.0, 2)

    mix = exhaust * 1.0 + body * 0.12
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
    low_share = 10 * np.log10(np.sum(spec[f < 60] ** 2) / np.sum(spec ** 2) + 1e-12)
    print(f"{out}: {LOOP}s, RMS {rms_out:.1f} dBFS, peak {peak_out:.1f} dBFS, seam step {seam:.4f}, "
          f"energy over 3 kHz {hi_share:.1f} dB, under 60 Hz {low_share:.1f} dB; engine_gain_db {-9.7 - rms_out:.1f}")


if __name__ == "__main__":
    main()
