#!/usr/bin/env python3
"""
Generates high quality swoosh/whoosh sound effects for the RC Vibe GP animated splashscreen.
Produces crisp, airy, cinematic letter fly-in swooshes using time-varying resonant
bandpass/highpass filtering over pink/white noise with smooth non-linear envelopes.
"""

import math
import random
import struct
import wave
import os

SAMPLE_RATE = 44100

def generate_swoosh(
    filename: str,
    duration: float = 0.22,
    freq_start: float = 380.0,
    freq_peak: float = 4200.0,
    freq_end: float = 850.0,
    peak_ratio: float = 0.35,
    q: float = 2.8,
    sub_blend: float = 0.12,
    seed: int = 1001
):
    rng = random.Random(seed)
    num_samples = int(duration * SAMPLE_RATE)
    
    # 1. Pink-ish noise generator with subtle turbulence modulation
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    noise = []
    for i in range(num_samples):
        white = rng.uniform(-1.0, 1.0)
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        b6 = white * 0.115926
        # Blend pink with white for airy high frequencies
        noise.append(pink * 0.20 + white * 0.50)
    
    # 2. Cytomic State Variable Filter
    ic1eq = 0.0
    ic2eq = 0.0
    
    output_samples = []
    sub_phase = 0.0
    
    fade_in_samples = int(0.008 * SAMPLE_RATE)   # 8ms fade in
    fade_out_samples = int(0.025 * SAMPLE_RATE)  # 25ms fade out
    
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        u = t / duration  # 0.0 to 1.0
        
        # Envelope: snappy attack, smooth crest, natural decay
        if u < peak_ratio:
            env = math.sin((u / peak_ratio) * (math.pi / 2.0)) ** 2.2
        else:
            decay_u = (u - peak_ratio) / (1.0 - peak_ratio)
            env = math.cos(decay_u * (math.pi / 2.0)) ** 1.9
            
        # Frequency sweep: rises rapidly to peak, then sweeps downward
        if u < peak_ratio:
            sweep_u = math.sin((u / peak_ratio) * (math.pi / 2.0))
            fc = freq_start + (freq_peak - freq_start) * sweep_u
        else:
            decay_u = (u - peak_ratio) / (1.0 - peak_ratio)
            fc = freq_peak - (freq_peak - freq_end) * math.sin(decay_u * (math.pi / 2.0))
            
        fc = max(100.0, min(SAMPLE_RATE * 0.45, fc))
        
        # Cytomic SVF
        g = math.tan(math.pi * fc / SAMPLE_RATE)
        k = 1.0 / q
        a1 = 1.0 / (1.0 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        
        v0 = noise[i]
        v3 = v0 - ic2eq
        v1 = a1 * ic1eq + a2 * v3
        v2 = ic2eq + a2 * ic1eq + a3 * v3
        ic1eq = 2.0 * v1 - ic1eq
        ic2eq = 2.0 * v2 - ic2eq
        
        bp = v1
        hp = v0 - k * v1 - v2
        
        # Mix 75% bandpass, 25% highpass for airy sweep
        filtered = bp * 0.75 + hp * 0.25
        
        # Clean sub tone (sine wave tracking the frequency sweep)
        sub_freq = max(110.0, fc * 0.20)
        sub_phase += 2.0 * math.pi * sub_freq / SAMPLE_RATE
        sub = math.sin(sub_phase) * math.sin(u * math.pi)
        
        combined = (filtered * 1.5 + sub * sub_blend) * env
        
        # Edge fades to prevent any click
        if i < fade_in_samples:
            combined *= (i / fade_in_samples)
        elif i > num_samples - fade_out_samples:
            combined *= ((num_samples - i) / fade_out_samples)
            
        # Warm soft clipping
        sample = math.tanh(combined * 1.3)
        output_samples.append(sample)
        
    # Normalize peak to approx 0.70 (-3 dB)
    peak = max(abs(s) for s in output_samples) if output_samples else 1.0
    target_peak = 0.70
    gain = target_peak / max(0.001, peak)
    
    out_dir = os.path.dirname(filename)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        
    with wave.open(filename, 'wb') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        data = bytearray()
        for s in output_samples:
            val = int(max(-32767, min(32767, s * gain * 32767)))
            data.extend(struct.pack('<h', val))
        wav_file.writeframes(data)
    print(f"Generated {filename} ({duration:.2f}s, peak {peak:.2f} -> {target_peak})")

def main():
    # 3 snappy, crisp variations
    generate_swoosh("sounds/letter_swoosh_1.wav", duration=0.22, freq_start=360, freq_peak=4000, freq_end=750, peak_ratio=0.35, q=2.7, seed=101)
    generate_swoosh("sounds/letter_swoosh_2.wav", duration=0.20, freq_start=400, freq_peak=4600, freq_end=850, peak_ratio=0.33, q=2.9, seed=202)
    generate_swoosh("sounds/letter_swoosh_3.wav", duration=0.24, freq_start=320, freq_peak=3700, freq_end=680, peak_ratio=0.37, q=2.6, seed=303)
    generate_swoosh("sounds/letter_swoosh.wav", duration=0.22, freq_start=370, freq_peak=4200, freq_end=780, peak_ratio=0.35, q=2.8, seed=404)

if __name__ == "__main__":
    main()
