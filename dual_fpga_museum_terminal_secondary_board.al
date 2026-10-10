<?xml version='1.0' encoding='utf-8'?>
<Project Version="3" Minor="2" Path=".">
    <Project_Created_Time />
    <TD_Version>6.2.168116</TD_Version>
    <Name>dual_fpga_museum_terminal_secondary_board</Name>
    <HardWare>
        <Family>EG4</Family>
        <Device>EG4S20BG256</Device>
        <Speed />
    </HardWare>
    <Source_Files>
        <Verilog>
            <File Path="src/common/reset_sync.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="1" />
                </FileInfo>
            </File>
            <File Path="src/common/seg_hex_display.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="2" />
                </FileInfo>
            </File>
            <File Path="src/input/key_debounce.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="3" />
                </FileInfo>
            </File>
            <File Path="src/video/video_timing_640x480_pclk.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="4" />
                </FileInfo>
            </File>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/video_delay.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="5" />
                </FileInfo>
            </File>
            <File Path="src/storage/fat32_image_loader.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="6" />
                </FileInfo>
            </File>
            <File Path="src/storage/adaptive_row_ram.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="7" />
                </FileInfo>
            </File>
            <File Path="src/storage/al_dp_ram16.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="8" />
                </FileInfo>
            </File>
            <File Path="src/storage/bmp_row_buffer.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="10" />
                </FileInfo>
            </File>
            <File Path="src/storage/rgb565_stream_packer_ready.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="11" />
                </FileInfo>
            </File>
            <File Path="src/storage/bmp_sdram_row_writer.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="13" />
                </FileInfo>
            </File>
            <File Path="src/video/rgb888_adjust.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="15" />
                </FileInfo>
            </File>
            <File Path="src/video/video_fade.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="19" />
                </FileInfo>
            </File>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/sd_card/spi_master.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="20" />
                </FileInfo>
            </File>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/sd_card/sd_card_cmd.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="21" />
                </FileInfo>
            </File>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/sd_card/sd_card_sec_read_write.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="22" />
                </FileInfo>
            </File>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/sd_card/sd_card_top.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="23" />
                </FileInfo>
            </File>
            <File Path="src/memory/anlogic_frame_store.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="24" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/frame_read_write.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="25" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/frame_fifo_read.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="26" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/frame_fifo_write.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="27" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/al_ip/afifo_16_32_256.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="28" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/al_ip/afifo_32_16_256.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="29" />
                </FileInfo>
            </File>
            <File Path="src/clock/sys_pll_50m_phase144_native720.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="30" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/sdram/sdram.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="32" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/sdram/enc_file/global_def.v">
                <FileInfo>
                    <Attr Name="AutoExcluded" Val="true" />
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="33" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/sdram/enc_file/sdr_as_ram.enc.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="34" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/sdram/enc_file/sdr_init_ref.enc.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="35" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_lab6/sdram/enc_file/sdr_wrrd.enc.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="36" />
                </FileInfo>
            </File>
            <File Path="src/memory/sdram_bmp_row_top_v66.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="38" />
                </FileInfo>
            </File>
            <File Path="src/video/video_transition_mask.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="40" />
                </FileInfo>
            </File>
            <File Path="src/clock/video_pll_75m.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="52" />
                </FileInfo>
            </File>
            <File Path="src/video/transition_theme_controller.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="66" />
                </FileInfo>
            </File>
            <File Path="src/video/product_show_controller.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="67" />
                </FileInfo>
            </File>
            <File Path="src/secondary/secondary_carousel_controller.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="78" />
                </FileInfo>
            </File>
            <File Path="src/secondary/secondary_page_overlay.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="79" />
                </FileInfo>
            </File>
            <File Path="src/secondary/secondary_help_overlay.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="80" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/clk_gen_rst_gen.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="101" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/div_clk_gen.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="102" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/IDDR.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="103" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/ODDR.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="104" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/RAMB16_S9_S9.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="105" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/rgmii_interface.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="106" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/rx_client_fifo.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="107" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/temac_block.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="108" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/temac_clk_gen.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="109" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/tx_client_fifo.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="110" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/src/tx_clk_en_gen.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="111" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/rx_pll.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="113" />
                </FileInfo>
            </File>
            <File Path="vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/pll_gen.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="114" />
                </FileInfo>
            </File>
            <File Path="src/ethernet/mdio_clause22_monitor.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="115" />
                </FileInfo>
            </File>
            <File Path="src/ethernet/mbp1_fixed_udp.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="117" />
                </FileInfo>
            </File>
            <File Path="src/ethernet/mbp1_codec.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="118" />
                </FileInfo>
            </File>
            <File Path="src/ethernet/mbp1_secondary_endpoint.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="120" />
                </FileInfo>
            </File>
            <File Path="src/secondary/top_secondary_main5e_netdiag.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="121" />
                </FileInfo>
            </File>
            <File Path="src/secondary/secondary_main5e_status_adapter.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="122" />
                </FileInfo>
            </File>
            <File Path="src/secondary/secondary_main5e_keys.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="124" />
                </FileInfo>
            </File>
            <File Path="src/secondary/top_secondary_main5e.v">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="126" />
                </FileInfo>
            </File>
            <File Path="src/clock/secondary_media_eth_pll.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="201" /></FileInfo></File>
            <File Path="src/secondary/top_secondary_shared_clock.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="202" /></FileInfo></File>
        <File Path="src/clock/hdmi_relay_clock.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="220" /></FileInfo></File>
