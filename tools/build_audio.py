"""Generates every sound effect and music track of the game, in code.

Retro synthesis in the style of sfxr: square, triangle and noise oscillators
with pitch slides, envelopes and a simple low-pass filter. Free, needs no
service or model, and is reproducible (fixed random seeds), so a sound can
be tweaked here and regenerated. Run from the project root:

    python tools/build_audio.py

Writes 16-bit mono WAV files to assets/audio/sfx/ and assets/audio/music/.
The file name (without .wav) is the id the game plays it by (see
AudioManager.play_sound).
"""

from pathlib import Path
import wave

import numpy as np

SAMPLE_RATE = 22050
SFX_DIR = Path("assets/audio/sfx")
MUSIC_DIR = Path("assets/audio/music")


# --- Building blocks ----------------------------------------------------------

def timeline(seconds):
    return np.arange(int(seconds * SAMPLE_RATE)) / SAMPLE_RATE


def phase_from(frequency):
    """Running phase (in cycles) of a frequency that may change over time."""
    frequency = np.broadcast_to(frequency, frequency.shape if np.ndim(frequency) else (1,))
    return np.cumsum(frequency) / SAMPLE_RATE


def square(frequency, duty=0.5):
    return np.where(phase_from(frequency) % 1.0 < duty, 1.0, -1.0)


def triangle(frequency):
    return 4.0 * np.abs((phase_from(frequency) % 1.0) - 0.5) - 1.0


def sine(frequency):
    return np.sin(2 * np.pi * phase_from(frequency))


