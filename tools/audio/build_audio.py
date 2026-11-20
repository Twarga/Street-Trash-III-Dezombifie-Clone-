import os, subprocess, tempfile, math
import numpy as np
import wave

ROOT = os.path.expanduser('~/projects/street_trash_dezombifier')
SFX_DIR = os.path.join(ROOT, 'assets/audio/sfx')
MUS_DIR = os.path.join(ROOT, 'assets/audio/music')
os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(MUS_DIR, exist_ok=True)

SR = 44100

def save_wav(path, data):
    data = np.clip(data, -0.98, 0.98)
    pcm = (data * 32767.0).astype(np.int16)
    with wave.open(path, 'wb') as wf:
        wf.setnchannels(1 if pcm.ndim == 1 else pcm.shape[1])
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())

def save_ogg(path, data):
    with tempfile.TemporaryDirectory() as tmp:
        w = os.path.join(tmp, 'in.wav')
        save_wav(w, data)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', w, '-c:a', 'libvorbis', '-q:a', '5', path], check=True)

def lp_filter(x, cutoff_hz):
    # Fast 1-pole lowpass
    rc = 1.0 / (2.0 * math.pi * max(20.0, cutoff_hz))
    dt = 1.0 / SR
    a = dt / (rc + dt)
    y = np.empty_like(x)
    prev = 0.0
    for i in range(len(x)):
        prev = prev + a * (x[i] - prev)
        y[i] = prev
    return y

def hp_filter(x, cutoff_hz):
    return x - lp_filter(x, cutoff_hz)

def saw(phase):
    return 2.0 * (phase - np.floor(phase + 0.5))

def square(phase):
    return np.where(np.sin(2.0 * np.pi * phase) >= 0, 1.0, -1.0)

rng = np.random.default_rng(2026)

# ---- 1. PUNCHY SFX BANK ----
def make_gunshot(dur, body_hz, snap_amt, tail_decay, gain=0.9):
    n = int(SR * dur)
    t = np.linspace(0, dur, n, endpoint=False)
    noise = rng.uniform(-1, 1, n)
    crack = hp_filter(noise, 1200) * np.exp(-t * 55.0) * snap_amt
    body_f = body_hz * np.exp(-t * 18.0) + 45.0
    body_ph = np.cumsum(body_f) / SR
    body = np.sin(2 * np.pi * body_ph) * np.exp(-t * 24.0) * 0.85
    tail = lp_filter(noise, 900) * np.exp(-t * tail_decay) * 0.55
    sig = np.tanh((crack + body + tail) * 1.9) * gain
    return sig

save_wav(os.path.join(SFX_DIR, 'pistol.wav'), make_gunshot(0.22, 220, 1.1, 16, 0.85))
save_wav(os.path.join(SFX_DIR, 'smg.wav'), make_gunshot(0.14, 290, 1.0, 26, 0.72))
save_wav(os.path.join(SFX_DIR, 'shotgun.wav'), make_gunshot(0.45, 130, 1.4, 8.5, 0.96))
save_wav(os.path.join(SFX_DIR, 'rifle.wav'), make_gunshot(0.24, 185, 1.25, 14, 0.88))
save_wav(os.path.join(SFX_DIR, 'hmg.wav'), make_gunshot(0.26, 150, 1.3, 12, 0.92))

# Flamethrower loopable whoosh
t_fl = np.linspace(0, 0.6, int(SR * 0.6), endpoint=False)
fl_n = lp_filter(rng.uniform(-1, 1, len(t_fl)), 650) * (0.7 + 0.3 * np.sin(2*np.pi*9*t_fl))
save_wav(os.path.join(SFX_DIR, 'flamethrower.wav'), np.tanh(fl_n * 2.2) * 0.65)

# Wet flesh hit
t = np.linspace(0, 0.14, int(SR * 0.14), endpoint=False)
flesh = lp_filter(rng.uniform(-1, 1, len(t)), 1100) * np.exp(-t * 32) * 0.7 + np.sin(2*np.pi*(160*np.exp(-t*20))*t) * np.exp(-t*28) * 0.65
save_wav(os.path.join(SFX_DIR, 'hit_flesh.wav'), np.tanh(flesh * 1.8) * 0.8)