<File Path="src/video/hdmi_relay_phy.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="221" /></FileInfo></File>
<File Path="src/video/hdmi_edid_720p.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="222" /></FileInfo></File>
<File Path="src/video/hdmi_tmds_monitor.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="223" /></FileInfo></File>
<File Path="src/secondary/top_secondary_hdmi_relay_diag.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="224" /></FileInfo></File>
<File Path="vendor/official_hdmi_loop_edid/myedid_new.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="225" /></FileInfo></File>
<File Path="vendor/official_hdmi_loop_edid/i2c_edid.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="226" /></FileInfo></File>
<File Path="vendor/official_hdmi_loop_edid/i2cSlaveTop.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="227" /></FileInfo></File>
<File Path="src/video/secondary_hdmi_local_pairs.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="228" /></FileInfo></File>
<File Path="src/video/secondary_hdmi_source_switch.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="229" /></FileInfo></File>
<File Path="src/secondary/top_secondary_hdmi_museum.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="230" /></FileInfo></File>
<File Path="src/common/uart_byte_io.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="231" /></FileInfo></File>
<File Path="src/secondary/secondary_video_uart_control.v"><FileInfo><Attr Name="UsedInSyn" Val="true" /><Attr Name="UsedInP&amp;R" Val="true" /><Attr Name="BelongTo" Val="design_1" /><Attr Name="CompileOrder" Val="232" /></FileInfo></File>
</Verilog>
        <VHDL>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/hdmi_tx.vhd">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="41" />
                </FileInfo>
            </File>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/DVITransmitter.enc.vhd">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="43" />
                </FileInfo>
            </File>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/SerializerN_1_lvds.enc.vhd">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="46" />
                </FileInfo>
            </File>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/SerializerN_1_lvds_dat.enc.vhd">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="48" />
                </FileInfo>
            </File>
            <File Path="vendor/official_ref/lab_ex_6_tf_sdram_hdmi/hdmi/enc_file/TMDSEncoder.enc.vhd">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="50" />
                </FileInfo>
            </File>
        </VHDL>
        <ADC_FILE>
            <File Path="constraints/secondary_hdmi_museum.adc">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="constraint_1" />
                    <Attr Name="CompileOrder" Val="1" />
                </FileInfo>
            </File>
        </ADC_FILE>
        <SDC_FILE>
            <File Path="constraints/secondary_hdmi_museum.sdc">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="constraint_1" />
                    <Attr Name="CompileOrder" Val="2" />
                </FileInfo>
            </File>
        </SDC_FILE>
        <IP_FILE>
            <File Path="vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/TEMAC_CORE.ipc">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true" />
                    <Attr Name="UsedInP&amp;R" Val="true" />
                    <Attr Name="BelongTo" Val="design_1" />
                    <Attr Name="CompileOrder" Val="200" />
                </FileInfo>
            </File>
        </IP_FILE>
    </Source_Files>
    <FileSets>
        <FileSet Name="design_1" Type="DesignFiles">
        </FileSet>
        <FileSet Name="constraint_1" Type="ConstrainFiles">
        </FileSet>
    </FileSets>
    <TOP_MODULE>
        <LABEL>top_secondary_hdmi_museum</LABEL>
        <MODULE>top_secondary_hdmi_museum</MODULE>
        <CREATEINDEX>user</CREATEINDEX>
    </TOP_MODULE>
    <Property>
    </Property>
    <Device_Settings>
    </Device_Settings>
    <Configurations>
    </Configurations>
    <Runs>
        <Run Name="syn_1" Type="Synthesis" ConstraintSet="constraint_1" Description="" Active="true">
            <Strategy Name="Default_Synthesis_Strategy">
            </Strategy>
            <UserParams>
            </UserParams>
        </Run>
        <Run Name="phy_1" Type="PhysicalDesign" ConstraintSet="constraint_1" Description="" SynRun="syn_1" Active="true">
            <Strategy Name="Default_PhysicalDesign_Strategy">
            </Strategy>
            <UserParams>
            </UserParams>
        </Run>
    </Runs>
    <Project_Settings>
    </Project_Settings>
</Project>
