
//

module i2cSlaveTop (
	input              SYS_CLK        ,
    input              rst,
	inout              sda        ,
	input              scl        ,

	output reg 			hpd_reset = 1'b0,
	output				LED

);                 

wire	lock;
wire    clk=SYS_CLK;
/*
tx_pll u1(
		.refclk(SYS_CLK),
		.reset(1'b0),
		.extlock(lock),
		.clk0_out(clk)
		);


wire [7:0]       myReg0   ;
wire  [7:0]       EDID_DATA ;
wire  [7:0]       EDID_Addr;
wire              EDID_WEN;

reg	lock_1d,hpd_flag;
always @(posedge clk)
begin
	lock_1d <= lock;
	hpd_flag <= lock & (~lock_1d);
end
*/

reg [25:0]hpd_reset_cnt = 26'd0;			
	 
always @(posedge clk)
begin
	//if(EDID_WEN&&EDID_Addr==8'h7f)
	if(rst)
		begin 
			hpd_reset<=1'b0;
			hpd_reset_cnt<=26'd0;
		end
	else  
		if(hpd_reset_cnt[25])
			begin
				hpd_reset_cnt <= hpd_reset_cnt;
				hpd_reset<=1'b1;
			end	
		else begin 
				hpd_reset<=hpd_reset;
				hpd_reset_cnt<=hpd_reset_cnt+1'b1;
			end
end


reg [15:0]  led_cnt;
always @(posedge clk)
begin
	if(lock)
		led_cnt <= led_cnt+1'b1;
	else
		led_cnt <= 16'd0;
end
assign LED=led_cnt[15];

wire nRST;
assign nRST=~lock;

/*
i2cSlave u_i2cSlave(
  .clk            (clk)    ,
  .rst            (rst)    ,
  .sda            (sda)    ,
  .scl            (scl)    ,
  .myReg0         (myReg0) ,
  .myReg1         ()       ,
  .myReg2         ()       ,
  .myReg3         ()       ,
  .myReg4         (8'h12)  ,
  .myReg5         (8'h34)  ,
  .myReg6         (8'h56)  ,
  .myReg7         (8'h78)  ,
  .EDID_DATA           (EDID_DATA           ),
  .EDID_Addr           (EDID_Addr           ),
  .EDID_WEN            (1'b0) //EDID_WEN            )

);
*/


i2c_edid u2_iic(
	.clk(clk),
	.rst(rst),
	.scl(scl),
	.sda(sda)
);




endmodule


 
