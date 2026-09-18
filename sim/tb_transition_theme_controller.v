`timescale 1ns / 1ps

module tb_transition_theme_controller;
reg [1:0] theme, context, demo_step;
wire [2:0] primitive_mode;
integer i;

transition_theme_controller dut (
    .theme(theme), .context(context), .demo_step(demo_step),
    .primitive_mode(primitive_mode)
);

task expect;
    input [1:0] t;
    input [1:0] c;
    input [1:0] d;
    input [2:0] p;
    begin
        theme=t; context=c; demo_step=d; #1;
        if (primitive_mode !== p)
            $fatal(1, "theme=%0d context=%0d demo=%0d got=%0d expected=%0d",
                   t, c, d, primitive_mode, p);
    end
endtask

initial begin
    expect(0,0,0,0); expect(0,1,0,0); expect(0,2,0,2);
    expect(1,0,0,1); expect(1,1,0,1); expect(1,2,0,3);
    expect(2,0,0,3); expect(2,1,0,1); expect(2,2,0,2);
    expect(3,0,0,0); expect(3,2,0,3);
    for (i=0; i<4; i=i+1)
        expect(3,1,i[1:0],i[2:0]);
    $display("PASS phase4 theme mapping and Demo rotation");
    $finish;
end
endmodule
