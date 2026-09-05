`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: anlgoic
// Author: 	xg 
// description:  top module
//////////////////////////////////////////////////////////////////////////////////

`define DEBUG

`include "vendor/anlogic_lab6/sdram/enc_file/global_def.v"

module sdram(
    `ifdef SIMULATION
	output					SDRAM_CLK,
	output					SDR_CKE,
	output					SDR_RAS,
	output					SDR_CAS,
	output					SDR_WE,
	output	[`BA_WIDTH-1:0]	SDR_BA,
	output	[`ROW_WIDTH-1:0]SDR_ADDR,
	output	[`DM_WIDTH-1:0]	SDR_DM,
	inout	[`DATA_WIDTH-1:0]	SDR_DQ,	
	`endif
    input   					Clk,
    input						Clk_sft,
    input						Rst,
    
    output 						Sdr_init_done,
    output						Sdr_init_ref_vld,
    output						Sdr_busy,
    
    input						App_wr_en,
	input [`ADDR_WIDTH-1:0]		App_wr_addr,  	
	input [`DM_WIDTH-1:0]		App_wr_dm,
	input [`DATA_WIDTH-1:0]		App_wr_din,	//synthesis keep
    
    input 						App_rd_en,
	input [`ADDR_WIDTH-1:0]		App_rd_addr,
	output 						Sdr_rd_en,
	output [`DATA_WIDTH-1:0]	Sdr_rd_dout,	//synthesis keep
	// Optional diagnostic taps. They expose the existing controller bus only.
	output wire						 dbg_write_cmd,
	output wire [`BA_WIDTH-1:0]	 dbg_ba,
	output wire [`ROW_WIDTH-1:0]	dbg_addr,
	output wire [`DM_WIDTH-1:0]	 dbg_dm,
	output wire [`DATA_WIDTH-1:0]	dbg_dq,
	output wire						 dbg_ras_n,
	output wire						 dbg_cas_n,
	output wire						 dbg_we_n,
	output wire                         dbg_sdram_clk
    
    
    
);
`ifndef SIMULATION
wire  			SDRAM_CLK;
wire 			SDR_RAS;
wire  			SDR_CAS;
wire  			SDR_WE;
wire  [`BA_WIDTH-1:0]	SDR_BA; 
wire  [`ROW_WIDTH-1:0]	SDR_ADDR;
wire  [`DATA_WIDTH-1:0]	SDR_DQ ;
wire  [`DM_WIDTH-1:0]	SDR_DM; 
`endif

sdr_as_ram  #( .self_refresh_open(1'b1))
	u2_ram( 
		.Sdr_clk(Clk),
		.Sdr_clk_sft(Clk_sft),
		.Rst(Rst),
			  			  
		.Sdr_init_done(Sdr_init_done),
		.Sdr_init_ref_vld(Sdr_init_ref_vld),
		.Sdr_busy(Sdr_busy),
		
		.App_ref_req(1'b0),
		
        .App_wr_en(App_wr_en), 
        .App_wr_addr(App_wr_addr),  	
		.App_wr_dm(App_wr_dm),
		.App_wr_din(App_wr_din),

		.App_rd_en(App_rd_en),
		.App_rd_addr(App_rd_addr),
		.Sdr_rd_en	(Sdr_rd_en),
		.Sdr_rd_dout(Sdr_rd_dout),
	
		.SDRAM_CLK(SDRAM_CLK),
		.SDR_RAS(SDR_RAS),
		.SDR_CAS(SDR_CAS),
		.SDR_WE(SDR_WE),
		.SDR_BA(SDR_BA),
		.SDR_ADDR(SDR_ADDR),
		.SDR_DM(SDR_DM),
		.SDR_DQ(SDR_DQ)	
	);


assign SDR_CKE=1'b1;

// SDRAM command pins are active-low: WRITE is RAS_n=0, CAS_n=0, WE_n=0.
assign dbg_write_cmd = !SDR_RAS && !SDR_CAS && !SDR_WE;
assign dbg_ba         = SDR_BA;
assign dbg_addr       = SDR_ADDR;
assign dbg_dm         = SDR_DM;
assign dbg_dq         = SDR_DQ;
assign dbg_ras_n      = SDR_RAS;
assign dbg_cas_n      = SDR_CAS;
assign dbg_we_n       = SDR_WE;
assign dbg_sdram_clk  = SDRAM_CLK;

//`ifndef SIMULATION
	EG_PHY_SDRAM_2M_32 sdram(
		.clk(SDRAM_CLK),
		.ras_n(SDR_RAS),
		.cas_n(SDR_CAS),
		.we_n(SDR_WE),
		.addr(SDR_ADDR[10:0]),
		.ba(SDR_BA),
		.dq(SDR_DQ),
		.cs_n(1'b0),
		.dm0(SDR_DM[0]),
		.dm1(SDR_DM[1]),
		.dm2(SDR_DM[2]),
		.dm3(SDR_DM[3]),
		.cke(1'b1)
		);
//`endif

endmodule 
