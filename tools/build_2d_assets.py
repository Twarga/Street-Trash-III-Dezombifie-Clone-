import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.expanduser('~/projects/street_trash_dezombifier')
UI_DIR = os.path.join(ROOT, 'assets/ui')
TEX_DIR = os.path.join(ROOT, 'assets/textures')
os.makedirs(UI_DIR, exist_ok=True)
os.makedirs(TEX_DIR, exist_ok=True)

def find_font(size):
    candidates = [
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
        '/usr/share/fonts/truetype/freefont/FreeSansBold.ttf',
    ]
    for p in candidates:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

# 1. Clean & crop perk art + portraits (removes any outer comic border margins)
crops = {
    'perk_combat.jpg': ('perk_combat.png', 0.02, 512),
    'perk_survival.jpg': ('perk_survival.png', 0.05, 512),
    'perk_mobility.jpg': ('perk_mobility.png', 0.02, 512),
    'perk_economy.jpg': ('perk_economy.png', 0.06, 512),
    'perk_chaos.jpg': ('perk_chaos.png', 0.02, 512),
    'perk_loadout.jpg': ('perk_loadout.png', 0.02, 512),
    'perk_duality.jpg': ('perk_duality.png', 0.02, 512),
    'survivor_portrait.jpg': ('survivor_portrait.png', 0.03, 256),
    'survivor_hurt.jpg': ('survivor_hurt.png', 0.07, 256),
}
for src, (dst, margin, sz) in crops.items():
    p = os.path.join(UI_DIR, src)
    if os.path.exists(p):
        im = Image.open(p).convert('RGBA')
        w, h = im.size
        mx, my = int(w * margin), int(h * margin)
        im = im.crop((mx, my, w - mx, h - my)).resize((sz, sz), Image.Resampling.LANCZOS)
        im.save(os.path.join(UI_DIR, dst))
        os.remove(p)

# Convert title_splash to PNG
sp = os.path.join(UI_DIR, 'title_splash.jpg')
if os.path.exists(sp):
    Image.open(sp).convert('RGB').resize((1280, 720), Image.Resampling.LANCZOS).save(os.path.join(UI_DIR, 'title_splash.png'))
    os.remove(sp)

# Key out solid black background on title_logo cleanly preserving red/green glow
lp = os.path.join(UI_DIR, 'title_logo_raw.jpg')
if os.path.exists(lp):
    im = Image.open(lp).convert('RGBA').resize((1024, 576), Image.Resampling.LANCZOS)
    arr = np.array(im, dtype=np.float32)
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    maxc = np.maximum(np.maximum(r, g), b)
    # Keep dark interior of letters via morphological fill of bright mask
    bright = (maxc > 32).astype(np.uint8) * 255
    mask_img = Image.fromarray(bright).filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(2))
    mask = np.array(mask_img, dtype=np.float32) / 255.0
    lum_alpha = np.clip((maxc - 12.0) / 38.0, 0.0, 1.0)
    alpha = np.maximum(lum_alpha, mask * 0.96)
    # Ensure pure black corners are 0
    alpha = np.where((maxc < 18) & (mask < 0.25), 0.0, alpha)
    arr[:,:,3] = np.clip(alpha * 255.0, 0, 255)
    Image.fromarray(arr.astype(np.uint8)).save(os.path.join(UI_DIR, 'title_logo.png'))
    os.remove(lp)

# 2. Procedural Tileable Wet Asphalt PBR (Albedo, Normal, ORM with puddles!)
def tileable_fbm(size, octaves=5, seed=42):
    rng = np.random.default_rng(seed)
    res = np.zeros((size, size), dtype=np.float32)
    amp = 0.5
    freq = 4
    for _ in range(octaves):
        grid = rng.random((freq, freq)).astype(np.float32)
        im = Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.Resampling.BICUBIC)
        res += (np.array(im, dtype=np.float32) / 255.0) * amp
        amp *= 0.5
        freq *= 2
    res = (res - res.min()) / (res.max() - res.min() + 1e-6)
    return res

def height_to_normal(hmap, strength=3.0):
    dx = (np.roll(hmap, -1, axis=1) - np.roll(hmap, 1, axis=1)) * strength
    dy = (np.roll(hmap, -1, axis=0) - np.roll(hmap, 1, axis=0)) * strength
    dz = np.ones_like(hmap)
    l = np.sqrt(dx*dx + dy*dy + dz*dz)
    nx = (-dx / l) * 0.5 + 0.5
    ny = (-dy / l) * 0.5 + 0.5
    nz = (dz / l) * 0.5 + 0.5
    rgb = np.stack([nx, ny, nz], axis=-1)
    return Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8))

