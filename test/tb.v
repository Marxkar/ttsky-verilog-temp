module tb_jtag_tap;

    reg clk;
    reg rst_n;
    reg ena;
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    reg [7:0] uio_in = 8'b0;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Instantiate DUT
    tt_um_marxkar_jtag dut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // Clock generation (Cocotb can also drive this, but safe to keep)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 20ns period = 50 MHz
    end

    // Simple initial reset (Cocotb will override anyway)
    initial begin
        rst_n = 0;
        ena   = 1;
        ui_in = 8'b0;
        #50;
        rst_n = 1;
    end

endmodule