# Metallic armor ping (Riot Bruiser)
t = np.linspace(0, 0.22, int(SR * 0.22), endpoint=False)
ping = (np.sin(2*np.pi*1840*t) + 0.6*np.sin(2*np.pi*2790*t) + 0.4*np.sin(2*np.pi*4120*t)) * np.exp(-t * 22)
save_wav(os.path.join(SFX_DIR, 'hit_armor.wav'), np.tanh(ping * 1.3) * 0.75)

# Critical hit crunch + metallic glint
t = np.linspace(0, 0.22, int(SR * 0.22), endpoint=False)
crit = hp_filter(rng.uniform(-1, 1, len(t)), 1500) * np.exp(-t*35)*0.8 + np.sin(2*np.pi*980*t)*np.exp(-t*18)*0.55 + np.sin(2*np.pi*1470*t)*np.exp(-t*22)*0.4
save_wav(os.path.join(SFX_DIR, 'hit_crit.wav'), np.tanh(crit * 1.5) * 0.88)

# Zombie groans (3 pitches)
for idx, f0 in enumerate([92.0, 118.0, 74.0], 1):
    dur = 0.75
    t = np.linspace(0, dur, int(SR * dur), endpoint=False)
    env = np.sin(np.pi * t / dur) ** 0.7
    vib = f0 * (1.0 - 0.18 * t / dur + 0.04 * np.sin(2*np.pi*11*t))
    ph = np.cumsum(vib) / SR
    raw = saw(ph) * 0.6 + lp_filter(rng.uniform(-1, 1, len(t)), 500) * 0.45
    g = lp_filter(raw, 560.0) * env
    save_wav(os.path.join(SFX_DIR, f'zombie_groan_{idx}.wav'), np.tanh(g * 2.1) * 0.65)

# Zombie death & Bloater acid pop
t = np.linspace(0, 0.35, int(SR * 0.35), endpoint=False)
zd = lp_filter(rng.uniform(-1, 1, len(t)), 700) * np.exp(-t*11) * 0.8 + np.sin(2*np.pi*(120*np.exp(-t*5))*t)*np.exp(-t*12)*0.5
save_wav(os.path.join(SFX_DIR, 'zombie_death.wav'), np.tanh(zd * 1.8) * 0.75)

t = np.linspace(0, 0.5, int(SR * 0.5), endpoint=False)
pop = np.sin(2*np.pi*(260*np.exp(-t*14)+40)*t)*np.exp(-t*10)*0.85 + hp_filter(rng.uniform(-1, 1, len(t)), 1400)*np.exp(-t*6)*0.55
save_wav(os.path.join(SFX_DIR, 'bloater_pop.wav'), np.tanh(pop * 2.0) * 0.9)

# Huge Car Explosion
t = np.linspace(0, 1.4, int(SR * 1.4), endpoint=False)
noise = rng.uniform(-1, 1, len(t))
sub = np.sin(2*np.pi*(95*np.exp(-t*4.5)+28)*t) * np.exp(-t*3.2) * 1.2
rumble = lp_filter(noise, 280) * np.exp(-t*2.4) * 1.1
debris = hp_filter(noise, 1800) * np.exp(-t*5.5) * 0.55
save_wav(os.path.join(SFX_DIR, 'explosion.wav'), np.tanh((sub + rumble + debris) * 1.5) * 0.96)

# Dash whoosh & Player hurt
t = np.linspace(0, 0.24, int(SR * 0.24), endpoint=False)
dash = lp_filter(rng.uniform(-1, 1, len(t)), 1400) * np.sin(np.pi * t / 0.24) * 0.85
save_wav(os.path.join(SFX_DIR, 'dash_whoosh.wav'), dash)

t = np.linspace(0, 0.28, int(SR * 0.28), endpoint=False)
hurt = np.sin(2*np.pi*(140*np.exp(-t*9)+42)*t)*np.exp(-t*10)*0.9 + lp_filter(rng.uniform(-1,1,len(t)), 600)*np.exp(-t*16)*0.6
save_wav(os.path.join(SFX_DIR, 'player_hurt.wav'), np.tanh(hurt * 1.9) * 0.9)