SZ = 512
grain = tileable_fbm(SZ, octaves=6, seed=11)
puddle_raw = tileable_fbm(SZ, octaves=3, seed=77)
puddle_mask = np.clip((puddle_raw - 0.54) / 0.14, 0.0, 1.0) # 1 = standing water puddle

# Wet asphalt albedo (dark charcoal, even darker in puddles)
base_val = 28 + grain * 24 - puddle_mask * 12
asphalt_rgb = np.stack([base_val * 0.96, base_val * 0.99, base_val * 1.08], axis=-1)
Image.fromarray(np.clip(asphalt_rgb, 8, 90).astype(np.uint8)).save(os.path.join(TEX_DIR, 'asphalt_albedo.png'))

# ORM: R=AO, G=Roughness (0.05 puddles, 0.58 damp asphalt), B=Metallic (0.05)
ao = np.clip(0.75 + grain * 0.25, 0.5, 1.0)
rough = (0.58 - grain * 0.12) * (1.0 - puddle_mask) + 0.05 * puddle_mask
metal = np.full((SZ, SZ), 0.04, dtype=np.float32) + puddle_mask * 0.06
orm = np.stack([ao, rough, metal], axis=-1)
Image.fromarray(np.clip(orm * 255, 0, 255).astype(np.uint8)).save(os.path.join(TEX_DIR, 'asphalt_orm.png'))

# Normal: smooth inside puddles, gritty outside
h_asphalt = grain * (1.0 - puddle_mask * 0.92)
height_to_normal(h_asphalt, strength=3.5).save(os.path.join(TEX_DIR, 'asphalt_normal.png'))

