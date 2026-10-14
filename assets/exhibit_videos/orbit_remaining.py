"""Blender 4.5: four photo-guided volumetric reliefs, continuous visitor cameras.

--artifact 1..4 --output <temporary folder> [--preview | --encode-only]
Limited frontal arcs: inferred depth is illustrative, not a scanned full 3D model.
The approved sword film and the board/player sources are not modified.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import shutil
import sys
import wave

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent
MEDIA = ROOT/'final'
NAMES = {1:'02_四羊方尊', 2:'03_金缕玉衣', 3:'04_马踏飞燕', 4:'05_长信宫灯'}
p = argparse.ArgumentParser()
p.add_argument('--artifact', type=int, choices=NAMES, required=True)
p.add_argument('--output', required=True)
p.add_argument('--preview', action='store_true')
p.add_argument('--encode-only', action='store_true')
p.add_argument('--ffmpeg', default='ffmpeg.exe')
args = p.parse_args(sys.argv[sys.argv.index('--')+1:])
aid, name, out = args.artifact, NAMES[args.artifact], Path(args.output)
out.mkdir(parents=True, exist_ok=True)
audio = ROOT/'narration'/f'{aid}.wav'
with wave.open(str(audio), 'rb') as wav:
    narration = wav.getnframes()/wav.getframerate()
frames = math.ceil((narration+2)*60)
duration = frames/60
dest = MEDIA/(name+'_游客环绕正式版.mp4')
raw = out/'orbit_silent.mp4'

if args.encode_only:
    ff = Path(shutil.which(args.ffmpeg) or args.ffmpeg).resolve()
    dest.parent.mkdir(parents=True, exist_ok=True)
    caption = ("drawtext=fontfile='C\\:/Windows/Fonts/msyh.ttc':text='"+name[3:]+
               " · 数字复原示意':fontsize=17:fontcolor=white@0.65:x=28:y=h-35")
    subprocess.run([str(ff), '-hide_banner', '-n', '-i', str(raw), '-f', 'lavfi',
        '-i', 'anullsrc=r=48000:cl=stereo', '-t', str(duration), '-vf', caption,
        '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-pix_fmt', 'yuv420p',
        '-g', '60', '-keyint_min', '60', '-bf', '0', '-c:a', 'aac', '-b:a', '64k',
        '-movflags', '+faststart', str(dest)], check=True)
    info = json.loads(subprocess.check_output([str(ff.with_name('ffprobe.exe')),
        '-v', 'error', '-count_frames', '-show_streams', '-show_format', '-of', 'json', str(dest)], text=True))
    v = next(s for s in info['streams'] if s['codec_type']=='video')
    a = next(s for s in info['streams'] if s['codec_type']=='audio')
    assert (v['width'],v['height'],v['avg_frame_rate'],int(v['nb_read_frames']))==(1280,720,'60/1',frames)
    assert a['sample_rate']=='48000' and a['channels']==2
    assert abs(float(v['duration'])-duration)<.002 and float(v['duration'])>=narration+2
    check = subprocess.run([str(ff), '-hide_banner', '-i', str(dest), '-an', '-vf',
        'blackdetect=d=0.016:pix_th=0.06:pic_th=0.995', '-f', 'null', '-'],
        capture_output=True, text=True, check=True)
    assert 'black_start:' not in check.stderr
    checksums = subprocess.check_output([str(ff), '-v', 'error', '-i', str(dest),
        '-map', '0:v:0', '-f', 'framemd5', '-'], text=True)
    md5 = [s.rsplit(',',1)[1].strip() for s in checksums.splitlines() if s and not s.startswith('#')]
    assert len(md5)==frames and len(set(md5))>frames*.98
    info.update(sha256=hashlib.sha256(dest.read_bytes()).hexdigest(), narration_seconds=narration,
        narration_sha256=hashlib.sha256(audio.read_bytes()).hexdigest(),
        script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        full_decode_black_check='pass', unique_decoded_frames=len(set(md5)))
    (out/'video_validation.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
    print(dest, info['sha256'])
    sys.exit(0)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.eevee.taa_render_samples = 32
scene.render.resolution_x,scene.render.resolution_y = 1280,720
scene.render.resolution_percentage = 100
scene.render.fps = 60
scene.frame_start,scene.frame_end = 1,frames
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.world.color = (.035,.035,.035)
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'

def material(label, color, metal=0, rough=.5):
    m = bpy.data.materials.new(label)
    m.diffuse_color = (*color,1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color,1)
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Roughness'].default_value = rough
    return m

stone = material('Charcoal museum stone',(.025,.032,.031),.08,.62)
gold = material('Brass edging',(.56,.40,.18),.55,.4)
wall = material('Gallery wall',(.018,.032,.03),0,.88)
floor = material('Stone floor',(.062,.058,.05),.12,.38)
side = material('Interpretive side surface', (.36,.32,.20) if aid==2 else (.17,.13,.06) if aid==4 else (.07,.095,.055),.04 if aid==2 else .48,.56)
photo = material('Preserved artifact surface',(.3,.3,.2),.18 if aid!=2 else .04,.54)
texture_path = ROOT/'orbit_textures'/f'{aid}.png'
img = bpy.data.images.load(str(texture_path))
nodes, links = photo.node_tree.nodes,photo.node_tree.links
tex = nodes.new('ShaderNodeTexImage')
tex.image,tex.interpolation = img,'Linear'
bsdf = nodes.get('Principled BSDF')
links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
links.new(tex.outputs['Color'],bsdf.inputs['Emission Color'])
bsdf.inputs['Emission Strength'].default_value = .12
bump = nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .14
bump.inputs['Distance'].default_value = .0006
links.new(tex.outputs['Color'],bump.inputs['Height'])
links.new(bump.outputs['Normal'],bsdf.inputs['Normal'])

# Construct a CLOSED relief volume, including silhouette holes, from the alpha.
# ponytail: missing back views limit these reconstructions to small frontal arcs.
# An authenticated multi-view scan is required before expanding to 360 degrees.
w,h = img.size
pixels = np.empty(w*h*4,dtype=np.float32)
img.pixels.foreach_get(pixels)
alpha = pixels.reshape(h,w,4)[:,:,3]
ys,xs = np.where(alpha>.8)
assert len(xs)>10000 and alpha.min()<.1, 'Expected true transparent cutout'
x0,x1,y0,y1 = int(xs.min()),int(xs.max()),int(ys.min()),int(ys.max())
step = max(1,math.ceil(max(x1-x0,y1-y0)/420))
gx,gy = np.arange(x0,x1+1,step),np.arange(y0,y1+1,step)
mask = alpha[np.ix_(gy,gx)]>.8
mask[[0,-1],:] = False
mask[:,[0,-1]] = False
ny,nx = mask.shape
u,v = np.meshgrid((gx-x0)/(x1-x0),(gy-y0)/(y1-y0))
# Distance to boundary softens the inferred thickness without changing the photo.
distance = np.where(mask,1000.,0.)
for _ in range(90):
    distance[1:-1,1:-1] = np.minimum(distance[1:-1,1:-1],1+np.minimum.reduce((
        distance[:-2,1:-1],distance[2:,1:-1],distance[1:-1,:-2],distance[1:-1,2:])))

height = {1:.72,2:1.55,3:.70,4:.74}[aid]
width = height*(x1-x0)/(y1-y0)
depth = np.full(mask.shape,.012)
# (centre x, centre height, horizontal/vertical radii, depth in metres)
lobes = {
  1:[(.5,.32,.43,.25,.15),(.5,.70,.32,.29,.10),(.18,.56,.13,.13,.15),(.82,.56,.13,.13,.15),(.5,.1,.31,.18,.09)],
  2:[(.5,.72,.24,.19,.14),(.5,.94,.10,.09,.085),(.18,.63,.08,.20,.055),(.82,.63,.08,.20,.055),(.39,.28,.11,.25,.08),(.61,.28,.11,.25,.08)],
  3:[(.52,.46,.32,.16,.14),(.34,.65,.13,.28,.11),(.25,.87,.12,.1,.075),(.68,.43,.13,.14,.08),(.49,.03,.12,.05,.025)],
  4:[(.70,.35,.26,.30,.12),(.70,.76,.15,.18,.095),(.29,.56,.22,.30,.14),(.46,.10,.24,.15,.08),(.57,.94,.16,.15,.08)]
}[aid]
for cx,cy,rx,ry,amount in lobes:
    ellipse = np.maximum(0,1-((u-cx)/rx)**2-((v-cy)/ry)**2)
    depth = np.maximum(depth,amount*np.sqrt(ellipse))
depth *= np.sqrt(np.clip(distance/(nx*.025),0,1))
idx = np.full(mask.shape,-1,dtype=int)
idx[mask] = np.arange(mask.sum())
coords = np.column_stack(((u[mask]-.5)*width,-depth[mask],v[mask]*height+.8))
back = coords.copy()
back[:,1] = depth[mask]
count = len(coords)
uv = np.column_stack((np.broadcast_to(gx/w,mask.shape)[mask],np.broadcast_to((gy/h)[:,None],mask.shape)[mask]))
vertices = np.concatenate((coords,back))
faces,edges = [],{}
for y in range(ny-1):
    for x in range(nx-1):
        quad = (idx[y,x],idx[y,x+1],idx[y+1,x+1],idx[y+1,x])
        if min(quad)<0:
            continue
        faces.append(quad)
        for a,b in zip(quad,quad[1:]+quad[:1]):
            key = (min(a,b),max(a,b))
            if key in edges: del edges[key]
            else: edges[key] = (a,b)
front_count = len(faces)
faces += [tuple(i+count for i in reversed(f)) for f in faces[:front_count]]
faces += [(b,a,a+count,b+count) for a,b in edges.values()]
data = bpy.data.meshes.new('Artifact closed relief')
data.from_pydata(vertices.tolist(),[],faces)
data.update()
artifact = bpy.data.objects.new(name,data)
scene.collection.objects.link(artifact)
data.materials.append(photo)
data.materials.append(side)
layer = data.uv_layers.new()
for poly in data.polygons:
    poly.use_smooth = True
    poly.material_index = 1 if front_count<=poly.index<front_count*2 else 0
    for li in poly.loop_indices:
        layer.data[li].uv = uv[data.loops[li].vertex_index%count]
smooth = artifact.modifiers.new('Smooth silhouette sampling','SMOOTH')
smooth.factor,smooth.iterations = .8,20
bpy.context.view_layer.objects.active = artifact
artifact.select_set(True)
bpy.ops.object.modifier_apply(modifier=smooth.name)
sub = artifact.modifiers.new('Continuous outline','SUBSURF')
sub.levels,sub.render_levels = 1,1
bpy.ops.object.modifier_apply(modifier=sub.name)
if aid!=2:
    used = {loop.vertex_index for loop in artifact.data.loops}
    artifact.location.z = .8002-min(artifact.data.vertices[i].co.z for i in used)
    assert abs(artifact.location.z)<.03, 'Unexpected support offset'
assert front_count>1000 and len(edges)>0 and depth.max()>.05
if aid==2:
    # Jade suit lies face-up; no bending or articulation of the body.
    artifact.matrix_world = Matrix(((0,0,-1,.8+height/2),(1,0,0,0),(0,-1,0,.83),(0,0,0,1)))

def box(label,loc,dims,mat,bevel=.006):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    obj = bpy.context.object
    obj.name,obj.dimensions = label,dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new('Soft edges','BEVEL')
        mod.width,mod.segments = bevel,3
    return obj

table_x,table_y = (1.90,1.10) if aid==2 else (max(1.05,width+.26),.72)
box('Exhibit pedestal',(0,0,.385),(table_x,table_y,.77),stone)
box('Thin brass reveal',(0,0,.775),(table_x+.004,table_y+.004,.006),gold,.002)
box('Dark display pad',(0,0,.791),(table_x-.012,table_y-.012,.018),stone,.003)
box('Gallery floor',(0,0,-.06),(12,12,.1),floor)
box('Gallery wall',(0,2.3,1.7),(12,.16,3.4),wall)
for x in (-2.4,-1.2,1.2,2.4):
    box('Wall pilaster',(x,2.18,1.6),(.12,.25,3.2),stone)
    box('Pilaster trim',(x-.042,2.04,1.6),(.006,.01,3.1),gold,.001)

def area(label,loc,target,power,size,color):
    lamp = bpy.data.lights.new(label,'AREA')
    lamp.energy,lamp.shape,lamp.size,lamp.color = power,'DISK',size,color
    obj = bpy.data.objects.new(label,lamp)
    scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

area('Warm key',(-1,-1.2,2.7),(0,0,1.1),32,1.2,(1,.88,.73))
area('Cool fill',(1.1,-.5,2),(0,0,1.1),20,1.0,(.70,.85,1))
area('Rim',(.4,1,2.3),(0,0,1.1),55,.8,(1,.72,.45))
area('Gallery wash',(0,1,2.6),(0,2.3,1.4),20,1.5,(1,.78,.56))
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.name = 'Continuous visitor camera'
camera.data.lens = 50
camera.data.dof.use_dof = True
camera.data.dof.aperture_fstop = 9
scene.camera = camera

def pose(t):
    a = math.sin(math.pi*min(1,max(0,(t-.07)/.48)))**4
    b = math.sin(math.pi*min(1,max(0,(t-.43)/.48)))**4
    close = a+b
    ease = t*t*(3-2*t)
    theta = math.radians((-24 if aid==2 else -18)+(48 if aid==2 else 36)*ease)
    if aid==2:
        target = Vector((-.45*a+.40*b,0,.92))
        radius = 1.25-.62*close
        pos = target+Vector((radius*math.sin(theta),-radius*math.cos(theta),2.08-1.05*close))
    else:
        targets = {1:((-.23, .43),(.05,.22)),3:((-.26,.58),(.05,.11)),4:((.12,.55),(-.15,.34))}
        first,second = targets[aid]
        target = Vector((first[0]*a+second[0]*b,-.045,.8+height*.52+(first[1]-height*.52)*a+(second[1]-height*.52)*b))
        radius = (2.12 if aid!=3 else 2.20)-(1.15 if aid!=3 else 1.10)*close
        pos = target+Vector((radius*math.sin(theta),-radius*math.cos(theta),.075+.015*close))
    return pos,target

last = None
max_step = 0
for f in range(1,frames+1):
    scene.frame_set(f)
    pos,target = pose((f-1)/(frames-1))
    if last is not None: max_step = max(max_step,(pos-last).length)
    last = pos
    camera.location = pos
    camera.rotation_euler = (target-pos).to_track_quat('-Z','Y').to_euler()
    camera.data.dof.focus_distance = (target-pos).length
    camera.keyframe_insert('location',frame=f)
    camera.keyframe_insert('rotation_euler',frame=f)
    camera.data.dof.keyframe_insert('focus_distance',frame=f)
assert max_step<.008
report = dict(artifact=name,narration_seconds=narration,duration=duration,frames=frames,fps=60,cuts=0,
    max_camera_step_m=max_step,arc_degrees=48 if aid==2 else 36,front_mesh_faces=front_count,
    model='Photo-guided closed relief; depth inferred, no unseen back view claimed',
    texture_sha256=hashlib.sha256(texture_path.read_bytes()).hexdigest())
(out/'scene_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'orbit.blend'))
if args.preview:
    for f in (1,round(frames*.31),round(frames*.50),round(frames*.67),frames):
        scene.frame_set(f)
        scene.render.filepath = str(out/f'preview_{f:04}.png')
        bpy.ops.render.render(write_still=True)
else:
    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'MPEG4'
    scene.render.ffmpeg.codec = 'H264'
    scene.render.ffmpeg.constant_rate_factor = 'HIGH'
    scene.render.ffmpeg.ffmpeg_preset = 'GOOD'
    scene.render.filepath = str(raw)
    bpy.ops.render.render(animation=True)
