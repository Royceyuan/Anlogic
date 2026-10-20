<?xml version="1.0" encoding="utf-8"?>
<Project Version="3" Minor="2" Path=".">
  <TD_Version>6.2.168116</TD_Version>
  <Name>secondary_tf_read_probe</Name>
  <HardWare><Family>EG4</Family><Device>EG4S20BG256</Device><Speed /></HardWare>
  <Source_Files>
    <Verilog>
      <File Path="src/storage/sd_native_command.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="1"/></FileInfo></File>
      <File Path="src/storage/sd_native_data_rx.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="2"/></FileInfo></File>
      <File Path="src/storage/sd_native_read.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="3"/></FileInfo></File>
      <File Path="src/secondary/top_secondary_tf_read_probe.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="4"/></FileInfo></File>
    </Verilog>
    <ADC_FILE><File Path="constraints/secondary_tf_read_probe.adc"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="constraint_1"/><Attr Name="CompileOrder" Val="1"/></FileInfo></File></ADC_FILE>
    <SDC_FILE><File Path="constraints/secondary_tf_read_probe.sdc"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="constraint_1"/><Attr Name="CompileOrder" Val="2"/></FileInfo></File></SDC_FILE>
  </Source_Files>
  <FileSets><FileSet Name="design_1" Type="DesignFiles"/><FileSet Name="constraint_1" Type="ConstrainFiles"/></FileSets>
  <TOP_MODULE><LABEL>top_secondary_tf_read_probe</LABEL><MODULE>top_secondary_tf_read_probe</MODULE><CREATEINDEX>user</CREATEINDEX></TOP_MODULE>
  <Property/><Device_Settings/><Configurations/>
  <Runs><Run Name="syn_1" Type="Synthesis" ConstraintSet="constraint_1" Description="" Active="true"><Strategy Name="Default_Synthesis_Strategy"/><UserParams/></Run><Run Name="phy_1" Type="PhysicalDesign" ConstraintSet="constraint_1" Description="" SynRun="syn_1" Active="true"><Strategy Name="Default_PhysicalDesign_Strategy"/><UserParams/></Run></Runs>
  <Project_Settings/>
</Project>
