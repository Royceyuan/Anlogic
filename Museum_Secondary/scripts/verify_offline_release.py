"""Refuse bit generation unless this exact build and its regression evidence pass."""
import argparse
import hashlib
import json
from pathlib import Path
import re

SECONDARY=Path(__file__).resolve().parents[1]


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream,'sha256').hexdigest()


def passed(path):
    text=path.read_text(encoding='utf-8-sig',errors='replace')
    assert 'PASS' in text and not re.search(r'^\s*(?:FAIL|FATAL|ERROR)\b',text,re.M),f'Failed test: {path}'
    return sha(path)


def verify(target):
    root=SECONDARY if target=='secondary' else SECONDARY.parent/'Museum_Main'
    build=root/('_build_secondary' if target=='secondary' else '_build_main')
    snapshot=json.loads((build/'build_sources.json').read_text(encoding='utf-8-sig'))
    for name,digest in snapshot['sources'].items():
        assert sha(root/name).lower()==digest.lower(),f'Build input changed: {name}'
    status=(build/'final.status').read_text()
    expected_top='top_secondary_offline_av' if target=='secondary' else 'dual_fpga_museum_terminal_main_board'
    assert expected_top in status,'Wrong top module'
    timing={}
    for kind in ('Setup','Hold'):
        match=re.search(rf'{kind}\s+: WNS\s+(-?\d+)ps\s+TNS\s+(-?\d+)ps\s+NUM_FEPS\s+(\d+)',status)
        assert match and int(match[1])>=0 and match.groups()[1:]==('0','0'),f'{kind} not closed'
        timing[kind.lower()+'_wns_ps']=int(match[1])
    log=(build/'console.log').read_text(encoding='utf-8-sig',errors='replace')
    synthesis=build/'synthesis.log'
    synthesis_text=synthesis.read_text(encoding='utf-8-sig',errors='replace') if target=='secondary' and synthesis.exists() else log
    combined=synthesis_text+'\n'+log
    seeds=re.findall(r'start command "set_param place seed (\d+)"',log)
    assert seeds,'Missing actual placement seed in routed log'
    level_opts=re.findall(r'start command "set_param place logic_level_opt (on|off)"',log)
    assert ('MUSEUM_SECONDARY_ROUTE_FINISHED' if target=='secondary' else 'MUSEUM_MAIN_ROUTE_FINISHED') in log,'Incomplete route'
    assert not re.search(r' ERROR:|No clock match|Clock group is empty|black box',combined,re.I),'Build/clock/black-box error'
    assert 'No multi-drive.' in log and 'No abnormal timing path.' in log,'DRC evidence missing'
    implicit={}
    for name in set(re.findall(r'analyze (?:verilog|vhdl) file ([^\r\n]+)',synthesis_text)):
        path=root/name.strip()
        assert path.is_file() and path.stat().st_mtime<=(build/'gate.db').stat().st_mtime,f'Implicit source changed: {path}'
        implicit[name]=sha(path)
    reviewed=[]
    for line in set(line.strip() for line in combined.splitlines() if 'CRITICAL-WARNING:' in line):
        if re.fullmatch(r"PHY-7002 CRITICAL-WARNING: Instance .*?/u_sdram/sdram location \((?:12, 12|164, 288)\) is not honored\..*",line):
            reviewed.append(dict(message=line,reason='Inherited SDRAM macro placement repaired by router; final DRC/timing checked'))
        elif line.startswith('PHY-5079 CRITICAL-WARNING: Marked 1 clock net(s) utilize the local routing resources.'):
            assert re.search(r'AL_PHY_PLL\s+\|\s+0/1\s+\|\s+1\s+\|\s+\S*/u_sdram/u2_ram/SDRAM_CLK\s+\|\s+true',log),'Unknown local clock sink'
            reviewed.append(dict(message=line,reason='Single phase-shifted clock drives only SDRAM output pin; routed timing checked'))
        elif target=='main' and line.startswith("USR-6136 CRITICAL-WARNING: 'derive_pll_clocks' is obsolete."):
            assert 'Derived clock:' in log,'PLL clocks were not derived'
            reviewed.append(dict(message=line,reason='Inherited supported TD command; generated PLL clocks are present in routed report'))
        elif target=='main' and line=="PRJ-7002 CRITICAL-WARNING: Load IPC file v error, the IP's generated file D doesn't exist.":
            for name in ('rx_pll','pll_gen'):
                assert f'elaborate module {name} ' in log,f'Missing generated module {name}'
                assert any(key.endswith('/'+name+'.v') for key in implicit),f'Missing generated source {name}'
            reviewed.append(dict(message=line,reason='Legacy IPC loader metadata warning; generated PLL Verilog directly analyzed and elaborated, no black boxes'))
        else:raise AssertionError('Unreviewed critical warning: '+line)
    regression=SECONDARY/'_build_offline_integration'
    hashes=json.loads((regression/'source_sha256.json').read_text(encoding='utf-8-sig'))
    for name,digest in hashes.items():
        assert sha(SECONDARY/name).lower()==digest.lower(),f'Test input changed: {name}'
    tests={path.name:passed(path) for path in regression.glob('*.log') if path.stem in (
        'media_format','subtitle_reuse','subtitle_slide_1','subtitle_slide_5','fat32_mvid_reader','mvid2_reader','mvid_seek_cache','mvid_geometry','mvid_pcm_commit',
        'secondary_offline_scene_control','mvid_frame_control','offline_file_switch','secondary_offline_request_cdc',
        'mbp1_secondary_endpoint','offline_sd_arbiter','offline_audio_output','offline_audio_fade','offline_audio_continuity',
        'secondary_offline_main_timeline','museum_voice_handoff','offline_voice_protocol','offline_osd_switch',
        'offline_av_pipeline','offline_subtitle_files','secondary_offline_overlay','secondary_compact_waveform','offline_main_state','main_visualizer_reuse')}
    assert len(tests)==28,'Missing regression logs'
    hdmi=SECONDARY/'_build_secondary/hdmi_audio.log'
    tests['hdmi_audio.log']=passed(hdmi)
    assert hdmi.read_text(encoding='utf-8-sig',errors='replace').count('PASS')>=6,'Incomplete HDMI checks'
    for name in ('src/video/secondary_hdmi_packet_symbols.v','src/video/secondary_hdmi_local_pairs.v',
                 'sim/tb_secondary_hdmi_packet_symbols.v','sim/run_offline_hdmi_audio.do'):
        assert (SECONDARY/name).stat().st_mtime<=hdmi.stat().st_mtime,'Stale HDMI simulation'
    tests['tool_conversion.log']=passed(SECONDARY/'_build_offline_media_tool/conversion_test.log')
    test_sources={}
    if target=='main':
        tests['main_endpoint_control.log']=passed(build/'main_endpoint_control.log')
        for name in ('half_stream_physical','key1_zoom','zoom_osd','zoom_osd_physical','remote_controls','local_controls',
                     'application_recovery','emergency_recovery','audio_playback_speed','subtitle_playback_speed','wav_address_timing',
                     'overview_black_loading','half_memory_bandwidth','read_completion'):
            path=build/(name+'.log')
            text=path.read_text(encoding='utf-8-sig',errors='replace')
            assert not re.search(r'#\s+(?:\*\* (?:Fatal|Error)|Errors: [1-9]|FAIL)',text),f'ModelSim failure: {name}'
            tests[path.name]=passed(path)
        assert (build/'half_stream_physical.log').read_text().count('PASS 0.5x')==2,'Missing physical BRAM half-scale test'
        for test,names in {
            'half_stream_physical':('sim/tb_linebuf_scaler_zoom_stream.v','sim/run_viewport_pan_stream.do'),
            'key1_zoom':('sim/tb_museum_media_core.v','sim/run_viewport_zoom.do'),
            'zoom_osd':('sim/tb_museum_status_osd.v','sim/run_museum_status_osd.do'),
            'zoom_osd_physical':('sim/tb_museum_status_osd.v','sim/run_zoom_osd_physical.do'),
            'wav_address_timing':('sim/tb_wav_cluster_address.v','sim/tb_fat32_wav_streamer.v','sim/run_wav_address_timing.do'),
            'overview_black_loading':('sim/tb_museum_overview_overlay.v','sim/run_museum_overview.do'),
            'half_memory_bandwidth':('sim/tb_half_zoom_memory.v','sim/run_half_zoom_memory.do'),
            'read_completion':('sim/tb_frame_fifo_read_completion.v','sim/run_frame_fifo_read_completion.do'),
        }.items():
            for name in names:
                assert (root/name).stat().st_mtime<=(build/(test+'.log')).stat().st_mtime,f'Stale zoom simulation: {test}'
                test_sources[name]=sha(root/name)
        test_sources['scripts/verify_zoom.ps1']=sha(root/'scripts/verify_zoom.ps1')
    area=(build/'final.area').read_text()
    resources={name:int(re.search(rf'^#{name}\s+(\d+)',area,re.M)[1]) for name in ('lut','reg','bram','bram32k','dsp','pll')}
    assert resources['pll']<=4 and resources['lut']<=19600 and resources['bram']<=64 and resources['bram32k']<=16
    result=dict(target=target,project=snapshot['project'],placement_seed=int(seeds[-1]),
        logic_level_opt=level_opts[-1] if level_opts else None,timing=timing,resources=resources,
        database_sha256=sha(build/'final.db'),captured_sources=snapshot['sources'],
        analyzed_sources=implicit,tests=tests,test_sources=test_sources,reviewed_warnings=reviewed,board_verified=False)
    (build/'release_verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'PASS {target} release gate: {timing}; resources={resources}; not a board result')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target',choices=('secondary','main'))
    verify(parser.parse_args().target)