# 3. Brick Tenement Wall PBR (Albedo, Normal, ORM) + Lit Windows
BW, BH = 512, 512
brick_col = np.zeros((BH, BW, 3), dtype=np.float32)
brick_h = np.zeros((BH, BW), dtype=np.float32)
rng = np.random.default_rng(101)
rows, cols = 16, 8
rh, cw = BH // rows, BW // cols
for r in range(rows):
    off = (cw // 2) if (r % 2 == 1) else 0
    for c in range(-1, cols + 1):
        x0 = c * cw + off
        y0 = r * rh
        tint = rng.uniform(0.72, 1.15)
        col = np.array([58 * tint, 34 * tint, 30 * tint])
        for yy in range(max(0, y0 + 2), min(BH, y0 + rh - 2)):
            for xx in range(max(0, x0 + 2), min(BW, x0 + cw - 2)):
                brick_col[yy, xx] = col
                brick_h[yy, xx] = 0.85
# Mortar + grime
grime = tileable_fbm(BW, octaves=4, seed=202)
mortar_mask = (brick_h < 0.1)
brick_col[mortar_mask] = [24, 22, 24]
brick_col = brick_col * (0.7 + 0.45 * grime[:,:,None])
Image.fromarray(np.clip(brick_col, 0, 255).astype(np.uint8)).save(os.path.join(TEX_DIR, 'brick_albedo.png'))
height_to_normal(brick_h * 0.7 + grime * 0.3, strength=4.0).save(os.path.join(TEX_DIR, 'brick_normal.png'))
b_orm = np.stack([0.6 + 0.4 * brick_h, 0.78 - 0.15 * grime, np.zeros_like(brick_h)], axis=-1)
Image.fromarray(np.clip(b_orm * 255, 0, 255).astype(np.uint8)).save(os.path.join(TEX_DIR, 'brick_orm.png'))

# 4. Sidewalk Concrete PBR
sw_g = tileable_fbm(SZ, octaves=5, seed=303)
sw_h = sw_g.copy()
# Concrete slab joints
for pos in [0, 256]:
    sw_h[pos:pos+4, :] *= 0.2
    sw_h[:, pos:pos+4] *= 0.2
sw_v = 48 + sw_h * 34
Image.fromarray(np.clip(np.stack([sw_v*0.95, sw_v*0.96, sw_v], axis=-1), 12, 120).astype(np.uint8)).save(os.path.join(TEX_DIR, 'sidewalk_albedo.png'))
height_to_normal(sw_h, strength=2.8).save(os.path.join(TEX_DIR, 'sidewalk_normal.png'))
sw_orm = np.stack([0.7 + 0.3*sw_h, 0.62 - 0.25*sw_g, np.full((SZ,SZ), 0.02)], axis=-1)
Image.fromarray(np.clip(sw_orm * 255, 0, 255).astype(np.uint8)).save(os.path.join(TEX_DIR, 'sidewalk_orm.png'))

# 5. Glowing Neon Storefront Signs & Graffiti
def make_neon_sign(filename, text, color, subtext='', w=512, h=160):
    img = Image.new('RGBA', (w, h), (10, 12, 16, 255))
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dg = ImageDraw.Draw(glow)
    font = find_font(62 if len(text) <= 10 else 46)
    bbox = dg.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx, ty = (w - tw) // 2, (h - th) // 2 - (14 if subtext else 4)
    # Border neon frame
    dg.rounded_rectangle([12, 12, w-12, h-12], radius=14, outline=color + (255,), width=6)
    dg.text((tx, ty), text, font=font, fill=color + (255,))
    if subtext:
        sf = find_font(24)
        sb = dg.textbbox((0, 0), subtext, font=sf)
        dg.text(((w - (sb[2]-sb[0])) // 2, ty + th + 10), subtext, font=sf, fill=(255, 220, 180, 255))
    blur1 = glow.filter(ImageFilter.GaussianBlur(14))
    blur2 = glow.filter(ImageFilter.GaussianBlur(5))
    img = Image.alpha_composite(img, blur1)
    img = Image.alpha_composite(img, blur2)
    img = Image.alpha_composite(img, glow)
    # Hot white tube core
    dc = ImageDraw.Draw(img)
    dc.text((tx, ty), text, font=font, fill=(255, 255, 255, 220))
    img.convert('RGB').save(os.path.join(TEX_DIR, filename))

make_neon_sign('sign_vapes.png', 'VAPES', (40, 255, 230), '24/7 SMOKE')
make_neon_sign('sign_coffee.png', 'COFFEE', (255, 160, 40), 'HOT & FRESH')
make_neon_sign('sign_barber.png', 'BARBER SHOP', (70, 200, 255), 'OPEN LATE')
make_neon_sign('sign_bakery.png', 'BAKERY', (255, 120, 45), 'FRESH BREAD')
make_neon_sign('sign_club.png', 'NEON CLUB', (255, 45, 190), 'VIP LOUNGE')
make_neon_sign('sign_gas365.png', 'GAS 365', (255, 65, 35), '6.66$ / GAL')
make_neon_sign('sign_thrift.png', 'THRIFT STORE', (120, 255, 90), 'SURPLUS')
make_neon_sign('sign_highrise.png', 'HIGH-RISE', (40, 240, 255), 'EXTRACTION ZONE')

# Graffiti decal: WORLD ENDING PREPARE
graf = Image.new('RGBA', (512, 256), (0, 0, 0, 0))
dg = ImageDraw.Draw(graf)
f1 = find_font(54)
dg.text((34, 30), 'WORLD ENDING', font=f1, fill=(220, 35, 35, 240))
dg.text((92, 118), 'PREPARE!', font=f1, fill=(245, 65, 30, 245))
# Paint drips
for x in range(50, 460, 28):
    if random.random() < 0.65:
        h_drip = random.randint(25, 70)
        y_start = random.choice([88, 172])
        dg.line([(x, y_start), (x, y_start + h_drip)], fill=(210, 30, 25, 210), width=4)
graf.filter(ImageFilter.GaussianBlur(0.8)).save(os.path.join(TEX_DIR, 'graffiti_warning.png'))

# 6. Blood Splatters (4 variants), Acid Puddle, Scorch Crater
def make_splatter(filename, base_rgb, seed, blobs=26):
    r = random.Random(seed)
    im = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = 128, 128
    # Central pool
    for _ in range(8):
        ox, oy = r.randint(-24, 24), r.randint(-24, 24)
        rad = r.randint(24, 52)
        a = r.randint(170, 235)
        d.ellipse([cx+ox-rad, cy+oy-rad, cx+ox+rad, cy+oy+rad], fill=base_rgb + (a,))
    # Radial droplets
    for _ in range(blobs):
        ang = r.uniform(0, math.tau)
        dist = r.uniform(35, 108)
        rad = r.randint(4, 16)
        px, py = int(cx + math.cos(ang)*dist), int(cy + math.sin(ang)*dist)
        a = r.randint(150, 230)
        d.ellipse([px-rad, py-rad, px+rad, py+rad], fill=base_rgb + (a,))
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    im.save(os.path.join(TEX_DIR, filename))

make_splatter('blood_1.png', (130, 8, 12), 10, 28)
make_splatter('blood_2.png', (110, 5, 10), 22, 34)
make_splatter('blood_3.png', (145, 12, 16), 33, 22)
make_splatter('blood_4.png', (95, 4, 8), 44, 30)
make_splatter('acid_decal.png', (75, 255, 55), 55, 24)
make_splatter('scorch_decal.png', (18, 15, 14), 66, 36)

# 7. Crisp White Weapon & HUD Silhouette Icons (128x64 transparent PNG)
def make_icon(filename, draw_fn, w=128, h=64):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    draw_fn(d, w, h)
    im.save(os.path.join(UI_DIR, filename))

def draw_pistol(d, w, h):
    d.rectangle([28, 16, 98, 32], fill=(245, 245, 245, 255))
    d.rectangle([92, 18, 104, 26], fill=(245, 245, 245, 255))
    d.polygon([(34, 32), (56, 32), (48, 56), (26, 56)], fill=(245, 245, 245, 255))
    d.rectangle([52, 32, 68, 42], outline=(245, 245, 245, 255), width=3)

def draw_smg(d, w, h):
    d.rectangle([20, 14, 96, 32], fill=(245, 245, 245, 255))
    d.rectangle([96, 18, 114, 25], fill=(245, 245, 245, 255))
    d.polygon([(30, 32), (46, 32), (40, 54), (24, 54)], fill=(245, 245, 245, 255))
    d.polygon([(64, 32), (76, 32), (82, 58), (68, 58)], fill=(245, 245, 245, 255))

def draw_shotgun(d, w, h):
    d.polygon([(8, 28), (34, 24), (34, 38), (8, 48)], fill=(245, 245, 245, 255))
    d.rectangle([34, 20, 118, 28], fill=(245, 245, 245, 255))
    d.rectangle([58, 28, 94, 36], fill=(245, 245, 245, 255))

def draw_rifle(d, w, h):
    d.polygon([(8, 22), (32, 22), (32, 36), (8, 42)], fill=(245, 245, 245, 255))
    d.rectangle([32, 18, 96, 32], fill=(245, 245, 245, 255))
    d.rectangle([96, 21, 120, 27], fill=(245, 245, 245, 255))
    d.polygon([(40, 32), (52, 32), (46, 52), (34, 52)], fill=(245, 245, 245, 255))
    d.polygon([(66, 32), (78, 32), (84, 56), (70, 56)], fill=(245, 245, 245, 255))
    d.rectangle([50, 11, 78, 18], fill=(245, 245, 245, 255))

def draw_hmg(d, w, h):
    d.rectangle([10, 14, 92, 38], fill=(245, 245, 245, 255))
    d.rectangle([92, 18, 122, 24], fill=(245, 245, 245, 255))
    d.rectangle([92, 28, 118, 33], fill=(245, 245, 245, 255))
    d.rectangle([54, 38, 82, 58], fill=(245, 245, 245, 255))
    d.rectangle([24, 6, 62, 14], fill=(245, 245, 245, 255))

def draw_autoshotgun(d, w, h):
    d.rectangle([10, 18, 96, 34], fill=(245, 245, 245, 255))
    d.rectangle([96, 20, 118, 29], fill=(245, 245, 245, 255))
    d.ellipse([54, 30, 84, 58], fill=(245, 245, 245, 255))
    d.polygon([(28, 34), (42, 34), (36, 54), (22, 54)], fill=(245, 245, 245, 255))

def draw_flamethrower(d, w, h):
    d.rectangle([14, 18, 102, 34], fill=(245, 245, 245, 255))
    d.rounded_rectangle([38, 34, 86, 56], radius=8, fill=(245, 245, 245, 255))
    d.polygon([(102, 16), (122, 26), (102, 36)], fill=(255, 180, 60, 255))

def draw_gear(d, w, h):
    cx, cy = w//2, h//2
    for i in range(8):
        ang = i * (math.tau / 8.0)
        x = cx + math.cos(ang) * 22
        y = cy + math.sin(ang) * 22
        d.ellipse([x-7, y-7, x+7, y+7], fill=(255, 255, 255, 255))
    d.ellipse([cx-20, cy-20, cx+20, cy+20], fill=(255, 255, 255, 255))
    d.ellipse([cx-9, cy-9, cx+9, cy+9], fill=(0, 0, 0, 0))

make_icon('icon_pistol.png', draw_pistol)
make_icon('icon_smg.png', draw_smg)
make_icon('icon_shotgun.png', draw_shotgun)
make_icon('icon_rifle.png', draw_rifle)
make_icon('icon_hmg.png', draw_hmg)
make_icon('icon_autoshotgun.png', draw_autoshotgun)
make_icon('icon_flamethrower.png', draw_flamethrower)
make_icon('icon_gear.png', draw_gear, 64, 64)

print('2D textures, neon signs, decals, and UI icons generated successfully on tlab!')
