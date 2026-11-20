import bpy, bmesh, math, os
from mathutils import Vector, Euler

OUT = os.path.expanduser('~/projects/street_trash_dezombifier/assets/models')
os.makedirs(OUT, exist_ok=True)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def make_mat(name, color, rough=0.6, metal=0.0, emission=None, em_strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    if emission is not None and em_strength > 0.0:
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = (*emission, 1.0)
            bsdf.inputs['Emission Strength'].default_value = em_strength
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value = (*emission, 1.0)
    return m

def add_box(name, size, loc=(0,0,0), rot=(0,0,0), mat=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0.0:
        mod = o.modifiers.new('Bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if mat:
        o.data.materials.append(mat)
    return o

def add_cyl(name, r, d, loc=(0,0,0), rot=(0,0,0), verts=16, mat=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if mat:
        o.data.materials.append(mat)
    return o

def add_sphere(name, r, loc=(0,0,0), scale=(1,1,1), mat=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=r, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if mat:
        o.data.materials.append(mat)
    return o

def export_glb(filename, has_anim=False):
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        export_yup=True,
        export_apply=False if has_anim else True,
        export_animations=has_anim,
        export_nla_strips=has_anim,
        export_materials='EXPORT',
    )
    print('Exported:', path)

# ============================================================
# 1. RIGGED HUMANOID GENERATOR (Survivor + 5 Zombie Archetypes)
# Facing -Y in Blender => +Z forward in Godot!
# ============================================================
def build_humanoid(filename, cfg):
    clear_scene()
    sc = cfg.get('scale', 1.0)
    skin = make_mat('Skin', cfg['skin'], rough=0.72)
    shirt = make_mat('Shirt', cfg['shirt'], rough=0.78)
    pants = make_mat('Pants', cfg['pants'], rough=0.82)
    boots = make_mat('Boots', (0.08, 0.08, 0.09), rough=0.55)
    accent = make_mat('Accent', cfg.get('accent', (0.18, 0.2, 0.22)), rough=0.45, metal=cfg.get('accent_metal', 0.2))
    eye_em = cfg.get('eye_em', None)
    eye_mat = make_mat('Eyes', eye_em if eye_em else (0.1, 0.1, 0.1), rough=0.2, emission=eye_em, em_strength=5.5 if eye_em else 0.0)

    # Create Armature
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm_obj = bpy.context.active_object
    arm_obj.name = 'Rig'
    arm = arm_obj.data
    eb = arm.edit_bones
    eb.remove(eb[0])

    def mk_bone(name, head, tail, parent=None):
        b = eb.new(name)
        b.head = Vector(head) * sc
        b.tail = Vector(tail) * sc
        if parent:
            b.parent = eb[parent]
        return b

    mk_bone('Hips', (0, 0, 0.90), (0, 0, 1.05))
    mk_bone('Spine', (0, 0, 1.05), (0, 0, 1.48), 'Hips')
    mk_bone('Head', (0, 0, 1.50), (0, 0, 1.82), 'Spine')
    mk_bone('ArmL', (-0.28, 0, 1.44), (-0.34, 0, 0.96), 'Spine')
    mk_bone('ArmR', (0.28, 0, 1.44), (0.34, 0, 0.96), 'Spine')
    mk_bone('LegL', (-0.13, 0, 0.88), (-0.13, 0, 0.06), 'Hips')
    mk_bone('LegR', (0.13, 0, 0.88), (0.13, 0, 0.06), 'Hips')

    bpy.ops.object.mode_set(mode='OBJECT')

    def attach(obj, bone_name):
        obj.parent = arm_obj
        obj.parent_type = 'BONE'
        obj.parent_bone = bone_name
        # Counteract Blender bone-tail offset so mesh sits at exact world loc
        b_tail = arm_obj.data.bones[bone_name].tail_local
        obj.matrix_parent_inverse = arm_obj.matrix_world.inverted()
        # Simpler: set world matrix after parenting
        pass

    def mk_part(mesh_obj, bone_name):
        wmat = mesh_obj.matrix_world.copy()
        mesh_obj.parent = arm_obj
        mesh_obj.parent_type = 'BONE'
        mesh_obj.parent_bone = bone_name
        mesh_obj.matrix_world = wmat

    w_mult = cfg.get('width', 1.0)
    # Pelvis
    mk_part(add_box('Pelvis', (0.38*sc*w_mult, 0.24*sc*w_mult, 0.22*sc), (0, 0, 0.92*sc), mat=pants, bevel=0.02*sc), 'Hips')
    # Torso
    mk_part(add_box('Torso', (0.44*sc*w_mult, 0.26*sc*w_mult, 0.50*sc), (0, 0, 1.26*sc), mat=shirt, bevel=0.03*sc), 'Spine')

    # Archetype-specific torso details
    kind = cfg['kind']
    if kind == 'survivor':
        # Tactical vest + backpack + hood collar
        mk_part(add_box('Vest', (0.47*sc, 0.29*sc, 0.36*sc), (0, 0, 1.28*sc), mat=accent, bevel=0.02*sc), 'Spine')
        mk_part(add_box('Backpack', (0.32*sc, 0.16*sc, 0.38*sc), (0, 0.20*sc, 1.28*sc), mat=boots, bevel=0.03*sc), 'Spine')
        mk_part(add_box('Hood', (0.34*sc, 0.26*sc, 0.14*sc), (0, 0.04*sc, 1.52*sc), mat=shirt, bevel=0.03*sc), 'Spine')
    elif kind == 'bruiser':
        # Riot shoulder pads & chest armor
        mk_part(add_box('ArmorChest', (0.56*sc, 0.36*sc, 0.44*sc), (0, -0.02*sc, 1.30*sc), mat=accent, bevel=0.03*sc), 'Spine')
        mk_part(add_box('PauldronL', (0.24*sc, 0.28*sc, 0.20*sc), (-0.36*sc, 0, 1.46*sc), mat=accent, bevel=0.03*sc), 'ArmL')
        mk_part(add_box('PauldronR', (0.24*sc, 0.28*sc, 0.20*sc), (0.36*sc, 0, 1.46*sc), mat=accent, bevel=0.03*sc), 'ArmR')
    elif kind == 'bloater':
        # Glowing toxic belly & dorsal sacs
        glow_sac = make_mat('ToxicSac', (0.25, 0.95, 0.20), rough=0.25, emission=(0.35, 1.0, 0.18), em_strength=4.0)
        mk_part(add_sphere('Belly', 0.32*sc, (0, -0.14*sc, 1.18*sc), (1.1, 0.9, 1.0), mat=glow_sac), 'Spine')
        mk_part(add_sphere('Sac1', 0.14*sc, (-0.18*sc, 0.12*sc, 1.42*sc), mat=glow_sac), 'Spine')
        mk_part(add_sphere('Sac2', 0.16*sc, (0.16*sc, 0.14*sc, 1.32*sc), mat=glow_sac), 'Spine')
    elif kind == 'boss':
        # Massive armored juggernaut shoulders + glowing crimson core
        core_mat = make_mat('BossCore', (1.0, 0.15, 0.05), rough=0.2, emission=(1.0, 0.2, 0.05), em_strength=6.0)
        mk_part(add_box('BossPlate', (0.66*sc, 0.42*sc, 0.56*sc), (0, -0.02*sc, 1.32*sc), mat=accent, bevel=0.04*sc), 'Spine')
        mk_part(add_sphere('Core', 0.16*sc, (0, -0.22*sc, 1.34*sc), mat=core_mat), 'Spine')
        mk_part(add_box('HornL', (0.28*sc, 0.34*sc, 0.26*sc), (-0.42*sc, 0, 1.54*sc), mat=accent, bevel=0.04*sc), 'ArmL')
        mk_part(add_box('HornR', (0.28*sc, 0.34*sc, 0.26*sc), (0.42*sc, 0, 1.54*sc), mat=accent, bevel=0.04*sc), 'ArmR')

    # Head + Hair/Helmet + Glowing Eyes (facing -Y)
    mk_part(add_box('HeadMesh', (0.26*sc, 0.26*sc, 0.28*sc), (0, 0, 1.66*sc), mat=skin, bevel=0.04*sc), 'Head')
    if kind == 'survivor':
        hair = make_mat('Hair', (0.10, 0.08, 0.07), rough=0.85)
        mk_part(add_box('Hair', (0.28*sc, 0.28*sc, 0.12*sc), (0, 0.02*sc, 1.77*sc), mat=hair, bevel=0.03*sc), 'Head')
    elif kind in ('bruiser', 'boss'):
        mk_part(add_box('Helmet', (0.31*sc, 0.31*sc, 0.18*sc), (0, 0, 1.74*sc), mat=accent, bevel=0.04*sc), 'Head')
    mk_part(add_box('EyeL', (0.055*sc, 0.04*sc, 0.04*sc), (-0.065*sc, -0.13*sc, 1.68*sc), mat=eye_mat), 'Head')
    mk_part(add_box('EyeR', (0.055*sc, 0.04*sc, 0.04*sc), (0.065*sc, -0.13*sc, 1.68*sc), mat=eye_mat), 'Head')

    # Arms & Hands
    arm_w = 0.14 * sc * w_mult
    mk_part(add_box('ArmLMesh', (arm_w, arm_w, 0.50*sc), (-0.31*sc*w_mult, 0, 1.22*sc), mat=shirt, bevel=0.02*sc), 'ArmL')
    mk_part(add_box('HandL', (arm_w*0.85, arm_w*0.85, 0.13*sc), (-0.31*sc*w_mult, 0, 0.94*sc), mat=skin, bevel=0.02*sc), 'ArmL')
    mk_part(add_box('ArmRMesh', (arm_w, arm_w, 0.50*sc), (0.31*sc*w_mult, 0, 1.22*sc), mat=shirt, bevel=0.02*sc), 'ArmR')
    mk_part(add_box('HandR', (arm_w*0.85, arm_w*0.85, 0.13*sc), (0.31*sc*w_mult, 0, 0.94*sc), mat=skin, bevel=0.02*sc), 'ArmR')

    # Legs & Boots
    leg_w = 0.16 * sc * w_mult
    mk_part(add_box('LegLMesh', (leg_w, leg_w, 0.68*sc), (-0.13*sc*w_mult, 0, 0.48*sc), mat=pants, bevel=0.02*sc), 'LegL')
    mk_part(add_box('BootL', (leg_w*1.05, leg_w*1.45, 0.16*sc), (-0.13*sc*w_mult, -0.04*sc, 0.08*sc), mat=boots, bevel=0.02*sc), 'LegL')
    mk_part(add_box('LegRMesh', (leg_w, leg_w, 0.68*sc), (0.13*sc*w_mult, 0, 0.48*sc), mat=pants, bevel=0.02*sc), 'LegR')
    mk_part(add_box('BootR', (leg_w*1.05, leg_w*1.45, 0.16*sc), (0.13*sc*w_mult, -0.04*sc, 0.08*sc), mat=boots, bevel=0.02*sc), 'LegR')

    # ---- Animate & Stash NLA Actions ----
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='POSE')
    pb = arm_obj.pose.bones
    for b in pb:
        b.rotation_mode = 'XYZ'

    def reset_pose():
        for b in pb:
            b.location = (0, 0, 0)
            b.rotation_euler = (0, 0, 0)

    def key_all(frame):
        for b in pb:
            b.keyframe_insert('location', frame=frame)
            b.keyframe_insert('rotation_euler', frame=frame)

    def make_action(name, fn):
        act = bpy.data.actions.new(name)
        arm_obj.animation_data_create()
        arm_obj.animation_data.action = act
        reset_pose()
        fn()
        # Stash into NLA track
        track = arm_obj.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, int(act.frame_range[0]), act)
        strip.name = name
        arm_obj.animation_data.action = None

    if kind == 'survivor':
        def anim_idle():
            for f, z in [(1, 0.0), (15, -0.03), (30, 0.0)]:
                pb['Hips'].location = (0, 0, z)
                pb['ArmR'].rotation_euler = (-1.35, 0, -0.1) # aiming forward (-Y)
                pb['ArmL'].rotation_euler = (-1.25, 0, 0.25)
                key_all(f)
        def anim_run():
            frames = [(1, 0.65, -0.65, 0.04), (9, 0.0, 0.0, -0.03), (17, -0.65, 0.65, 0.04), (25, 0.0, 0.0, -0.03), (33, 0.65, -0.65, 0.04)]
            for f, ll, lr, bob in frames:
                pb['Hips'].location = (0, 0, bob)
                pb['Spine'].rotation_euler = (-0.12, 0, 0.06 * ll)
                pb['LegL'].rotation_euler = (ll, 0, 0)
                pb['LegR'].rotation_euler = (lr, 0, 0)
                pb['ArmR'].rotation_euler = (-1.42, 0, -0.08)
                pb['ArmL'].rotation_euler = (-1.32, 0, 0.22)
                key_all(f)
        make_action('Idle_loop', anim_idle)
        make_action('Run_loop', anim_run)
    else:
        hunch = -0.32 if kind == 'sprinter' else -0.18
        arm_lift = -1.35 if kind != 'bloater' else -0.85
        def anim_shamble():
            frames = [(1, 0.55, -0.55, 0.04, 0.14), (11, 0.0, 0.0, -0.02, 0.0), (21, -0.55, 0.55, 0.04, -0.14), (31, 0.0, 0.0, -0.02, 0.0), (41, 0.55, -0.55, 0.04, 0.14)]
            for f, ll, lr, bob, sway in frames:
                pb['Hips'].location = (0, 0, bob)
                pb['Spine'].rotation_euler = (hunch, sway, sway * 0.5)
                pb['Head'].rotation_euler = (0.15, -sway * 0.8, 0)
                pb['LegL'].rotation_euler = (ll, 0, 0)
                pb['LegR'].rotation_euler = (lr, 0, 0)
                pb['ArmL'].rotation_euler = (arm_lift + 0.15*ll, 0, 0.1)
                pb['ArmR'].rotation_euler = (arm_lift + 0.15*lr, 0, -0.1)
                key_all(f)
        def anim_attack():
            for f, arm_a, sp in [(1, arm_lift, hunch), (7, -2.15, 0.15), (13, -0.85, -0.45), (21, arm_lift, hunch)]:
                pb['Spine'].rotation_euler = (sp, 0, 0)
                pb['ArmL'].rotation_euler = (arm_a, 0, 0.1)
                pb['ArmR'].rotation_euler = (arm_a, 0, -0.1)
                key_all(f)
        def anim_death():
            for f, pitch, dz in [(1, 0.0, 0.0), (8, 0.75, -0.25), (16, 1.52, -0.78)]:
                pb['Hips'].location = (0, 0, dz)
                pb['Hips'].rotation_euler = (pitch, 0, 0.12)
                pb['ArmL'].rotation_euler = (-0.5, 0, 0.6)
                pb['ArmR'].rotation_euler = (-0.3, 0, -0.7)
                key_all(f)
        make_action('Shamble_loop', anim_shamble)
        make_action('Attack', anim_attack)
        make_action('Death', anim_death)

    bpy.ops.object.mode_set(mode='OBJECT')
    export_glb(filename, has_anim=True)

build_humanoid('survivor.glb', {
    'kind': 'survivor', 'scale': 1.0, 'width': 1.0,
    'skin': (0.76, 0.56, 0.44), 'shirt': (0.14, 0.17, 0.21), 'pants': (0.11, 0.13, 0.18),
    'accent': (0.20, 0.24, 0.20), 'eye_em': (0.8, 0.95, 1.0),
})
build_humanoid('zombie_shambler.glb', {
    'kind': 'shambler', 'scale': 0.98, 'width': 0.95,
    'skin': (0.42, 0.50, 0.38), 'shirt': (0.22, 0.18, 0.16), 'pants': (0.14, 0.14, 0.16),
    'eye_em': (1.0, 0.85, 0.15),
})
build_humanoid('zombie_sprinter.glb', {
    'kind': 'sprinter', 'scale': 0.93, 'width': 0.84,
    'skin': (0.48, 0.40, 0.40), 'shirt': (0.36, 0.10, 0.10), 'pants': (0.12, 0.10, 0.12),
    'eye_em': (1.0, 0.12, 0.10),
})
build_humanoid('zombie_bruiser.glb', {
    'kind': 'bruiser', 'scale': 1.18, 'width': 1.25,
    'skin': (0.38, 0.44, 0.40), 'shirt': (0.12, 0.16, 0.22), 'pants': (0.10, 0.12, 0.16),
    'accent': (0.28, 0.32, 0.38), 'accent_metal': 0.75, 'eye_em': (1.0, 0.45, 0.10),
})
build_humanoid('zombie_bloater.glb', {
    'kind': 'bloater', 'scale': 1.12, 'width': 1.38,
    'skin': (0.36, 0.56, 0.30), 'shirt': (0.18, 0.24, 0.15), 'pants': (0.14, 0.16, 0.12),
    'eye_em': (0.35, 1.0, 0.15),
})
build_humanoid('zombie_boss.glb', {
    'kind': 'boss', 'scale': 1.55, 'width': 1.35,
    'skin': (0.32, 0.28, 0.30), 'shirt': (0.14, 0.08, 0.09), 'pants': (0.09, 0.09, 0.11),
    'accent': (0.35, 0.12, 0.12), 'accent_metal': 0.8, 'eye_em': (1.0, 0.08, 0.04),
})

# ============================================================
# 2. WEAPONS (Facing -Y barrel forward)
# ============================================================
def build_weapon(filename, parts):
    clear_scene()
    gunmetal = make_mat('Gunmetal', (0.16, 0.17, 0.19), rough=0.35, metal=0.85)
    dark = make_mat('Grip', (0.07, 0.07, 0.08), rough=0.7, metal=0.1)
    wood = make_mat('Wood', (0.30, 0.16, 0.08), rough=0.65, metal=0.0)
    glow = make_mat('Glow', (1.0, 0.45, 0.1), rough=0.2, emission=(1.0, 0.45, 0.1), em_strength=4.5)
    mats = {'metal': gunmetal, 'dark': dark, 'wood': wood, 'glow': glow}
    for name, size, loc, mkey in parts:
        add_box(name, size, loc, mat=mats[mkey], bevel=0.008)
    export_glb(filename)

build_weapon('weapon_pistol.glb', [
    ('Slide', (0.06, 0.28, 0.08), (0, -0.10, 0.04), 'metal'),
    ('Grip', (0.055, 0.09, 0.14), (0, 0.0, -0.04), 'dark'),
])
build_weapon('weapon_smg.glb', [
    ('Body', (0.07, 0.34, 0.11), (0, -0.14, 0.04), 'metal'),
    ('Barrel', (0.04, 0.14, 0.04), (0, -0.34, 0.05), 'metal'),
    ('Mag', (0.045, 0.06, 0.22), (0, -0.20, -0.08), 'dark'),
    ('Grip', (0.055, 0.08, 0.14), (0, -0.02, -0.04), 'dark'),
])
build_weapon('weapon_shotgun.glb', [
    ('Stock', (0.065, 0.26, 0.11), (0, 0.12, 0.0), 'wood'),
    ('Receiver', (0.075, 0.28, 0.10), (0, -0.12, 0.04), 'metal'),
    ('Barrel', (0.05, 0.46, 0.06), (0, -0.44, 0.06), 'metal'),
    ('Pump', (0.08, 0.20, 0.075), (0, -0.38, 0.01), 'wood'),
])
build_weapon('weapon_rifle.glb', [
    ('Stock', (0.065, 0.24, 0.11), (0, 0.14, 0.02), 'dark'),
    ('Body', (0.075, 0.38, 0.11), (0, -0.14, 0.04), 'metal'),
    ('Barrel', (0.045, 0.32, 0.045), (0, -0.46, 0.05), 'metal'),
    ('Mag', (0.05, 0.08, 0.22), (0, -0.22, -0.08), 'dark'),
    ('Scope', (0.05, 0.18, 0.06), (0, -0.12, 0.12), 'dark'),
])
build_weapon('weapon_hmg.glb', [
    ('Receiver', (0.14, 0.56, 0.18), (0, -0.22, 0.04), 'metal'),
    ('BarrelTop', (0.06, 0.46, 0.06), (0, -0.68, 0.08), 'metal'),
    ('BarrelBot', (0.05, 0.40, 0.05), (0, -0.64, 0.01), 'dark'),
    ('AmmoBox', (0.18, 0.20, 0.22), (0.08, -0.26, -0.10), 'dark'),
    ('Handle', (0.08, 0.22, 0.04), (0, -0.24, 0.17), 'metal'),
])
build_weapon('weapon_autoshotgun.glb', [
    ('Body', (0.10, 0.48, 0.13), (0, -0.18, 0.04), 'metal'),
    ('Barrel', (0.065, 0.34, 0.07), (0, -0.54, 0.05), 'metal'),
    ('DrumMag', (0.16, 0.18, 0.18), (0, -0.26, -0.08), 'dark'),
])
build_weapon('weapon_flamethrower.glb', [
    ('Pipe', (0.09, 0.62, 0.10), (0, -0.26, 0.05), 'metal'),
    ('FuelTank', (0.16, 0.32, 0.16), (0, -0.18, -0.08), 'glow'),
    ('Nozzle', (0.11, 0.12, 0.11), (0, -0.60, 0.05), 'glow'),
])

# ============================================================
# 3. RETRO BOX-BODY VEHICLES + WRECK + JOLT DEBRIS
# ============================================================
def build_car(filename, paint_rgb, is_van=False, is_police=False, is_wreck=False):
    clear_scene()
    paint = make_mat('Paint', paint_rgb, rough=0.82 if is_wreck else 0.30, metal=0.25 if is_wreck else 0.65)
    glass = make_mat('Glass', (0.04, 0.06, 0.08), rough=0.12, metal=0.4)
    rubber = make_mat('Rubber', (0.06, 0.06, 0.07), rough=0.85)
    chrome = make_mat('Chrome', (0.65, 0.68, 0.72), rough=0.2, metal=0.95)
    headlight = make_mat('Headlight', (1.0, 0.96, 0.82), rough=0.1, emission=(1.0, 0.95, 0.8), em_strength=0.0 if is_wreck else 5.0)
    taillight = make_mat('Taillight', (1.0, 0.1, 0.08), rough=0.2, emission=(1.0, 0.12, 0.08), em_strength=0.0 if is_wreck else 3.5)

    L = 5.0 if is_van else 4.5
    W = 2.1 if is_van else 1.92
    add_box('Chassis', (W, L, 0.72), (0, 0, 0.66), mat=paint, bevel=0.08)
    if is_van:
        add_box('Cabin', (W*0.95, L*0.84, 1.05), (0, 0.25, 1.48), mat=paint, bevel=0.08)
        add_box('Windshield', (W*0.84, 0.12, 0.65), (0, -L*0.36, 1.48), rot=(0.2, 0, 0), mat=glass)
    else:
        add_box('Cabin', (W*0.86, 2.15, 0.68), (0, 0.18, 1.32), mat=paint, bevel=0.08)
        add_box('Windows', (W*0.88, 1.95, 0.48), (0, 0.18, 1.32), mat=glass)
    # Bumpers
    add_box('BumperF', (W*1.02, 0.18, 0.24), (0, -L*0.51, 0.42), mat=chrome, bevel=0.03)
    add_box('BumperR', (W*1.02, 0.18, 0.24), (0, L*0.51, 0.42), mat=chrome, bevel=0.03)
    # Lights
    add_box('LightFL', (0.34, 0.08, 0.18), (-W*0.34, -L*0.50, 0.72), mat=headlight)
    add_box('LightFR', (0.34, 0.08, 0.18), (W*0.34, -L*0.50, 0.72), mat=headlight)
    add_box('LightRL', (0.38, 0.08, 0.16), (-W*0.34, L*0.50, 0.74), mat=taillight)
    add_box('LightRR', (0.38, 0.08, 0.16), (W*0.34, L*0.50, 0.74), mat=taillight)
    # Wheels
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_cyl(f'Wheel_{sx}_{sy}', 0.36, 0.26, (sx*(W*0.48), sy*(L*0.31), 0.36), rot=(0, math.pi/2, 0), mat=rubber)
            add_cyl(f'Rim_{sx}_{sy}', 0.20, 0.28, (sx*(W*0.48), sy*(L*0.31), 0.36), rot=(0, math.pi/2, 0), mat=chrome)
    if is_police:
        blue_em = make_mat('BlueBar', (0.1, 0.4, 1.0), emission=(0.15, 0.5, 1.0), em_strength=6.0)
        red_em = make_mat('RedBar', (1.0, 0.1, 0.1), emission=(1.0, 0.15, 0.1), em_strength=6.0)
        add_box('BarL', (0.45, 0.22, 0.14), (-0.28, 0.15, 1.72), mat=blue_em)
        add_box('BarR', (0.45, 0.22, 0.14), (0.28, 0.15, 1.72), mat=red_em)
    # Godot auto-collision helper!
    add_box('CarBounds-colonly', (W*1.04, L*1.04, 1.8 if is_van else 1.55), (0, 0, 0.9))
    export_glb(filename)

build_car('car_sedan_red.glb', (0.58, 0.12, 0.09))
build_car('car_sedan_cyan.glb', (0.14, 0.26, 0.32))
build_car('car_police.glb', (0.10, 0.11, 0.14), is_police=True)
build_car('car_van.glb', (0.72, 0.64, 0.44), is_van=True)
build_car('car_wreck.glb', (0.10, 0.09, 0.09), is_wreck=True)

# Detachable Jolt debris pieces
clear_scene()
add_box('DoorMesh', (0.10, 1.15, 0.72), (0,0,0), mat=make_mat('CharDoor', (0.14, 0.11, 0.10), rough=0.8), bevel=0.02)
export_glb('debris_door.glb')

clear_scene()
add_cyl('TireMesh', 0.36, 0.26, (0,0,0), rot=(0, math.pi/2, 0), mat=make_mat('CharTire', (0.06, 0.06, 0.06), rough=0.9))
export_glb('debris_wheel.glb')

# ============================================================
# 4. URBAN PROPS, BARREL FIRE, GARAGE SHUTTER, PICKUPS, HIGH-RISE
# ============================================================
# Burning Barrel
clear_scene()
rust = make_mat('RustBarrel', (0.28, 0.14, 0.09), rough=0.82, metal=0.45)
ember = make_mat('EmberCore', (1.0, 0.38, 0.05), rough=0.3, emission=(1.0, 0.42, 0.05), em_strength=7.0)
add_cyl('Barrel', 0.34, 0.96, (0, 0, 0.48), verts=16, mat=rust)
add_cyl('CoalCore', 0.28, 0.15, (0, 0, 0.92), verts=14, mat=ember)
add_cyl('BarrelCol-colonly', 0.38, 1.0, (0, 0, 0.50), verts=8)
export_glb('barrel_fire.glb')

# Streetlamp
clear_scene()
pole = make_mat('PoleMetal', (0.14, 0.15, 0.17), rough=0.45, metal=0.8)
lamp_em = make_mat('LampBulb', (1.0, 0.78, 0.45), rough=0.1, emission=(1.0, 0.75, 0.42), em_strength=8.0)
add_cyl('Post', 0.11, 6.2, (0, 0, 3.1), verts=10, mat=pole)
add_box('Arm', (0.12, 1.6, 0.12), (0, -0.75, 6.1), mat=pole)
add_box('Fixture', (0.36, 0.58, 0.14), (0, -1.45, 6.02), mat=pole)
add_box('Bulb', (0.26, 0.44, 0.06), (0, -1.45, 5.93), mat=lamp_em)
add_cyl('PostCol-colonly', 0.16, 4.0, (0, 0, 2.0), verts=6)
export_glb('streetlamp.glb')

# Concrete Jersey Barricade
clear_scene()
conc = make_mat('Concrete', (0.36, 0.36, 0.37), rough=0.88)
stripe = make_mat('HazardStripe', (0.85, 0.58, 0.08), rough=0.55)
add_box('Base', (2.2, 0.68, 0.36), (0, 0, 0.18), mat=conc, bevel=0.03)
add_box('Upper', (2.15, 0.36, 0.62), (0, 0, 0.65), mat=conc, bevel=0.03)
add_box('TopStripe', (2.16, 0.38, 0.14), (0, 0, 0.86), mat=stripe)
add_box('Barricade-colonly', (2.25, 0.72, 1.0), (0, 0, 0.5))
export_glb('barricade.glb')

# Dumpster
clear_scene()
dmp = make_mat('DumpsterGreen', (0.12, 0.24, 0.16), rough=0.72, metal=0.35)
lid = make_mat('DumpsterLid', (0.07, 0.07, 0.08), rough=0.8)
add_box('Bin', (2.1, 1.25, 1.18), (0, 0, 0.62), mat=dmp, bevel=0.04)
add_box('Lid', (2.16, 1.30, 0.10), (0, 0.02, 1.24), rot=(0.12, 0, 0), mat=lid)
add_box('Dumpster-colonly', (2.18, 1.32, 1.30), (0, 0, 0.65))
export_glb('dumpster.glb')

# Chainlink Fence Section (4m wide)
clear_scene()
fmat = make_mat('FenceSteel', (0.32, 0.34, 0.36), rough=0.45, metal=0.85)
add_cyl('PostL', 0.06, 2.4, (-2.0, 0, 1.2), verts=8, mat=fmat)
add_cyl('PostR', 0.06, 2.4, (2.0, 0, 1.2), verts=8, mat=fmat)
add_box('TopRail', (4.0, 0.07, 0.07), (0, 0, 2.35), mat=fmat)
add_box('MidRail', (4.0, 0.05, 0.05), (0, 0, 1.20), mat=fmat)
for i in range(-8, 9):
    add_box(f'Bar_{i}', (0.03, 0.03, 2.3), (i*0.23, 0, 1.18), mat=fmat)
add_box('Fence-colonly', (4.05, 0.20, 2.4), (0, 0, 1.2))
export_glb('fence_section.glb')

# Animated Rolling Garage Shutter (for Intro Cutscene!)
clear_scene()
sh_mat = make_mat('ShutterSteel', (0.20, 0.21, 0.24), rough=0.52, metal=0.78)
frame_mat = make_mat('FrameSteel', (0.12, 0.12, 0.14), rough=0.65, metal=0.6)
add_box('FrameL', (0.28, 0.40, 3.4), (-2.15, 0, 1.7), mat=frame_mat)
add_box('FrameR', (0.28, 0.40, 3.4), (2.15, 0, 1.7), mat=frame_mat)
add_box('FrameTop', (4.6, 0.50, 0.50), (0, 0, 3.45), mat=frame_mat)
door = add_box('ShutterDoor', (4.05, 0.12, 3.25), (0, 0, 1.62), mat=sh_mat)
door.animation_data_create()
act = bpy.data.actions.new('Garage_Open')
door.animation_data.action = act
door.location = (0, 0, 1.62); door.keyframe_insert('location', frame=1)
door.location = (0, 0, 4.65); door.keyframe_insert('location', frame=75)
tr = door.animation_data.nla_tracks.new(); tr.name = 'Garage_Open'
tr.strips.new('Garage_Open', 1, act)
door.animation_data.action = None
export_glb('garage_shutter.glb', has_anim=True)

# Pickups: Glowing Cyan Gear & Emerald Medkit
clear_scene()
g_metal = make_mat('GearMetal', (0.25, 0.85, 1.0), rough=0.25, metal=0.85, emission=(0.15, 0.85, 1.0), em_strength=4.5)
add_cyl('Ring', 0.42, 0.16, (0, 0, 0), verts=16, mat=g_metal)
for i in range(8):
    ang = i * (math.tau / 8.0)
    add_box(f'Tooth_{i}', (0.16, 0.18, 0.16), (math.cos(ang)*0.45, math.sin(ang)*0.45, 0), rot=(0, 0, ang), mat=g_metal)
export_glb('pickup_gear.glb')

clear_scene()
med_white = make_mat('MedWhite', (0.88, 0.92, 0.90), rough=0.35)
med_green = make_mat('MedCross', (0.12, 1.0, 0.35), rough=0.2, emission=(0.15, 1.0, 0.4), em_strength=5.0)
add_box('Case', (0.58, 0.44, 0.24), (0, 0, 0.14), mat=med_white, bevel=0.03)
add_box('CrossH', (0.30, 0.10, 0.04), (0, 0, 0.27), mat=med_green)
add_box('CrossV', (0.10, 0.30, 0.04), (0, 0, 0.27), mat=med_green)
export_glb('pickup_medkit.glb')

print('ALL Blender 4.0.2 3D assets exported cleanly to:', OUT)
