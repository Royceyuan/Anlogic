

module hdmi_audio_video_phy #(
    parameter DEVICE = "EG"
    )(
    input wire      I_pixel_clk,
    input wire      I_serial_clk,
    input wire      I_pixel_rst,
    input wire      I_serial_rst,

    input wire[9:0] I_tmds_channel_0,
    input wire[9:0] I_tmds_channel_1,
    input wire[9:0] I_tmds_channel_2,
    input wire[9:0] I_tmds_channel_clk,
    
    output wire     O_tmds_ch0_p,
    output wire     O_tmds_ch1_p,
    output wire     O_tmds_ch2_p,
    output wire     O_tmds_clk_p
);
    
    wire[9:0] S_tmds_data_ch0;
    wire[9:0] S_tmds_data_ch1;
    wire[9:0] S_tmds_data_ch2;
    wire[9:0] S_tmds_data_clk;
    wire serial_rst_n_ch0;
    wire serial_rst_n_ch1;
    wire serial_rst_n_ch2;
    wire serial_rst_n_clk;

    // Release reset beside each ODDR lane to avoid a 375 MHz global reset fanout.
    // Preserve equivalent flops: otherwise synthesis merges the four local
    // releases back into one long reset net across the serializer lanes.
    reset_sync #(.PRESERVE("true")) u_serial_reset_ch0 (.clk(I_serial_clk), .arst_n(~I_serial_rst), .srst_n(serial_rst_n_ch0));
    reset_sync #(.PRESERVE("true")) u_serial_reset_ch1 (.clk(I_serial_clk), .arst_n(~I_serial_rst), .srst_n(serial_rst_n_ch1));
    reset_sync #(.PRESERVE("true")) u_serial_reset_ch2 (.clk(I_serial_clk), .arst_n(~I_serial_rst), .srst_n(serial_rst_n_ch2));
    reset_sync #(.PRESERVE("true")) u_serial_reset_clk (.clk(I_serial_clk), .arst_n(~I_serial_rst), .srst_n(serial_rst_n_clk));

    assign S_tmds_data_ch0 = {I_tmds_channel_0[0],
                              I_tmds_channel_0[1],
                              I_tmds_channel_0[2],
                              I_tmds_channel_0[3],
                              I_tmds_channel_0[4],
                              I_tmds_channel_0[5],
                              I_tmds_channel_0[6],
                              I_tmds_channel_0[7],
                              I_tmds_channel_0[8],
                              I_tmds_channel_0[9]};

    assign S_tmds_data_ch1 = {I_tmds_channel_1[0],
                              I_tmds_channel_1[1],
                              I_tmds_channel_1[2],
                              I_tmds_channel_1[3],
                              I_tmds_channel_1[4],
                              I_tmds_channel_1[5],
                              I_tmds_channel_1[6],
                              I_tmds_channel_1[7],
                              I_tmds_channel_1[8],
                              I_tmds_channel_1[9]};

    assign S_tmds_data_ch2 = {I_tmds_channel_2[0],
                              I_tmds_channel_2[1],
                              I_tmds_channel_2[2],
                              I_tmds_channel_2[3],
                              I_tmds_channel_2[4],
                              I_tmds_channel_2[5],
                              I_tmds_channel_2[6],
                              I_tmds_channel_2[7],
                              I_tmds_channel_2[8],
                              I_tmds_channel_2[9]};

    assign S_tmds_data_clk = {I_tmds_channel_clk[0],
                              I_tmds_channel_clk[1],
                              I_tmds_channel_clk[2],
                              I_tmds_channel_clk[3],
                              I_tmds_channel_clk[4],
                              I_tmds_channel_clk[5],
                              I_tmds_channel_clk[6],
                              I_tmds_channel_clk[7],
                              I_tmds_channel_clk[8],
                              I_tmds_channel_clk[9]};


    hdmi_tmds_lane_serializer #(
        .DEVICE ( DEVICE )    
    )u0_lane_lvds_8_1(
        .I_pixel_clk  ( I_pixel_clk     ),
        .I_serial_clk ( I_serial_clk    ),
        .I_pixel_rst  ( I_pixel_rst     ),
        .I_serial_rst ( ~serial_rst_n_ch0 ),

        .I_data_in    ( S_tmds_data_ch0 ),
        .O_serial_out ( O_tmds_ch0_p    )
    );


    hdmi_tmds_lane_serializer #(
        .DEVICE ( DEVICE )    
    )u1_lane_lvds_8_1(
        .I_pixel_clk  ( I_pixel_clk     ),
        .I_serial_clk ( I_serial_clk    ),
        .I_pixel_rst  ( I_pixel_rst     ),
        .I_serial_rst ( ~serial_rst_n_ch1 ),
        
        .I_data_in    ( S_tmds_data_ch1 ),
        .O_serial_out ( O_tmds_ch1_p    )
    );


    hdmi_tmds_lane_serializer #(
        .DEVICE ( DEVICE )    
    )u2_lane_lvds_8_1(
        .I_pixel_clk  ( I_pixel_clk     ),
        .I_serial_clk ( I_serial_clk    ),
        .I_pixel_rst  ( I_pixel_rst     ),
        .I_serial_rst ( ~serial_rst_n_ch2 ),
        
        .I_data_in    ( S_tmds_data_ch2 ),
        .O_serial_out ( O_tmds_ch2_p    )
    );


    hdmi_tmds_lane_serializer #(
        .DEVICE ( DEVICE )    
    )u3_lane_lvds_8_1(
        .I_pixel_clk  ( I_pixel_clk     ),
        .I_serial_clk ( I_serial_clk    ),
        .I_pixel_rst  ( I_pixel_rst     ),
        .I_serial_rst ( ~serial_rst_n_clk ),
        
        .I_data_in    ( S_tmds_data_clk ),
        .O_serial_out ( O_tmds_clk_p    )
    );


endmodule





