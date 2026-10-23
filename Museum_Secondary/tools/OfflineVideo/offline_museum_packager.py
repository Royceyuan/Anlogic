"""Fixed-format offline museum media builder; no PC is required during playback."""
from datetime import datetime
import importlib.util
import json
from pathlib import Path
import queue
import shutil
import struct
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import filedialog,messagebox,ttk
import wave
from PIL import ImageDraw,ImageFont  # Included explicitly in the frozen tool.
import convert_video
import generate_museum_subtitles as subtitles

HERE=Path(sys.executable).parent if getattr(sys,'frozen',False) else Path(__file__).resolve().parent
REPO=HERE.parents[1]
MEDIA=REPO/'assets'
PACKAGES=HERE/'packages'
module_path=Path(sys._MEIPASS)/'mvid2.py' if getattr(sys,'frozen',False) else HERE/'mvid2.py'
spec=importlib.util.spec_from_file_location('mvid2',module_path)
mvid2=importlib.util.module_from_spec(spec);spec.loader.exec_module(mvid2)
FF=HERE/'ffmpeg/ffmpeg.exe'
TITLES=['越王勾践剑','四羊方尊','金缕玉衣','铜奔马','长信宫灯','总览宣传片','应急疏散片']
STEMS=['ART0','ART1','ART2','ART3','ART4','GUIDE','EVAC']
NAMES=['01_越王勾践剑','02_四羊方尊','03_金缕玉衣','04_铜奔马','05_长信宫灯','06_总览宣传片','07_应急疏散指引']


