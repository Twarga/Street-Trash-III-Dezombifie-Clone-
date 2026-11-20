import os, subprocess, tempfile
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

ROOT = os.path.expanduser('~/projects/street_trash_dezombifier')
VO_DIR = os.path.join(ROOT, 'assets/audio/vo')
os.makedirs(VO_DIR, exist_ok=True)

kokoro = Kokoro(
    os.path.expanduser('~/kokoro-web/kokoro-v1.0.onnx'),
    os.path.expanduser('~/kokoro-web/voices-v1.0.bin'),
)
voices = list(kokoro.get_voices()) if hasattr(kokoro, 'get_voices') else ['af_bella']
voice = 'af_bella' if 'af_bella' in voices else ( 'af_sarah' if 'af_sarah' in voices else voices[0] )
print('Using Kokoro voice:', voice)

LINES = {
    'vo_intro_1': 'Anyone who has not been turned into a brain munching freak down there should head to the High Rise in the quarantine zone. Extraction procedures are now operational.',
    'vo_intro_2': 'See that timer ticking down? That is how long you have to find six gears and reach the High Rise before the city gets a nuclear makeover. No pressure, I guess.',
    'vo_gear_1': 'See, I knew you could salvage something. Just five more gears left to find.',
    'vo_gear_2': 'Two gears down. Keep moving through the neon strip and watch those burning wrecks.',
    'vo_gear_3': 'Halfway there! Three gears salvaged. The infected are swarming thicker ahead.',
    'vo_gear_4': 'Four gears secured. Only two left before extraction clears.',
    'vo_gear_5': 'Five gears! One last salvage and the High Rise gate unlocks.',
    'vo_gear_6': 'All six gears collected! Sprint to the High Rise extraction plaza now!',
    'vo_boss': 'Warning! Heavy bio-signature ahead. A High Rise Brute just broke containment!',
    'vo_two_min': 'Two minutes until nuclear strike! Move it or you are vapor!',
    'vo_holdout': 'Extraction chopper inbound! Hold the High Rise pad for ninety seconds!',
    'vo_victory': 'Chopper locked on! You made it out of the quarantine zone alive. Welcome back.',
}

def make_squelch(sr, dur=0.07):
    n = int(sr * dur)
    t = np.linspace(0, dur, n, endpoint=False)
    noise = np.random.uniform(-1, 1, n) * np.exp(-t * 38.0)
    chirp = np.sin(2 * np.pi * (1400 - 600 * t / dur) * t) * np.exp(-t * 50.0)
    return (0.28 * noise + 0.18 * chirp).astype(np.float32)

with tempfile.TemporaryDirectory() as tmp:
    for slug, text in LINES.items():
        samples, sr = kokoro.create(text, voice=voice, speed=1.06, lang='en-us')
        samples = np.asarray(samples, dtype=np.float32)
        # Add tiny radio static bed & walkie-talkie squelch clicks
        static = np.random.normal(0, 0.008, len(samples)).astype(np.float32)
        sq = make_squelch(sr)
        full = np.concatenate([sq, samples + static, sq * 0.8])
        raw_wav = os.path.join(tmp, slug + '.wav')
        out_ogg = os.path.join(VO_DIR, slug + '.ogg')
        sf.write(raw_wav, full, sr)
        subprocess.run([
            'ffmpeg', '-y', '-loglevel', 'error', '-i', raw_wav,
            '-af', 'highpass=f=340,lowpass=f=3200,acompressor=threshold=-16dB:ratio=4:attack=5:release=60,alimiter=limit=0.92',
            '-c:a', 'libvorbis', '-q:a', '5', out_ogg
        ], check=True)
        print('Generated VO:', out_ogg)
print('All 12 Kokoro radio VO lines generated!')