def noise(seconds, seed, hold_samples=1):
    """White noise; holding each value for a few samples makes it rougher and
    lower, like the noise channel of old consoles."""
    rng = np.random.default_rng(seed)
    count = int(seconds * SAMPLE_RATE)
    values = rng.uniform(-1.0, 1.0, count // hold_samples + 1)
    return np.repeat(values, hold_samples)[:count]


def slide(start, end, seconds, curve=1.0):
    """A frequency going from start to end over the sound."""
    t = np.linspace(0.0, 1.0, int(seconds * SAMPLE_RATE))
    return start + (end - start) * t ** curve


def envelope(seconds, attack=0.005, decay_power=1.0, hold=0.0):
    """Quick attack, optional hold at full level, then a decay to silence."""
    count = int(seconds * SAMPLE_RATE)
    t = np.arange(count) / SAMPLE_RATE
    level = np.ones(count)
    attack_part = t < attack
    level[attack_part] = t[attack_part] / attack
    decay_start = attack + hold
    decay_part = t >= decay_start
    remaining = max(seconds - decay_start, 1e-6)
    level[decay_part] = np.clip(1.0 - (t[decay_part] - decay_start) / remaining, 0.0, 1.0) ** decay_power
    return level


def low_pass(signal, cutoff):
    """One-pole low-pass. cutoff may be a number or an array (a sweep)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), signal.shape)
    alpha = 1.0 - np.exp(-2 * np.pi * cutoff / SAMPLE_RATE)
    out = np.empty_like(signal)
    previous = 0.0
    for index in range(len(signal)):
        previous += alpha[index] * (signal[index] - previous)
        out[index] = previous
    return out


def fit(signal, seconds):
    count = int(seconds * SAMPLE_RATE)
    if len(signal) >= count:
        return signal[:count]
    return np.concatenate([signal, np.zeros(count - len(signal))])


def mix(*signals):
    length = max(len(signal) for signal in signals)
    return sum(fit(signal, length / SAMPLE_RATE) for signal in signals)


def sequence(*parts):
    return np.concatenate(parts)


def silence(seconds):
    return np.zeros(int(seconds * SAMPLE_RATE))


def note_frequency(name):
    """'A4' -> 440.0. Sharps as 'C#4'."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
             "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave - 4)) / 12)


def write(path, signal, peak=0.8, rate=SAMPLE_RATE):
    path.parent.mkdir(parents=True, exist_ok=True)
    top = np.max(np.abs(signal))
    if top > 0:
        signal = signal / top * peak
    # Tiny fades so no file starts or ends with a click.
    fade = min(64, len(signal) // 4)
    signal[:fade] *= np.linspace(0.0, 1.0, fade)
    signal[-fade:] *= np.linspace(1.0, 0.0, fade)
    samples = (signal * 32767).astype("<i2")
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(samples.tobytes())
    print(f"wrote {path} ({len(signal) / rate:.2f}s at {rate} Hz)")


# --- Sound effects -----------------------------------------------------------

def dig_earth():
    """A shovelful of earth: a soft low crunch."""
    seconds = 0.14
    crunch = low_pass(noise(seconds, seed=1, hold_samples=3), 900) * envelope(seconds, decay_power=2)
    thud = sine(slide(140, 70, seconds)) * envelope(seconds, decay_power=3) * 0.6
    return mix(crunch, thud)


def pickaxe_hit():
    """Pickaxe biting earth: a short metallic tick on top of a crunch."""
    seconds = 0.16
    tick = square(slide(1800, 1500, 0.05), duty=0.25) * envelope(0.05, decay_power=3) * 0.35
    crunch = low_pass(noise(seconds, seed=2, hold_samples=2), 1400) * envelope(seconds, decay_power=2)
    return mix(tick, crunch)


def jackhammer_hit():
    """One burst of the jackhammer: three fast rattles of bright noise."""
    rattle = low_pass(noise(0.035, seed=3), 3500) * envelope(0.035, decay_power=2)
    knock = square(slide(220, 160, 0.035)) * envelope(0.035, decay_power=2) * 0.4
    hit = mix(rattle, knock)
    return sequence(hit, silence(0.015), hit * 0.9, silence(0.015), hit * 0.8)


def place_block():
    """A block of earth set down: a dull thump."""
    seconds = 0.18
    thump = sine(slide(180, 60, seconds, curve=0.5)) * envelope(seconds, decay_power=2)
    dust = low_pass(noise(seconds, seed=4, hold_samples=4), 600) * envelope(seconds, decay_power=3) * 0.5
    return mix(thump, dust)


def place_brick():
    """A plank or brick laid (diagonal ladder, bridge): a wooden knock."""
    seconds = 0.09
    knock = triangle(slide(620, 420, seconds)) * envelope(seconds, decay_power=3)
    click = low_pass(noise(0.02, seed=5), 4000) * envelope(0.02, decay_power=2) * 0.4
    return mix(knock, click)


def place_ladder():
    """A ladder segment hooked on: two quick wooden knocks."""
    return sequence(place_brick(), silence(0.03), place_brick() * 0.7)


def fuse():
    """A fuse lit: a fizzing hiss."""
    seconds = 0.5
    hiss = low_pass(noise(seconds, seed=6), 5000) - low_pass(noise(seconds, seed=6), 1500)
    flicker = 0.6 + 0.4 * square(np.full(int(seconds * SAMPLE_RATE), 23.0))
    return hiss * flicker * envelope(seconds, attack=0.02, decay_power=1.5)


def explosion():
    """A blast: a deep boom under a roar of noise that darkens as it fades."""
    seconds = 1.2
    count = int(seconds * SAMPLE_RATE)
    roar = noise(seconds, seed=7, hold_samples=4)
    roar = low_pass(roar, np.linspace(3000, 200, count)) * envelope(seconds, attack=0.004, decay_power=2.2)
    boom = sine(slide(90, 30, seconds, curve=0.6)) * envelope(seconds, attack=0.004, decay_power=1.6)
    return mix(roar, boom * 1.2)


def splat():
    """A fatal landing: a wet, falling splat."""
    seconds = 0.3
    body = low_pass(noise(seconds, seed=8, hold_samples=2), np.linspace(2500, 300, int(seconds * SAMPLE_RATE)))
    drop = square(slide(300, 60, seconds, curve=0.5), duty=0.3) * 0.35
    return mix(body, drop) * envelope(seconds, decay_power=2)


def spawn():
    """A lemming popping out of the entrance: a small rising blip."""
    seconds = 0.12
    return square(slide(330, 660, seconds), duty=0.25) * envelope(seconds, decay_power=1.5)


def saved():
    """A lemming through the exit: a happy three-note chime."""
    notes = ["E5", "G5", "C6"]
    parts = []
    for index, name in enumerate(notes):
        length = 0.07 if index < len(notes) - 1 else 0.18
        tone = square(np.full(int(length * SAMPLE_RATE), note_frequency(name)), duty=0.25)
        parts.append(tone * envelope(length, decay_power=1.2))
    return sequence(*parts)


def assign_tool():
    """A tool given to a lemming: a short confirming double blip."""
    def blip(frequency):
        return square(np.full(int(0.05 * SAMPLE_RATE), frequency), duty=0.5) * envelope(0.05, decay_power=1.5)
    return sequence(blip(880), silence(0.01), blip(1320))


def select_tool():
    """A tool button pressed: a tiny click."""
    seconds = 0.035
    return square(np.full(int(seconds * SAMPLE_RATE), 1200.0), duty=0.5) * envelope(seconds, decay_power=2)


def parachute():
    """A parachute opening: a whoosh that swells and settles."""
    seconds = 0.45
    count = int(seconds * SAMPLE_RATE)
    whoosh = low_pass(noise(seconds, seed=9), np.concatenate([np.linspace(300, 2500, count // 2), np.linspace(2500, 600, count - count // 2)]))
    return whoosh * envelope(seconds, attack=0.12, decay_power=1.5)


def level_won():
    """Level completed: a rising arpeggio ending on a held chord note."""
    notes = ["C5", "E5", "G5", "C6", "E6", "G6"]
    parts = []
    for index, name in enumerate(notes):
        length = 0.08 if index < len(notes) - 1 else 0.45
        tone = square(np.full(int(length * SAMPLE_RATE), note_frequency(name)), duty=0.25)
        parts.append(tone * envelope(length, decay_power=1.0))
    return sequence(*parts)


def level_lost():
    """Level failed: a slow sad descent."""
    notes = ["G4", "F#4", "F4", "E4"]
    parts = []
    for index, name in enumerate(notes):
        length = 0.22 if index < len(notes) - 1 else 0.6
        frequency = np.full(int(length * SAMPLE_RATE), note_frequency(name))
        vibrato = 1.0 + 0.01 * sine(np.full(len(frequency), 6.0))
        tone = triangle(frequency * vibrato)
        parts.append(tone * envelope(length, decay_power=1.0))
    return sequence(*parts)


def sacrifice():
    """A lemming sacrificed: a soft airy whoosh under a rising shimmer, a
    voluntary departure rather than the splat of an accident."""
    seconds = 0.6
    count = int(seconds * SAMPLE_RATE)
    air = low_pass(noise(seconds, seed=12), np.linspace(400, 3000, count)) * 0.5
    shimmer = triangle(slide(440, 1760, seconds, curve=0.7)) * 0.4
    sparkle = square(slide(1320, 2640, seconds), duty=0.125) * 0.12
    return mix(air, shimmer, sparkle) * envelope(seconds, attack=0.04, decay_power=1.6)


SOUND_EFFECTS = {
    "dig_earth": dig_earth,
    "pickaxe_hit": pickaxe_hit,
    "jackhammer_hit": jackhammer_hit,
    "place_block": place_block,
    "place_brick": place_brick,
    "place_ladder": place_ladder,
    "fuse": fuse,
    "explosion": explosion,
    "splat": splat,
    "spawn": spawn,
    "saved": saved,
    "assign_tool": assign_tool,
    "select_tool": select_tool,
    "parachute": parachute,
    "level_won": level_won,
    "level_lost": level_lost,
    "sacrifice": sacrifice,
}


# --- Music -----------------------------------------------------------------
#
# The first version used the same raw square waves as the effects, at
# 22 kHz, plus a white-noise hi-hat. Raw squares at that rate alias (their
# harmonics above the Nyquist limit fold back as a high whine) and the noise
# hats hiss: the user heard both as a constant hiss. The music now uses
# band-limited tones built from only the harmonics that fit at 44.1 kHz,
# softer timbres, no noise hats, a gentle echo and a low-pass on the mix.

MUSIC_RATE = 44100
## Harmonic amplitudes of each instrument (1st harmonic first). Mostly odd
## harmonics falling off fast: a mellow, rounded square for the lead.
LEAD_HARMONICS = [1.0, 0.0, 0.30, 0.0, 0.14, 0.0, 0.07, 0.0, 0.035]
BASS_HARMONICS = [1.0, 0.35, 0.10]
ARPEGGIO_HARMONICS = [1.0, 0.45, 0.20, 0.08]
## Highest frequency any harmonic may reach, as a fraction of the sample
## rate (Nyquist is 0.5); keeps well clear of aliasing.
HARMONIC_CEILING = 0.4
MUSIC_LOW_PASS_HZ = 6500


def music_envelope(seconds, attack, release_power, hold_fraction=0.0):
    count = int(seconds * MUSIC_RATE)
    t = np.arange(count) / MUSIC_RATE
    level = np.ones(count)
    rising = t < attack
    level[rising] = t[rising] / attack
    decay_start = attack + seconds * hold_fraction
    falling = t >= decay_start
    remaining = max(seconds - decay_start, 1e-6)
    level[falling] = np.clip(1.0 - (t[falling] - decay_start) / remaining, 0.0, 1.0) ** release_power
    return level


def additive_tone(frequency, seconds, harmonics):
    """A tone made only of the harmonics that fit under HARMONIC_CEILING."""
    t = np.arange(int(seconds * MUSIC_RATE)) / MUSIC_RATE
    out = np.zeros(len(t))
    for number, amplitude in enumerate(harmonics, start=1):
        if amplitude == 0.0:
            continue
        if number * frequency >= MUSIC_RATE * HARMONIC_CEILING:
            break
        out += amplitude * np.sin(2 * np.pi * number * frequency * t)
    return out


def music_low_pass(signal, cutoff):
    alpha = 1.0 - np.exp(-2 * np.pi * cutoff / MUSIC_RATE)
    out = np.empty_like(signal)
    previous = 0.0
    for index in range(len(signal)):
        previous += alpha * (signal[index] - previous)
        out[index] = previous
    return out


def echo(signal, delay_seconds, feedback, repeats=3):
    """A few fading repeats, for a little space around the notes."""
    out = signal.copy()
    delay = int(delay_seconds * MUSIC_RATE)
    gain = feedback
    for repeat in range(1, repeats + 1):
        shift = delay * repeat
        if shift >= len(signal):
            break
        # Wraps around, so the echo of the loop's end lands on its start
        # and the loop stays seamless.
        out += np.roll(signal, shift) * gain
        gain *= feedback
    return out


def render_track(bpm, bars, chords, melody, bass_octave=2, drums=True):
    """A seamless loop of `bars` bars of 4 beats.

    chords: one chord per bar, as a list of note names (root first).
    melody: a list of (note name or None, length in eighths), covering all
    the bars; None is a rest.
    """
    beat = 60.0 / bpm
    eighth = beat / 2
    count = int(bars * 4 * beat * MUSIC_RATE)

    def place(track, signal, start_seconds):
        start = int(start_seconds * MUSIC_RATE)
        end = min(start + len(signal), count)
        if start < count:
            track[start:end] += signal[: end - start]

    lead = np.zeros(count)
    position = 0.0
    for name, eighths in melody:
        length = eighths * eighth
        if name is not None:
            tone = additive_tone(note_frequency(name), length, LEAD_HARMONICS)
            place(lead, tone * music_envelope(length, 0.015, 0.8, hold_fraction=0.35), position)
        position += length

    bass = np.zeros(count)
    arpeggio = np.zeros(count)
    for bar, chord in enumerate(chords):
        bar_start = bar * 4 * beat
        root = chord[0][:-1] + str(bass_octave)
        fifth = chord[min(2, len(chord) - 1)][:-1] + str(bass_octave)
        for step in range(8):
            name = root if step % 2 == 0 else fifth
            tone = additive_tone(note_frequency(name), eighth, BASS_HARMONICS)
            place(bass, tone * music_envelope(eighth, 0.01, 1.2), bar_start + step * eighth)
        for step in range(16):
            name = chord[step % len(chord)]
            length = eighth / 2
            tone = additive_tone(note_frequency(name) * 2, length, ARPEGGIO_HARMONICS)
            place(arpeggio, tone * music_envelope(length, 0.005, 2.0), bar_start + step * length)

    track = lead * 0.30 + bass * 0.40 + arpeggio * 0.10
    if drums:
        t_kick = np.arange(int(0.16 * MUSIC_RATE)) / MUSIC_RATE
        kick = np.sin(2 * np.pi * np.cumsum(np.linspace(140, 45, len(t_kick))) / MUSIC_RATE) * music_envelope(0.16, 0.002, 2.5)
        rng = np.random.default_rng(12)
        snare_noise = music_low_pass(rng.uniform(-1, 1, int(0.12 * MUSIC_RATE)), 1800)
        snare = (snare_noise * 2.5 + additive_tone(190, 0.12, [1.0]) * 0.3) * music_envelope(0.12, 0.002, 3.0)
        drum_track = np.zeros(count)
        for bar in range(bars):
            bar_start = bar * 4 * beat
            for step in (0, 4):
                place(drum_track, kick, bar_start + step * eighth)
            for step in (2, 6):
                place(drum_track, snare * 0.5, bar_start + step * eighth)
        track += drum_track * 0.40

    track = echo(track, eighth * 1.5, 0.22)
    return music_low_pass(track, MUSIC_LOW_PASS_HZ)


def level_theme():
    """Bouncy, busy loop for playing a level."""
    chords = [["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"]] * 2
    melody = [
        ("E5", 2), ("G5", 1), ("E5", 1), ("C5", 2), ("D5", 2),
        ("E5", 2), ("C5", 2), ("A4", 4),
        ("F4", 2), ("A4", 1), ("C5", 1), ("F5", 2), ("E5", 2),
        ("D5", 3), ("B4", 1), ("G4", 4),
        ("E5", 2), ("G5", 1), ("E5", 1), ("C5", 2), ("E5", 2),
        ("A5", 2), ("G5", 2), ("E5", 4),
        ("F5", 2), ("E5", 1), ("D5", 1), ("C5", 2), ("A4", 2),
        ("B4", 2), ("D5", 2), ("C5", 4),
    ]
    return render_track(bpm=132, bars=8, chords=chords, melody=melody)


def menu_theme():
    """Calmer loop for the menu and the editor."""
    chords = [["A3", "C4", "E4"], ["F3", "A3", "C4"], ["C4", "E4", "G4"], ["G3", "B3", "D4"]] * 2
    melody = [
        ("E5", 4), ("C5", 2), ("D5", 2),
        ("C5", 4), ("A4", 4),
        ("A4", 2), ("C5", 2), ("F5", 4),
        ("E5", 6), (None, 2),
        ("E5", 4), ("G5", 2), ("E5", 2),
        ("D5", 4), ("C5", 4),
        ("B4", 2), ("C5", 2), ("D5", 4),
        ("B4", 6), (None, 2),
    ]
    return render_track(bpm=96, bars=8, chords=chords, melody=melody, drums=False)


MUSIC = {
    "level_theme": level_theme,
    "menu_theme": menu_theme,
}


def main():
    for name, build in SOUND_EFFECTS.items():
        write(SFX_DIR / f"{name}.wav", build())
    for name, build in MUSIC.items():
        write(MUSIC_DIR / f"{name}.wav", build(), peak=0.7, rate=MUSIC_RATE)


if __name__ == "__main__":
    main()