def msub(cues,total):
    header=bytearray(512);header[:5]=b'MSUB\x03'
    struct.pack_into('<HBBBHB',header,5,800,32,2,len(cues),6400,13)
    struct.pack_into('<IIIII',header,16,total,*[total*n//5 for n in range(1,5)])
    data=bytearray(header)
    for start,end,text in cues:
        width,bitmap=subtitles.render_bitmap(text)
        record=bytearray(6656);struct.pack_into('<IIHB',record,0,start,end,width,1)
        record[16:6416]=bitmap;data.extend(record)
    return data


def build(films,srts,destination,log):
    if not FF.is_file():raise FileNotFoundError(f'缺少随附FFmpeg：{FF}')
    if any(not p.is_file() for p in films+srts):raise ValueError('请先选择全部七个视频和六份字幕')
    output=Path(destination)/datetime.now().strftime('副板离线媒体_%Y%m%d_%H%M%S')
    output.mkdir(parents=True,exist_ok=False)
    work=output/'_work';work.mkdir()
    rows=[]
    for i,(film,stem) in enumerate(zip(films,STEMS)):
        log(f'{i+1}/7 正在转换：{TITLES[i]}')
        raw=work/f'{stem}.v1.bin';target=output/f'{stem}.BIN'
        raw_report=convert_video.convert(film,raw,FF,30,480)
        frames=raw_report['frames'];audio=None
        if i==5:
            audio=work/'GUIDE.WAV'
            subprocess.run([str(FF),'-v','error','-nostdin','-n','-i',str(film),'-map','0:a:0',
                '-af','apad','-t',f'{frames/30:.9f}','-ar','48000','-ac','2','-c:a','pcm_s16le',str(audio)],check=True,
                creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        srt=srts[i] if i<6 else None
        report=mvid2.build(raw,target,audio=audio,subtitle=srt if i==5 else None,artifact=i if i<5 else 255 if i==5 else 254)
        report.update(file=target.name,path=str(target),source=str(film));rows.append(report)
        if srt:
            total=frames*1600
            if i<5:
                with wave.open(str(MEDIA/'音频'/f'{NAMES[i]}.wav'),'rb') as track:
                    total=round(track.getnframes()*48000/track.getframerate())
            cues=subtitles.parse_srt(srt,total,'direct')
            sub=output/f'SUB{i}.BIN';data=msub(cues,total);sub.write_bytes(data)
            if sub.read_bytes()!=data:raise IOError('字幕包读回不一致')
            rows.append(dict(file=sub.name,path=str(sub),file_bytes=len(data),sha256=mvid2.sha256(sub),format='MSUB v3'))
        # Only remove intermediates created in this fresh output folder, after
        # the final package's full verification succeeded. Source media stay put.
        raw.unlink();raw.with_suffix('.json').unlink(missing_ok=True)
        if audio:audio.unlink()
    manifest=output/'install_manifest.json'
    manifest.write_text(json.dumps(dict(format='museum offline AV install set',files=rows,tf_updated=False),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    log(f'完成：{manifest}；尚未写TF卡')
    return manifest


def existing_set(destination):
    """Select the current validated local packages without reconverting movies."""
    rows=[]
    paths=[PACKAGES/'artifact_final_release'/f'ART{i}.BIN' for i in range(5)]
    paths += [PACKAGES/'promo_final_release/GUIDE.BIN',PACKAGES/'EVAC.BIN']
    paths += [PACKAGES/'subtitles'/f'SUB{i}.BIN' for i in range(5)]
    paths += [PACKAGES/'promo_final_release/SUB5.BIN']
    for p in paths:
        if not p.is_file():raise FileNotFoundError(p)
        with p.open('rb') as f:header=f.read(512)
        if p.name.startswith('SUB'):
            if header[:5]!=b'MSUB\x03':raise ValueError(f'不匹配的字幕格式：{p}')
        else:mvid2.parse_header(header,p.stat().st_size)
        rows.append(dict(file=p.name,path=str(p),file_bytes=p.stat().st_size,sha256=mvid2.sha256(p)))
    destination=Path(destination);destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(dict(format='museum offline AV install set',files=rows,tf_updated=False),indent=2)+'\n',encoding='utf-8')
    return destination


def gui():
    root=tk.Tk();root.title('博物馆副板 · 离线音视频打包');root.geometry('1080x760');root.minsize(850,640)
    style=ttk.Style(root);style.theme_use('clam');style.configure('TFrame',background='#f4f1e8')
    style.configure('TLabel',background='#f4f1e8',foreground='#173e3c');style.configure('TButton',padding=6)
    root.configure(bg='#f4f1e8');root.columnconfigure(0,weight=1);root.rowconfigure(1,weight=1)
    ttk.Label(root,text='副板纯离线音视频媒体包',font=('Microsoft YaHei UI',20,'bold')).grid(row=0,column=0,sticky='w',padx=24,pady=18)
    tabs=ttk.Notebook(root);tabs.grid(row=1,column=0,sticky='nsew',padx=20)
    videos=ttk.Frame(tabs,padding=12);texts=ttk.Frame(tabs,padding=12)
    tabs.add(videos,text='七个视频');tabs.add(texts,text='六份独立字幕')
    films=[];srts=[];events=queue.Queue();busy=False
    defaults=[MEDIA/'视频'/f'{name}.mp4' for name in NAMES]
    for frame,items,count in ((videos,films,7),(texts,srts,6)):
        frame.columnconfigure(1,weight=1)
        for i in range(count):
            default=defaults[i] if frame is videos else MEDIA/'字幕'/f'{NAMES[i]}.srt'
            value=tk.StringVar(value=str(default));items.append(value)
            ttk.Label(frame,text=TITLES[i]).grid(row=i,column=0,sticky='w',pady=12,padx=6)
            ttk.Entry(frame,textvariable=value).grid(row=i,column=1,sticky='ew',padx=8)
            def choose(var=value,is_video=frame is videos):
                path=filedialog.askopenfilename(filetypes=[('视频','*.mp4 *.mkv *.mov *.avi')] if is_video else [('字幕','*.srt')])
                if path:var.set(path)
            ttk.Button(frame,text='选择',command=choose).grid(row=i,column=2)
    ttk.Label(texts,text='文物字幕须与主板使用的文字和时间戳一致；本工具不改主板素材。',wraplength=760).grid(row=6,column=0,columnspan=3,sticky='w',pady=20)
    dest=tk.StringVar(value=str(PACKAGES/'exports'));manifest=tk.StringVar()
    bottom=ttk.Frame(root,padding=18);bottom.grid(row=2,column=0,sticky='ew');bottom.columnconfigure(1,weight=1)
    ttk.Label(bottom,text='输出目录').grid(row=0,column=0)
    ttk.Entry(bottom,textvariable=dest).grid(row=0,column=1,sticky='ew',padx=8)
    def choose_dest():
        path=filedialog.askdirectory()
        if path:dest.set(path)
    ttk.Button(bottom,text='选择目录',command=choose_dest).grid(row=0,column=2)
    log_widget=tk.Text(root,height=7,bg='#123a38',fg='#f5efdc',wrap='word')
    log_widget.grid(row=3,column=0,sticky='ew',padx=20,pady=(0,16))
    def launch(function):
        nonlocal busy
        if busy:return
        busy=True
        def work():
            try:events.put(('manifest',str(function())))
            except Exception as exc:events.put(('error',str(exc)))
            finally:events.put(('done',''))
        threading.Thread(target=work,daemon=True).start()
    def make():
        selected_films=list(map(Path,(v.get() for v in films)));selected_srts=list(map(Path,(v.get() for v in srts)));destination=dest.get()
        launch(lambda:build(selected_films,selected_srts,destination,lambda s:events.put(('log',s))))
    def current():
        destination=Path(dest.get())/'current_install_manifest.json'
        launch(lambda:existing_set(destination))
    def install():
        if busy:return
        path=manifest.get() or filedialog.askopenfilename(filetypes=[('安装清单','*.json')])
        if not path:return
        if not messagebox.askyesno('写入副板TF卡','仅写入已核验身份的副板E盘。将先备份所有将被替换的文件，再写入并读回校验。\n确认卡已挂载且不在板上使用？'):return
        script=REPO/'scripts/install_offline_av.ps1'
        def write_card():
            process=subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(script),'-Manifest',path],
                capture_output=True,text=True,encoding='utf-8',errors='replace',creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            events.put(('log',process.stdout))
            if process.returncode:raise RuntimeError(process.stderr)
            return path
        launch(write_card)
    ttk.Button(bottom,text='生成新媒体包',command=make).grid(row=1,column=0,pady=12)
    ttk.Button(bottom,text='校验工程现有媒体',command=current).grid(row=1,column=1,sticky='w',padx=8)
    ttk.Button(bottom,text='备份并写入E盘',command=install).grid(row=1,column=2)
    def poll():
        nonlocal busy
        while not events.empty():
            kind,value=events.get()
            if kind=='done':busy=False
            elif kind=='manifest':manifest.set(value);log_widget.insert('end',f'安装清单：{value}\n')
            elif kind=='error':log_widget.insert('end','失败：'+value+'\n');messagebox.showerror('处理失败',value)
            else:log_widget.insert('end',value+'\n')
            log_widget.see('end')
        root.after(100,poll)
    def close():
        if busy:messagebox.showinfo('任务仍在进行','请等待转换或写卡结束，勿强制关闭。')
        else:root.destroy()
    root.protocol('WM_DELETE_WINDOW',close);root.after(100,poll);root.mainloop()


if __name__=='__main__':
    if len(sys.argv)>1 and sys.argv[1]=='--self-test':
        data=msub([(0,48000,'独立字幕自检')],48000)
        assert data[:5]==b'MSUB\x03' and len(data)==512+6656
        assert struct.unpack_from('<II',data,512)==(0,48000)
        assert any(data[528:6928])
        mvid2.self_test();print('PASS offline GUI backend: MSUB timing/body and MVID format')
    elif len(sys.argv)>1 and sys.argv[1]=='--current-manifest':print(existing_set(sys.argv[2]))
    else:gui()