# Pickups & Level-Up / Card UI
def tone_chord(freqs, dur, decay=6.0):
    t = np.linspace(0, dur, int(SR * dur), endpoint=False)
    s = np.zeros_like(t)
    for i, f in enumerate(freqs):
        delay = int(i * 0.055 * SR)
        if delay < len(t):
            tt = t[:len(t)-delay]
            s[delay:] += (np.sin(2*np.pi*f*tt) + 0.3*np.sin(2*np.pi*f*2*tt)) * np.exp(-tt * decay)
    return np.tanh(s * 0.65) * 0.85

save_wav(os.path.join(SFX_DIR, 'pickup_gear.wav'), tone_chord([523.25, 659.25, 783.99, 1046.5], 0.55, 5.5))
save_wav(os.path.join(SFX_DIR, 'pickup_health.wav'), tone_chord([440.0, 554.37, 659.25], 0.42, 7.0))
save_wav(os.path.join(SFX_DIR, 'level_up.wav'), tone_chord([293.66, 369.99, 440.0, 587.33, 739.99], 0.85, 3.8))

t = np.linspace(0, 0.06, int(SR * 0.06), endpoint=False)
save_wav(os.path.join(SFX_DIR, 'card_hover.wav'), np.sin(2*np.pi*660*t)*np.exp(-t*65)*0.45)
save_wav(os.path.join(SFX_DIR, 'card_confirm.wav'), tone_chord([330.0, 660.0], 0.25, 11.0))
save_wav(os.path.join(SFX_DIR, 'card_redraw.wav'), hp_filter(rng.uniform(-1,1,int(SR*0.18)), 1600)*np.exp(-np.linspace(0,0.18,int(SR*0.18))*18)*0.55)

# Garage shutter metallic rumble
t = np.linspace(0, 2.2, int(SR * 2.2), endpoint=False)
sh = lp_filter(rng.uniform(-1,1,len(t)), 340)*0.75 + np.sin(2*np.pi*58*t)*0.35 + hp_filter(rng.uniform(-1,1,len(t)), 2400)*(0.2+0.2*np.sin(2*np.pi*18*t))
env_sh = np.clip(t/0.2, 0, 1) * np.clip((2.2-t)/0.25, 0, 1)
save_wav(os.path.join(SFX_DIR, 'shutter_open.wav'), np.tanh(sh * env_sh * 1.4) * 0.7)

# Nuclear / Extraction Siren pulse
t = np.linspace(0, 1.5, int(SR * 1.5), endpoint=False)
siren_f = 480 + 260 * np.sin(2*np.pi*0.66*t - np.pi/2)
siren = np.sin(2*np.pi*np.cumsum(siren_f)/SR) * 0.55 + 0.2*saw(np.cumsum(siren_f)/SR)
save_wav(os.path.join(SFX_DIR, 'siren_alarm.wav'), lp_filter(siren, 1600) * 0.55)

# ---- 2. ADAPTIVE DARK-SYNTHWAVE MUSIC STEMS (124 BPM, 8 BARS EXACT LOOP) ----
BPM = 124.0
BEAT = 60.0 / BPM
BARS = 8
DUR = BARS * 4 * BEAT
N = int(round(DUR * SR))
T = np.linspace(0, DUR, N, endpoint=False)
STEP = BEAT / 4.0 # 16th note

# D minor dark industrial progression: Dm - Bb - C - A (2 bars each)
bass_roots = [73.42, 73.42, 58.27, 58.27, 65.41, 65.41, 55.00, 55.00] # D2, Bb1, C2, A1

