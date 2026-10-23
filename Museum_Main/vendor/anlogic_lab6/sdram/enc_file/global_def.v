


`define   DATA_WIDTH                        32
`define   ADDR_WIDTH                        21
`define   DM_WIDTH                          4

`define   ROW_WIDTH                        11
`define   BA_WIDTH                        2

`define	  SDR_CLK_PERIOD				1000000000/125000000
// This local lab stack runs the SDRAM controller at 25 MHz. Keep the
// required 2048 refresh commands within 64 ms: 25e6 * 64e-3 / 2048 = 781.
`define   SELF_REFRESH_INTERVAL                         781

