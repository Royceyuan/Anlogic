"""Read-only audit of the mounted secondary card; never opens it for writing."""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/OfflineVideo'))
from mvid2 import parse_header


def main():
    manifest=json.loads((ROOT/'tools/OfflineVideo/packages/install_manifest.json').read_text(encoding='utf-8-sig'))
    target=ROOT/'_build_secondary/tf_black_screen_audit'
    target.mkdir(parents=True,exist_ok=True)
    rows=[]
    for item in manifest['files']:
        path=Path('E:/')/item['file']
        row={'file':item['file'],'exists':path.is_file()}
        if path.is_file():
            size=path.stat().st_size
            row['bytes']=size;row['size_matches']=size==item['file_bytes']
            with path.open('rb') as stream:
                head=stream.read(512)
            if item['file'].startswith(('ART','GUIDE','EVAC')):
                row['header']=parse_header(head,size)
            else:row['magic']=head[:4].decode('ascii',errors='replace')
        rows.append(row)
        print(json.dumps(row,ensure_ascii=False),flush=True)
    sectors={}
    with open(r'\\.\E:','rb',buffering=0) as volume:
        def sector(lba):
            volume.seek(lba*512);data=volume.read(512)
            if len(data)!=512:raise ValueError('Short raw sector')
            sectors[lba]=data
            return data
        boot=sector(0)
        u16=lambda b,p:struct.unpack_from('<H',b,p)[0]
        u32=lambda b,p:struct.unpack_from('<I',b,p)[0]
        spc=boot[13];fat=u16(boot,14);fats=boot[16];fat_sectors=u32(boot,36)
        data_start=fat+fats*fat_sectors;cluster=u32(boot,44)
        geometry=dict(spc=spc,fat_start=fat,data_start=data_start,root_cluster=cluster,
            fat_sectors=fat_sectors,fats=fats,total_sectors=u32(boot,32))
        def link(c):return u32(sector(fat+c//128),(c%128)*4)&0x0fffffff
        entries=[];end=False
        while not end:
            for s in range(spc):
                data=sector(data_start+(cluster-2)*spc+s)
                for p in range(0,512,32):
                    if data[p]==0:end=True;break
                    if data[p]==0xe5 or data[p+11]&0x18 or data[p+11]==0x0f:continue
                    name=data[p:p+8].decode('ascii').rstrip()+'.'+data[p+8:p+11].decode('ascii').rstrip()
                    c=(u16(data,p+20)<<16)|u16(data,p+26)
                    entries.append(dict(file=name,cluster=c,size=u32(data,p+28)))
                if end:break
            if end:break
            cluster=link(cluster)
            if cluster>=0xffffff8:break
            if len(sectors)>256:raise ValueError('Unexpectedly long root directory')
        for item in entries:
            if item['file'] not in ('GUIDE.BIN','EVAC.BIN'):continue
            c=item['cluster'];header=sector(data_start+(c-2)*spc)
            item['raw_header_matches_mounted']=header==(Path('E:/')/item['file']).open('rb').read(512)
            chain=[]
            # Enough links for the first two production frames, not the whole card.
            for _ in range(40):chain.append(c);c=link(c)
            item['first_clusters']=chain
        geometry['root_entries']=entries
    report=dict(read_only=True,headers=rows,geometry=geometry)
    (target/'metadata.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # Reproducible metadata image for the reader simulation; no card writes.
    with (target/'metadata_sectors.hex').open('w',encoding='ascii') as output:
        for lba,data in sorted(sectors.items()):
            output.write(f'@{lba*512:x}\n'+data.hex(' ')+'\n')
    print(json.dumps(geometry,ensure_ascii=False,indent=2),flush=True)
    for item in manifest['files']:
        path=Path('E:/')/item['file']
        with path.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
        row=next(r for r in rows if r['file']==item['file'])
        row['sha256']=digest;row['hash_matches']=digest==item['sha256']
        print(f"HASH {item['file']} matches={row['hash_matches']}",flush=True)
        (target/'metadata.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assert all(row['hash_matches'] and row['size_matches'] for row in rows)
    print('PASS mounted secondary media headers and all 13 SHA256 values; card not modified')


if __name__=='__main__':main()
