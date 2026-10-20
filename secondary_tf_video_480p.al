<?xml version="1.0" encoding="utf-8"?>
<Project Version="3" Minor="2" Path=".">
<TD_Version>6.2.168116</TD_Version><Name>secondary_tf_video_480p</Name>
<HardWare><Family>EG4</Family><Device>EG4S20BG256</Device><Speed/></HardWare>
<Source_Files><Verilog>
<File Path="src/common/reset_sync.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="1"/></FileInfo></File>
<File Path="src/input/key_debounce.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="2"/></FileInfo></File>
<File Path="src/storage/sd_native_command.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="3"/></FileInfo></File>
<File Path="src/storage/sd_native_data_rx.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="4"/></FileInfo></File>
<File Path="src/storage/sd_native_read.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="5"/></FileInfo></File>
<File Path="src/storage/fat32_mvid_reader.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="6"/></FileInfo></File>
<File Path="src/video/mvid_frame_control.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="7"/></FileInfo></File>
<File Path="src/video/mvid_scale2x.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="8"/></FileInfo></File>
<File Path="src/video/video_timing_640x480_pclk.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="9"/></FileInfo></File>
<File Path="src/video/secondary_hdmi_local_pairs.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="10"/></FileInfo></File>
<File Path="src/video/secondary_hdmi_symbol_pairs.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="11"/></FileInfo></File>
<File Path="src/memory/anlogic_frame_store.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="12"/></FileInfo></File>
<File Path="vendor/anlogic_lab6/frame_read_write.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="13"/></FileInfo></File>
<File Path="vendor/anlogic_lab6/frame_fifo_write.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="14"/></FileInfo></File>
<File Path="vendor/anlogic_lab6/frame_fifo_read.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="15"/></FileInfo></File>
<File Path="vendor/anlogic_lab6/al_ip/afifo_16_32_256.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="16"/></FileInfo></File>
<File Path="vendor/anlogic_lab6/al_ip/afifo_32_16_256.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="17"/></FileInfo></File>
<File Path="vendor/anlogic_lab6/sdram/sdram.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="18"/></FileInfo></File>
<File Path="vendor/anlogic_lab6/sdram/enc_file/sdr_as_ram.enc.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="19"/></FileInfo></File>
<File Path="vendor/anlogic_lab6/sdram/enc_file/sdr_init_ref.enc.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="20"/></FileInfo></File>
<File Path="vendor/anlogic_lab6/sdram/enc_file/sdr_wrrd.enc.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="21"/></FileInfo></File>
<File Path="src/secondary/top_secondary_tf_video.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="22"/></FileInfo></File>
</Verilog><VHDL><File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/TMDSEncoder.enc.vhd"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="23"/></FileInfo></File></VHDL>
<ADC_FILE><File Path="constraints/secondary_tf_video.adc"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="constraint_1"/><Attr Name="CompileOrder" Val="1"/></FileInfo></File></ADC_FILE>
<SDC_FILE><File Path="constraints/secondary_tf_video.sdc"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="constraint_1"/><Attr Name="CompileOrder" Val="2"/></FileInfo></File></SDC_FILE>
</Source_Files>
<FileSets><FileSet Name="design_1" Type="DesignFiles"><Config><Define Name="TF_VIDEO_HEIGHT" Val="480"/></Config></FileSet><FileSet Name="constraint_1" Type="ConstrainFiles"/></FileSets>
<TOP_MODULE><LABEL>top_secondary_tf_video</LABEL><MODULE>top_secondary_tf_video</MODULE><CREATEINDEX>user</CREATEINDEX></TOP_MODULE>
<Property/><Device_Settings/><Configurations/>
<Runs><Run Name="syn_1" Type="Synthesis" ConstraintSet="constraint_1" Description="" Active="true"><Strategy Name="Default_Synthesis_Strategy"/><UserParams/></Run>
<Run Name="phy_1" Type="PhysicalDesign" ConstraintSet="constraint_1" Description="" SynRun="syn_1" Active="true"><Strategy Name="Default_PhysicalDesign_Strategy"/><UserParams/></Run></Runs>
<Project_Settings/>
</Project>
