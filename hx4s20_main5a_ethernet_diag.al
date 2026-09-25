<?xml version="1.0" encoding="UTF-8"?>
<Project Version="3" Minor="2" Path="D:/VSCode/CodeFiles/Git_TD/Anlogic">
    <TD_Version>6.2.168116</TD_Version>
    <Name>hx4s20_main5a_ethernet_diag</Name>
    <HardWare><Family>EG4</Family><Device>EG4S20BG256</Device><Speed></Speed></HardWare>
    <Source_Files>
        <Verilog>
            <File Path="src/common/seg_hex_display.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="1"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/BUFGMUX.v"><FileInfo><Attr Name="AutoExcluded" Val="true"/><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="2"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/clk_gen_rst_gen.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="3"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/div_clk_gen.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="4"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/IDDR.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="5"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/ODDR.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="6"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/RAMB16_S9_S9.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="7"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/rgmii_interface.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="8"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/rx_client_fifo.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="9"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/temac_block.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="10"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/temac_clk_gen.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="11"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/tx_client_fifo.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="12"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/tx_clk_en_gen.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="13"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/src/udp_ip_protocol_stack_merge.enc.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="14"/></FileInfo></File>
            <File Path="src/ethernet/mdio_clause22_monitor.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="15"/></FileInfo></File>
            <File Path="src/ethernet/udp_echo_buffer.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="16"/></FileInfo></File>
            <File Path="src/top/top_main5a_ethernet_diag.v"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="17"/></FileInfo></File>
        </Verilog>
        <ADC_FILE><File Path="constraints/top_main5a_ethernet_diag.adc"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="constrain_1"/><Attr Name="CompileOrder" Val="1"/></FileInfo></File></ADC_FILE>
        <SDC_FILE><File Path="constraints/top_main5a_ethernet_diag.sdc"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="constrain_1"/><Attr Name="CompileOrder" Val="2"/></FileInfo></File></SDC_FILE>
        <IP_FILE>
            <File Path="vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/TEMAC_CORE.ipc"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="18"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/rx_pll.ipc"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="19"/></FileInfo></File>
            <File Path="vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/pll_gen.ipc"><FileInfo><Attr Name="UsedInSyn" Val="true"/><Attr Name="UsedInP&amp;R" Val="true"/><Attr Name="BelongTo" Val="design_1"/><Attr Name="CompileOrder" Val="20"/></FileInfo></File>
        </IP_FILE>
    </Source_Files>
    <FileSets><FileSet Name="design_1" Type="DesignFiles"></FileSet><FileSet Name="constrain_1" Type="ConstrainFiles"></FileSet></FileSets>
    <TOP_MODULE><LABEL>top_main5a_ethernet_diag</LABEL><MODULE>top_main5a_ethernet_diag</MODULE><CREATEINDEX>user</CREATEINDEX></TOP_MODULE>
    <Property></Property><Device_Settings></Device_Settings><Configurations></Configurations>
    <Runs>
        <Run Name="syn_1" Type="Synthesis" ConstraintSet="constrain_1" Description="" Active="true"><Strategy Name="Default_Synthesis_Strategy"></Strategy><UserParams></UserParams></Run>
        <Run Name="phy_1" Type="PhysicalDesign" ConstraintSet="constrain_1" Description="" SynRun="syn_1" Active="true"><Strategy Name="Default_PhysicalDesign_Strategy"></Strategy><UserParams></UserParams></Run>
    </Runs>
</Project>
