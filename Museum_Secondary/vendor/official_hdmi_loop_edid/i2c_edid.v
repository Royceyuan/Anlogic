
`default_nettype none
//`include "../../../boards/atlys/rtl/setup.v"

//`define R_1280_1024
//`define R_1280_1024_A
 `define R_1280_720

module i2c_edid
#(
//	parameter HEX_FILE = "/i2c_edid/software/edid/DELL3007WFP.hex"
	//parameter HEX_FILE = "/i2c_edid/software/HP2159.hex"
	parameter HEX_FILE = "F:/app/app_customer/hz_hk/hdmi_2_mipi/i2c_edid/iic_edid/software/aom_CannonCam.hex"
) (
`ifdef DEBUG
	input wire [7:0] switch,
	output wire [7:0] led,
`endif
	input wire clk,
	input wire rst,
	input wire scl,
	inout wire sda
);

reg         hiz = 1'b1;
reg         sda_out = 1'b0;
reg [4:0]   count = 5'd0;
reg [15:0]  rdata = 24'h0;
reg [7:0]   addr = 8'h0;
reg [7:0]   data = 8'h0;
parameter   EDID_IDLE     = 3'b000;
parameter   EDID_ADDR     = 3'b001;
parameter   EDID_ADDR_ACK = 3'b010;
parameter   EDID_ADDR_ACK2= 3'b011;
parameter   EDID_DATA     = 3'b100;
parameter   EDID_DATA_ACK = 3'b101;
parameter   EDID_DATA_ACK2= 3'b110;
reg [2:0]   edid_state = EDID_IDLE;
reg [3:0]   scl_data = 4'h00;
reg [3:0]   sda_data = 4'h00;
`ifdef DEBUG
reg [7:0]   led_r [0:255];
reg [7:0]   led_count = 8'h00;
`endif

wire        scl_posedge, scl_negedge, scl_high;
assign scl_posedge = (scl_data == 4'b0111);
assign scl_negedge = (scl_data == 4'b1000);
assign scl_high    = (scl_data == 4'b1111);

wire [7:0] dout;

/*
edid_rom # (
	.HEX_FILE(HEX_FILE)
) edid_rom_0 (
	.clk(clk),
	.addr(addr[7:0]),
	.dout(dout)
);
*/


myedid_new myedid_new_ram( 
		.rsta	(1'b0),
       .clka       (clk),
       .wea        (1'b0),
       .addra      (addr[7:0]),
       .dia       (),      
       .doa  	   (dout)   
       );    




always @(posedge clk) begin
	if (rst) begin
		hiz <= 1'b1;
		sda_out <= 1'b0;
		count <= 5'd0;
		rdata <= 24'h0;
		addr <= 8'h0;
		data <= 8'h0;
		scl_data <= 4'h00;
		sda_data <= 4'h00;
	end else begin
		scl_data <= {scl_data[2:0], scl};
		sda_data <= {sda_data[2:0], sda};

		if (sda_data == 4'b1000 && scl_high) begin		// Start
			count <= 5'd0;
			hiz <= 1'b1;
			sda_out <= 1'b0;
			edid_state <= EDID_ADDR;
		end else if (sda_data == 4'b0111 && scl_high) begin	// Stop
			edid_state <= EDID_IDLE;
		end else
		case (edid_state)
		EDID_IDLE: begin
			hiz <= 1'b1;
			sda_out <= 1'b0;
		end
		EDID_ADDR: begin
			if (scl_posedge) begin
				count <= count + 5'd1;
				rdata  <= {rdata[14:0], sda};
				if (count[2:0] == 3'd7) begin
`ifdef DEBUG
if (led_count != 8'd255)
led_count <= led_count + 8'd1;
led_r[ led_count ] <= {rdata[6:0], sda};
`endif
					if (count == 5'd15)
						addr <= {rdata[6:0],sda};
					edid_state <= EDID_ADDR_ACK;
				end
			end
		end
		EDID_ADDR_ACK: begin
			if (scl_negedge) begin
				hiz <= 1'b0;
				sda_out <= 1'b0;
				if (count == 5'd8 && rdata [0] == 1'b1) begin
					data <= dout;
					edid_state <= EDID_DATA;
				end else begin
					edid_state <= EDID_ADDR_ACK2;
				end
			end
		end
		EDID_ADDR_ACK2: begin
			if (scl_negedge) begin
				hiz <= 1'b1;
				edid_state <= EDID_ADDR;
			end
		end
		EDID_DATA: begin
			if (scl_negedge) begin
				count <= count + 5'd1;
				hiz <= 1'b0;
				sda_out <= data[7];
				data <= {data[6:0], 1'b0};
				if (count[2:0] == 3'd7) begin
`ifdef 	DEBUG
if (led_count != 8'd255)
led_count <= led_count + 8'd1;
led_r[ led_count ] <= dout;
`endif
					addr <= addr + 8'h1;
					edid_state <= EDID_DATA_ACK;
				end
			end
		end
		EDID_DATA_ACK: begin
			if (scl_negedge) begin
				data <= dout;
				hiz <= 1'b1;
				sda_out <= 1'b0;
				edid_state <= EDID_DATA_ACK2;
			end
		end
		EDID_DATA_ACK2: begin
			if (scl_posedge) begin
				if (sda)
					edid_state <= EDID_IDLE;
				else
					edid_state <= EDID_DATA;
			end
		end
		endcase
	end
end

assign sda = hiz ? 1'hz : sda_out;
`ifdef DEBUG
assign led = led_r[switch];
`endif

endmodule // edid



`default_nettype wire
