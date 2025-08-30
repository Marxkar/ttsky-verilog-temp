import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge


async def jtag_cycle(dut, tms, tdi):
    """
    Perform one JTAG cycle with TMS and TDI.
    Maps to Verilog jtag_cycle task.
    """
    dut.ui_in.value = (tms << 1) | tdi   # ui_in[1] = TMS, ui_in[0] = TDI
    await Timer(20, units="ns")          # one clock period = 20 ns
    await RisingEdge(dut.clk)


@cocotb.test()
async def tb_jtag_tap(dut):
    """
    Cocotb testbench for JTAG TAP controller.
    Translated from tb_jtag_tap.v
    """

    # --- Clock generation (50 MHz, 20 ns period) ---
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # --- Initialize ---
    dut.rst_n.value = 0
    dut.ena.value = 1        # Always enabled for JTAG TAP
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # --- Reset sequence ---
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut._log.info("Reset deasserted, starting test sequence")

    # --- IR shifting sequence ---
    await jtag_cycle(dut, 1, 0)  # test_logic_reset
    await jtag_cycle(dut, 1, 0)  # still in test_logic_reset
    await jtag_cycle(dut, 0, 0)  # run_idle
    await jtag_cycle(dut, 1, 0)  # select_dr_scan
    await jtag_cycle(dut, 1, 0)  # select_ir_scan
    await jtag_cycle(dut, 0, 0)  # capture_ir
    await jtag_cycle(dut, 0, 1)  # shift_ir - '1'
    await jtag_cycle(dut, 0, 0)  # shift_ir - '0'
    await jtag_cycle(dut, 1, 1)  # exit_1_ir with '1'
    await jtag_cycle(dut, 0, 0)  # pause_ir
    await jtag_cycle(dut, 1, 0)  # exit_2_ir
    await jtag_cycle(dut, 0, 0)  # update_ir

    # Run idle cycles
    for _ in range(5):
        await jtag_cycle(dut, 0, 0)

    # --- DR shifting sequence ---
    await jtag_cycle(dut, 1, 0)  # select_dr_scan
    await jtag_cycle(dut, 0, 0)  # capture_dr
    await jtag_cycle(dut, 0, 1)  # shift_dr - '1'
    await jtag_cycle(dut, 0, 0)  # shift_dr - '0'
    await jtag_cycle(dut, 0, 1)  # shift_dr - '1'
    await jtag_cycle(dut, 1, 0)  # exit_1_dr
    await jtag_cycle(dut, 0, 0)  # pause_dr
    await jtag_cycle(dut, 1, 0)  # exit_2_dr
    await jtag_cycle(dut, 0, 0)  # update_dr

    # Run idle cycles
    for _ in range(5):
        await jtag_cycle(dut, 0, 0)

    # --- End of test ---
    dut._log.info("TEST COMPLETE ✅")
