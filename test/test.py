import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge


async def jtag_cycle(dut, tms, tdi):
    """One JTAG cycle with TMS and TDI (matches Verilog task)."""
    dut.ui_in.value = (tms << 1) | tdi   # ui_in[1] = TMS, ui_in[0] = TDI
    await Timer(20, units="ns")          # one clock period (20ns @ 50MHz)
    await RisingEdge(dut.clk)


@cocotb.test()
async def tb_jtag_tap(dut):
    """Cocotb testbench translated from tb_jtag_tap.v with checks"""

    # --- Clock generation (20ns = 50MHz) ---
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # --- Initialize ---
    dut.rst_n.value = 0
    dut.ena.value = 1   # Always enabled for JTAG TAP
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Reset sequence
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut._log.info("Reset deasserted, starting test sequence")

    # --- Apply JTAG TAP sequence for IR update ---
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

    # Idle
    for _ in range(5):
        await jtag_cycle(dut, 0, 0)

    # --- DR shifting sequence (bypass/idcode) ---
    await jtag_cycle(dut, 1, 0)  # select_dr_scan
    await jtag_cycle(dut, 0, 0)  # capture_dr
    await jtag_cycle(dut, 0, 1)  # shift_dr - '1'
    await jtag_cycle(dut, 0, 0)  # shift_dr - '0'
    await jtag_cycle(dut, 0, 1)  # shift_dr - '1'
    await jtag_cycle(dut, 1, 0)  # exit_1_dr
    await jtag_cycle(dut, 0, 0)  # pause_dr
    await jtag_cycle(dut, 1, 0)  # exit_2_dr
    await jtag_cycle(dut, 0, 0)  # update_dr

    # Idle
    for _ in range(5):
        await jtag_cycle(dut, 0, 0)

    # --- ✅ Add checks on outputs ---
    # Example: expecting bypass output = TDI shifted
    bypass_out = int(dut.uo_out.value)
    dut._log.info(f"Bypass output observed: {bypass_out}")

    # Replace 'expected_val' with what your design should produce
    expected_val = 1  # example check, update for your DUT
    assert bypass_out == expected_val, f"Bypass failed: expected {expected_val}, got {bypass_out}"

    dut._log.info("TEST COMPLETE ✅")
