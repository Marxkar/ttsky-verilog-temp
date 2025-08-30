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

    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 20ns period = 50 MHz
    end

    initial begin
        // Initialize
        rst_n = 0;
        ena = 1; // Always enabled for JTAG TAP
        ui_in = 8'b0;

        // Hold reset for a few cycles
        #50;
        rst_n = 1; // Deassert reset
        
        // Apply JTAG TAP sequence for IR update (IDCODE or BYPASS)
        jtag_cycle(1, 0); // test_logic_reset: stay here with TMS=1
        jtag_cycle(1, 0); // still in test_logic_reset
        jtag_cycle(0, 0); // move to run_idle
        jtag_cycle(1, 0); // select_dr_scan
        jtag_cycle(1, 0); // select_ir_scan
        jtag_cycle(0, 0); // capture_ir
        jtag_cycle(0, 1); // shift_ir - shift in bit '1'
        jtag_cycle(0, 0); // shift_ir - shift in bit '0'
        jtag_cycle(1, 1); // exit_1_ir with bit '1'
        jtag_cycle(0, 0); // pause_ir
        jtag_cycle(1, 0); // exit_2_ir
        jtag_cycle(0, 0); // update_ir

        // Run idle
        repeat(5) jtag_cycle(0, 0);

        // Go to shift_dr to exercise DR shifting (bypass/idcode)
        jtag_cycle(1, 0); // select_dr_scan
        jtag_cycle(0, 0); // capture_dr
        jtag_cycle(0, 1); // shift_dr: send bits
        jtag_cycle(0, 0);
        jtag_cycle(0, 1);
        jtag_cycle(1, 0); // exit_1_dr
        jtag_cycle(0, 0); // pause_dr
        jtag_cycle(1, 0); // exit_2_dr
        jtag_cycle(0, 0); // update_dr

        // Run idle to finish
        repeat(5) jtag_cycle(0, 0);

        // End test
        $display("TEST COMPLETE");
        $finish;
    end

    // Task to apply a JTAG clock cycle with TMS and TDI
    task jtag_cycle(input tms_bit, input tdi_bit);
        begin
            ui_in[1] = tms_bit; // TMS on ui_in[1]
            ui_in[0] = tdi_bit; // TDI on ui_in[0]
            #20; // one clock period
        end
    endtask

endmodule