def make_stem(mode):
    mix = np.zeros(N, dtype=np.float32)
    # 1. Driving 16th-note dark synth bass
    bass = np.zeros(N, dtype=np.float32)
    num_steps = BARS * 16
    for s in range(num_steps):
        bar = s // 16
        root = bass_roots[bar]
        freq = root * (2.0 if (s % 4 == 2 and mode != 'explore') else 1.0)
        if mode == 'chaos' and (s % 2 == 1):
            freq *= 1.5
        i0 = int(s * STEP * SR)
        i1 = min(N, int((s + 1) * STEP * SR))
        lt = np.linspace(0, (i1 - i0) / SR, i1 - i0, endpoint=False)
        env = np.exp(-lt * (11.0 if mode == 'explore' else 8.5))
        ph = lt * freq
        tone = (saw(ph) * 0.65 + np.sin(2*np.pi*ph) * 0.55) * env
        bass[i0:i1] += tone
    cutoff = {'explore': 380, 'combat': 820, 'chaos': 1600, 'extraction': 1250}[mode]
    mix += lp_filter(bass, cutoff) * 0.48

    # 2. Eerie dark pad (D minor chord drone)
    pad = np.zeros(N, dtype=np.float32)
    for mult in [2.0, 2.378, 2.996]: # root, minor 3rd, 5th
        f = 73.42 * mult
        pad += np.sin(2*np.pi*f*T + 0.3*np.sin(2*np.pi*0.25*T)) * 0.14
    mix += lp_filter(pad, 650) * (0.45 if mode == 'explore' else 0.25)

    # 3. Industrial Drums (combat, chaos, extraction)
    if mode != 'explore':
        for b in range(BARS * 4):
            i0 = int(b * BEAT * SR)
            # Punchy Kick on every beat
            kn = min(N - i0, int(0.18 * SR))
            kt = np.linspace(0, kn/SR, kn, endpoint=False)
            kf = 135.0 * np.exp(-kt * 26.0) + 42.0
            kick = np.sin(2*np.pi*np.cumsum(kf)/SR) * np.exp(-kt * 12.0) * 0.65
            mix[i0:i0+kn] += kick
            # Snare on beats 2 and 4
            if b % 2 == 1:
                sn = min(N - i0, int(0.20 * SR))
                st = np.linspace(0, sn/SR, sn, endpoint=False)
                snare = (hp_filter(rng.uniform(-1,1,sn), 900)*0.55 + np.sin(2*np.pi*190*st)*0.4) * np.exp(-st*16.0)
                mix[i0:i0+sn] += snare * 0.52
        # 16th Hi-hats
        for s in range(num_steps):
            if mode == 'combat' and (s % 2 == 0): continue
            i0 = int(s * STEP * SR)
            hn = min(N - i0, int(0.05 * SR))
            ht = np.linspace(0, hn/SR, hn, endpoint=False)
            hh = hp_filter(rng.uniform(-1,1,hn), 5500) * np.exp(-ht * 70.0) * 0.18
            mix[i0:i0+hn] += hh

    # 4. Lead Arpeggio (chaos & extraction)
    if mode in ('chaos', 'extraction'):
        arp_notes = [293.66, 349.23, 440.0, 523.25, 440.0, 349.23, 329.63, 293.66]
        for s in range(num_steps):
            f = arp_notes[s % len(arp_notes)] * (1.0 if (s // 16) % 2 == 0 else 1.189)
            i0 = int(s * STEP * SR)
            i1 = min(N, int((s + 0.9) * STEP * SR))
            lt = np.linspace(0, (i1 - i0)/SR, i1 - i0, endpoint=False)
            lead = (saw(lt * f) * 0.5 + square(lt * f * 0.5) * 0.3) * np.exp(-lt * 10.0)
            mix[i0:i1] += lp_filter(lead, 2400) * 0.24

    # 5. Extraction urgent pulse
    if mode == 'extraction':
        pulse = np.sin(2*np.pi*880*T) * (0.5 + 0.5*np.sin(2*np.pi*(1.0/BEAT)*T))**6 * 0.08
        mix += pulse

    # Stereo subtle widen + master limiter
    left = np.tanh(mix * 1.35) * 0.72
    right = np.tanh(np.roll(mix, 18) * 1.35) * 0.72
    return np.stack([left, right], axis=-1)

for m in ['explore', 'combat', 'chaos', 'extraction']:
    save_ogg(os.path.join(MUS_DIR, f'music_{m}.ogg'), make_stem(m))
    print('Generated music stem:', m)

print('All SFX and adaptive dark-synthwave stems generated on tlab!')
