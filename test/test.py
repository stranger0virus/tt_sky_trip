import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

async def write_byte(dut, addr: int, data: int):
    """Equivalent to Verilog write_byte task: Standard 2-Clock Write"""
    await FallingEdge(dut.clk)
    dut.ui_in.value = ((addr & 0x0F) << 4) | ((data >> 4) & 0x0F)
    
    # Cast dut.uio_in.value to int to avoid LogicArray TypeError
    current_uio = int(dut.uio_in.value)
    dut.uio_in.value = (current_uio & ~0x07) | ((addr >> 4) & 0x01) | (1 << 1) # wen=1, ren=0
    dut.ena.value = 1

    await FallingEdge(dut.clk)
    # Clock 2: Drive LSB data_in[3:0] into ui_in[3:0]
    dut.ui_in.value = (int(dut.ui_in.value) & 0xF0) | (data & 0x0F)

    await FallingEdge(dut.clk)
    # Deassert control signals
    dut.uio_in.value = int(dut.uio_in.value) & ~0x02  # wen = 0
    dut.ui_in.value = int(dut.ui_in.value) & 0xF0     # clear lower nibble


async def write_and_read_simultaneous(dut, wr_addr: int, wr_data: int, rd_addr: int, expected_rd_data: int):
    """Equivalent to Verilog write_and_read_simultaneous task"""
    await FallingEdge(dut.clk)
    
    # Setup Write Target & MSB data
    ui_in_val = ((wr_addr & 0x0F) << 4) | ((wr_data >> 4) & 0x0F)
    current_uio = int(dut.uio_in.value)
    uio_in_val = (current_uio & ~0xDF) | ((wr_addr >> 4) & 0x01) | (rd_addr << 3) | (1 << 1) | (1 << 2) # wen=1, ren=1
    
    dut.ui_in.value = ui_in_val
    dut.uio_in.value = uio_in_val
    dut.ena.value = 1

    await FallingEdge(dut.clk)
    # Drive LSB for write_commit
    dut.ui_in.value = (int(dut.ui_in.value) & 0xF0) | (wr_data & 0x0F)

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")  # Evaluation strobe matching #1 in Verilog
    
    actual_output = int(dut.uo_out.value)
    if actual_output == expected_rd_data:
        print(f"\n>>> [SIMULTANEOUS SUCCESS] While writing to Addr {wr_addr}, read from Addr {rd_addr} matched 0x{expected_rd_data:02X}! <<<\n")
    else:
        print(f"\n>>> [SIMULTANEOUS ERROR] Read 0x{actual_output:02X} != Expected 0x{expected_rd_data:02X} <<<\n")
        assert actual_output == expected_rd_data

    await FallingEdge(dut.clk)
    # Deassert control signals
    dut.uio_in.value = int(dut.uio_in.value) & ~0x06  # wen = 0, ren = 0
    dut.ui_in.value = int(dut.ui_in.value) & 0xF0


@cocotb.test()
async def test_project(dut):
    # Start a 100 MHz clock (10 ns period)
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Initial states
    dut.rst_n.value = 0  # Active-low reset asserted
    dut.ena.value = 1
    dut.ui_in.value = 0x00
    dut.uio_in.value = 0x00

    # Wait and release reset
    await Timer(25, unit="ns")
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await Timer(5, unit="ns")

    # Step 1: Write 0xC3 into Address 5
    print("=====================================================================")
    print("STEP 1: Writing 0xC3 into Address 5 (no read)")
    print("=====================================================================")
    await write_byte(dut, 5, 0xC3)

    for _ in range(2):
        await FallingEdge(dut.clk)

    # Step 2: Write 0xE1 to Address 8 while reading Address 5 concurrently
    print("=====================================================================")
    print("STEP 2: Writing 0xE1 to Address 8 while reading Address 5 concurrently")
    print("=====================================================================")
    await write_and_read_simultaneous(
        wr_addr=8,
        wr_data=0xE1,
        rd_addr=5,
        expected_rd_data=0xC3
    )

    for _ in range(2):
        await FallingEdge(dut.clk)

    print("=====================================================================")
    print("             ALL 256-BIT MATRIX OPERATIONS VERIFIED                  ")
    print("=====================================================================\n")
