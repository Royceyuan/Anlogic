"""Blender 4.5: original, image-guided sword reconstruction and one continuous camera.

blender -b -t 6 --python orbit_sample.py -- --output D:/临时/自主环绕渲染/sword --preview
Remove --preview to render the narration-length, 60 fps film. No downloaded models.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import subprocess
import shutil
import wave

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent
args = argparse.ArgumentParser()
args.add_argument('--output', required=True)
args.add_argument('--preview', action='store_true')
args.add_argument('--encode-only', action='store_true')
args.add_argument('--ffmpeg', default='ffmpeg.exe')
args = args.parse_args(sys.argv[sys.argv.index('--') + 1:])
out = Path(args.output)
out.mkdir(parents=True, exist_ok=True)
audio = ROOT/'narration/0.wav'
with wave.open(str(audio), 'rb') as wav:
    narration_seconds = wav.getnframes()/wav.getframerate()
frame_count = math.ceil((narration_seconds + 2)*60)
duration = frame_count/60
if args.encode_only:
    ff = Path(shutil.which(args.ffmpeg) or args.ffmpeg).resolve()
    dest = ROOT/'final/01_越王勾践剑_平放环绕正式版.mp4'
    dest.parent.mkdir(parents=True, exist_ok=True)
    caption = "drawtext=fontfile='C\\:/Windows/Fonts/msyh.ttc':text='越王勾践剑 · 数字复原示意':fontsize=17:fontcolor=white@0.65:x=28:y=h-35"
    subprocess.run([str(ff), '-hide_banner', '-n', '-i', str(out/'sword_orbit_silent.mp4'),
                    '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo', '-t', str(duration),
                    '-vf', caption, '-c:v', 'libx264', '-crf', '18', '-preset', 'medium',
                    '-pix_fmt', 'yuv420p', '-g', '60', '-keyint_min', '60', '-bf', '0',
                    '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', str(dest)], check=True)
    probe = subprocess.check_output([str(ff.with_name('ffprobe.exe')), '-v', 'error',
            '-count_frames', '-show_streams', '-show_format', '-of', 'json', str(dest)], text=True)
    info = json.loads(probe)
    v = next(s for s in info['streams'] if s['codec_type'] == 'video')
    a = next(s for s in info['streams'] if s['codec_type'] == 'audio')
    assert (v['width'], v['height'], v['avg_frame_rate'], int(v['nb_read_frames'])) == (1280, 720, '60/1', frame_count)
    assert a['sample_rate'] == '48000' and a['channels'] == 2
    assert abs(float(info['format']['duration'])-duration) < .05
    assert float(v['duration']) >= narration_seconds + 2
    check = subprocess.run([str(ff), '-hide_banner', '-i', str(dest), '-an', '-vf',
            'blackdetect=d=0.016:pix_th=0.06:pic_th=0.995',
            '-f', 'null', '-'], capture_output=True, text=True, check=True)
    assert 'black_start:' not in check.stderr, check.stderr
    hashes = subprocess.check_output([str(ff), '-v', 'error', '-i', str(dest),
            '-map', '0:v:0', '-f', 'framemd5', '-'], text=True)
    frames = [line.rsplit(',', 1)[1].strip() for line in hashes.splitlines() if line and not line.startswith('#')]
    assert len(frames) == frame_count and len(set(frames)) > frame_count*.98
    info['sha256'] = hashlib.sha256(dest.read_bytes()).hexdigest()
    info['source_script_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    info['full_decode_black_check'] = 'pass'
    info['unique_decoded_frames'] = len(set(frames))
    info['narration_seconds'] = narration_seconds
    info['narration_sha256'] = hashlib.sha256(audio.read_bytes()).hexdigest()
    (out/'video_validation.json').write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding='utf-8')
    print(str(dest), info['sha256'])
    sys.exit(0)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.eevee.taa_render_samples = 32
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.render.resolution_percentage = 100
scene.render.fps = 60
scene.frame_start, scene.frame_end = 1, frame_count
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.image_settings.compression = 10
scene.world.color = (.035, .035, .035)
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'


def material(name, color, metal=0, rough=.45):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m


bronze = material('Aged bronze', (.18, .115, .043), .72, .4)
nodes, links = bronze.node_tree.nodes, bronze.node_tree.links
noise = nodes.new('ShaderNodeTexNoise')
noise.inputs['Scale'].default_value = 165
ramp = nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].color = (.018, .048, .035, 1)
ramp.color_ramp.elements[1].color = (.25, .17, .066, 1)
links.new(noise.outputs['Fac'], ramp.inputs[0])
links.new(ramp.outputs[0], nodes.get('Principled BSDF').inputs['Base Color'])
bump = nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .18
bump.inputs['Distance'].default_value = .0001
links.new(noise.outputs['Fac'], bump.inputs['Height'])
links.new(bump.outputs[0], nodes.get('Principled BSDF').inputs['Normal'])
edge = material('Worn edges', (.31, .23, .105), .75, .32)
stone = material('Charcoal plinth', (.025, .032, .031), .08, .62)
wall = material('Gallery plaster', (.018, .032, .030), 0, .88)
floor = material('Gallery floor', (.062, .058, .05), .12, .38)
gold = material('Museum lettering', (.56, .40, .18), .55, .4)

# The original image is left intact: mesh UVs project its visible front surface.
# ponytail: side thickness is interpretive, restricted front arc avoids inventing a back.
front = material('Existing image front surface', (.4, .3, .2), .35, .5)
tex = front.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = bpy.data.images.load(str(ROOT / 'source/0/0.png'))
tex.interpolation = 'Linear'
front.node_tree.links.new(tex.outputs['Color'], front.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])


def xyz(px, py, depth):
    return ((px - 357) * .000545, depth, .84 + (1050 - py) * .000545)


def mesh(name, vertices, faces, mat, photo_uv=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    if photo_uv:
        uv = data.uv_layers.new()
        for p in data.polygons:
            for idx in p.loop_indices:
                v = data.vertices[data.loops[idx].vertex_index].co
                uv.data[idx].uv = ((v.x / .000545 + 357) / 720,
                                   1 - (1050 - (v.z - .84) / .000545) / 1080)
    return obj


# Faceted section: actual edge, bevel and raised centre, rather than a flat image plane.
rows = [(1050, 0), (1020, 11), (970, 20), (870, 27), (660, 31), (440, 34), (222, 38)]
vertices = []
for py, w in rows:
    for side in (-1, 1):
        for portion, depth in [(-1, .0003), (-.72, .0023), (0, .0035), (.72, .0023), (1, .0003)]:
            vertices.append(xyz(357 + w * portion, py, depth * side))
faces = []
for row in range(len(rows) - 1):
    for side in range(2):
        for col in range(4):
            i = row * 10 + side * 5 + col
            face = (i, i + 1, i + 11, i + 10)
            faces.append(face if side == 0 else tuple(reversed(face)))
blade = mesh('Diamond-section blade', vertices, faces, front, True)

# Guard silhouette follows the source. Closed volume remains visible during orbit.
outline = [(315, 228), (315, 201), (322, 193), (340, 190), (376, 190),
           (393, 195), (400, 204), (400, 228), (375, 224), (357, 213), (337, 226)]
v = [xyz(x, y, d) for d in (-.004, .004) for x, y in outline]
n = len(outline)
f = [tuple(range(n - 1, -1, -1)), tuple(range(n, n * 2))]
f += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
guard = mesh('Solid decorated guard', v, f, front, True)
guard_mat = front.copy()
guard_mat.name = 'High-resolution guard detail'
guard_mat.node_tree.nodes.get(tex.name).image = bpy.data.images.load(str(ROOT/'source/0/1.png'))
guard.data.materials[0] = guard_mat
for loop in guard.data.loops:
    coord = guard.data.vertices[loop.vertex_index].co
    px = coord.x/.000545+357
    py = 1050-(coord.z-.84)/.000545
    guard.data.uv_layers.active.data[loop.index].uv = (
        .301 + (px-315)/85*.391, 1-(.259+(py-190)/38*.299))
bevel = guard.modifiers.new('Guard rounded edges', 'BEVEL')
bevel.width, bevel.segments = .0007, 3


def cylinder(name, radius, depth, location, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=radius, depth=depth, location=location)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    bevel = o.modifiers.new('Soft edges', 'BEVEL')
    bevel.width, bevel.segments = .0006, 3
    for p in o.data.polygons:
        p.use_smooth = True
    return o


cylinder('Grip', .0092, .077, xyz(357, 120, 0), bronze)
for py in (98, 141):
    cylinder('Grip collar', .0122, .002, xyz(357, py, 0), edge)
for py, radius in [(49, .011), (45, .014), (41, .017), (37, .020), (33, .021)]:
    cylinder('Pommel concentric step', radius, .002, xyz(357, py, 0), bronze)

# Rigid rotation only: the photographed front faces upward, sword lies horizontally.
flat = Matrix(((0, 0, -1, 1.12), (1, 0, 0, 0), (0, -1, 0, .855), (0, 0, 0, 1)))
assert abs(flat.to_3x3().determinant()-1) < 1e-6
for obj in list(scene.objects):
    obj.matrix_world = flat @ obj.matrix_world


def box(name, location, scale, mat, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    o = bpy.context.object
    o.name, o.dimensions = name, scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    if bevel:
        b = o.modifiers.new('Rounded edges', 'BEVEL')
        b.width, b.segments = bevel, 3
    return o


box('Horizontal display table', (0, 0, .39), (1.04, .62, .78), stone)
box('Brass table reveal', (0, 0, .778), (1.044, .624, .006), gold, .002)
lining = material('Recessed charcoal lining', (.052, .048, .037), 0, .95)
box('Display lining', (0, 0, .798), (.98, .56, .034), lining, .004)
for x in (-.51, .51):
    box('Case end rim', (x, 0, .823), (.018, .62, .09), stone, .002)
for y in (-.30, .30):
    box('Case side rim', (0, y, .823), (1.04, .018, .09), stone, .002)
for x in (-.16, .16):
    box('Padded conservation support', (x, 0, .833), (.016, .030, .036), stone, .002)
box('Floor', (0, 0, -.06), (10, 10, .1), floor)
box('Rear wall', (0, 1.5, 1.7), (10, .16, 3.4), wall)
for x in (-2.4, -1.2, 1.2, 2.4):
    box('Gallery wall pilaster', (x, 1.32, 1.6), (.12, .25, 3.2), stone)
    box('Brass pilaster accent', (x-.042, 1.18, 1.6), (.006, .01, 3.1), gold, .001)

font_path = Path('C:/Windows/Fonts/msyh.ttc')
font = bpy.data.fonts.load(str(font_path))
def label(body, loc, size):
    curve = bpy.data.curves.new(body, 'FONT')
    curve.body, curve.size, curve.font = body, size, font
    curve.align_x = 'CENTER'
    curve.extrude = .00003
    obj = bpy.data.objects.new(body, curve)
    scene.collection.objects.link(obj)
    obj.location, obj.rotation_euler = loc, (math.pi / 2, 0, 0)
    obj.data.materials.append(gold)

label('越王勾践剑', (0, -.311, .71), .027)
label('数字复原示意', (0, -.311, .666), .012)


def area(name, loc, target, energy, size, color):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy, data.shape, data.size, data.color = energy, 'DISK', size, color
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()


area('Warm key', (-.65, -.65, 2.2), (0, 0, 1.1), 22, .8, (1, .85, .68))
area('Cool fill', (.85, -.30, 1.6), (0, 0, 1.15), 12, .7, (.65, .83, 1))
area('Rim', (.4, .8, 1.9), (0, 0, 1.15), 28, .5, (1, .7, .4))
area('Wall wash', (0, .5, 2.5), (0, 1.5, 1.2), 9, 1.4, (1, .72, .45))
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.name = 'Visitor continuous orbit'
camera.data.lens = 56
camera.data.dof.use_dof = True
camera.data.dof.aperture_fstop = 7.1
scene.camera = camera


def pose(t):
    """Continuous visitor arc with two smooth detail visits; fixed lens, no cuts."""
    ease = t*t*(3-2*t)
    guard_close = math.sin(math.pi*min(1, max(0, (t-.07)/.48)))**4
    blade_close = math.sin(math.pi*min(1, max(0, (t-.43)/.48)))**4
    close = guard_close + blade_close
    theta = math.radians(-42 + 84*ease)
    radius = 1.02 - .58*close
    target = Vector((-.20*guard_close + .16*blade_close, 0, .855))
    position = target + Vector((radius*math.sin(theta), -radius*math.cos(theta), .83-.39*close))
    return position, target


def update(scene):
    t = (scene.frame_current-1)/(scene.frame_end-1)
    camera.location, target = pose(t)
    camera.rotation_euler = (target-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.dof.focus_distance = (target-camera.location).length


# Bake camera keys so the saved .blend also plays correctly without a Python handler.
for frame in range(1, scene.frame_end + 1):
    scene.frame_set(frame)
    update(scene)
    camera.keyframe_insert('location', frame=frame)
    camera.keyframe_insert('rotation_euler', frame=frame)
    camera.data.dof.keyframe_insert('focus_distance', frame=frame)
positions = [pose(i/(frame_count-1))[0] for i in range(frame_count)]
steps = [(b-a).length for a,b in zip(positions, positions[1:])]
assert max(steps) < .007, max(steps)
assert all(.60 < (p-target).length < 1.9 for p,target in (pose(i/(frame_count-1)) for i in range(frame_count)))
report = {'duration':duration, 'narration_seconds':narration_seconds,
          'fps':60, 'frames':frame_count, 'cuts':0, 'display':'Horizontal, front face upward',
          'camera_arc_degrees':84, 'max_camera_step_m':max(steps),
          'model':'Original image-guided interpretive geometry; not an artifact scan',
          'source_image':str(ROOT/'source/0/0.png')}
(out/'scene_checks.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'sword_orbit.blend'))
if args.preview:
    for frame in (1, round(frame_count*.31), round(frame_count*.50), round(frame_count*.67), frame_count):
        scene.frame_set(frame)
        scene.render.filepath = str(out/f'preview_{frame:04}.png')
        bpy.ops.render.render(write_still=True)
else:
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.constant_rate_factor = 'HIGH'
    scene.render.ffmpeg.ffmpeg_preset = 'GOOD'
    scene.render.filepath = str(out/'sword_orbit_silent.mp4')
    bpy.ops.render.render(animation=True)
