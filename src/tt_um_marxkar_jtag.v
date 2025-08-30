module tt_um_marxkar_jtag(
    input clk,                // TCLK
    input rst_n,              // Active-low reset (used as TRST)
    input ena,                // Always enabled
    input  [7:0] ui_in,       // Input pins: ui_in[0] = TDI, ui_in[1] = TMS, ui_in[2] = TRST
    output [7:0] uo_out,      // Output pins: uo_out[0] = TDO, uo_out[7:1] = debug.
    input  [7:0] uio_in,
    output [7:0] uio_out,
    output [7:0] uio_oe
);

    // Input mapping
    wire tdi = ui_in[0];
    wire tms = ui_in[1];
    wire trst = ~rst_n;  // since rst_n is active-low
    wire tclk = clk;

    wire _unused_ena     = ena;
    wire _unused_ui_in   = |ui_in[7:2];
    wire _unused_uio_in  = |uio_in;

    // Output mapping
    reg tdo;
    assign uo_out[0] = tdo;

    // FSM state variables
    reg [3:0] current_state, next_state;

    // Internal registers
    reg [1:0] instruction, shadow_instruction;
    reg [7:0] id_code = 8'b10101010;
    reg [7:0] shadow_id_code;
    reg bypass;
    reg [1:0] shadow_bsr;
    reg [3:0] bsr;
    wire bsr_wire;

    // Output debug (for optional observation)
    assign uo_out[1] = current_state[0];
    assign uo_out[2] = current_state[1];
    assign uo_out[3] = current_state[2];
    assign uo_out[4] = current_state[3];
    assign uo_out[5] = instruction[0];
    assign uo_out[6] = instruction[1];
    assign uo_out[7] = bypass;

    // Bidirectional pins unused
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // FSM state encoding
    localparam [3:0]
        test_logic_reset = 4'b0000,    
        run_idle_test    = 4'b0001,
        select_dr_scan   = 4'b0010,
        capture_dr       = 4'b0011,
        shift_dr         = 4'b0100,
        exit_1_dr        = 4'b0101,
        pause_dr         = 4'b0110,
        exit_2_dr        = 4'b0111,
        update_dr        = 4'b1000,
        select_ir_scan   = 4'b1001,
        capture_ir       = 4'b1010,
        shift_ir         = 4'b1011,
        exit_1_ir        = 4'b1100,
        pause_ir         = 4'b1101,
        exit_2_ir        = 4'b1110,
        update_ir        = 4'b1111;

    // FSM state transition
    always @(posedge tclk or posedge trst) begin
        if (trst)
            current_state <= test_logic_reset;
        else
            current_state <= next_state;
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            test_logic_reset : next_state = (tms) ? test_logic_reset : run_idle_test;
            run_idle_test    : next_state = (tms) ? select_dr_scan   : run_idle_test;
            select_dr_scan   : next_state = (tms) ? select_ir_scan   : capture_dr;
            capture_dr       : next_state = (tms) ? exit_1_dr        : shift_dr;
            shift_dr         : next_state = (tms) ? exit_1_dr        : shift_dr;
            exit_1_dr        : next_state = (tms) ? update_dr        : pause_dr;
            pause_dr         : next_state = (tms) ? exit_2_dr        : pause_dr;
            exit_2_dr        : next_state = (tms) ? update_dr        : shift_dr;
            update_dr        : next_state = (tms) ? select_dr_scan   : run_idle_test;
            select_ir_scan   : next_state = (tms) ? test_logic_reset : capture_ir;
            capture_ir       : next_state = (tms) ? exit_1_ir        : shift_ir;
            shift_ir         : next_state = (tms) ? exit_1_ir        : shift_ir;
            exit_1_ir        : next_state = (tms) ? update_ir        : pause_ir;
            pause_ir         : next_state = (tms) ? exit_2_ir        : pause_ir;
            exit_2_ir        : next_state = (tms) ? update_ir        : shift_ir;
            update_ir        : next_state = (tms) ? select_dr_scan   : run_idle_test;
            default: next_state = test_logic_reset;
        endcase
    end

    // Behavior logic on clock
    always @(posedge tclk or posedge trst) begin
        if (trst) begin
            tdo <= 0;
            bypass <= 0;
            shadow_bsr <= 0;
            shadow_instruction <= 0;
            shadow_id_code <= 0;
            bsr <= 0;
            instruction <= 0;
        end else begin
            bsr[0] <= bsr_wire; // replace bsr_wire logic with shifting dummy wire
            tdo <= 0;
            bypass <= bypass;
            shadow_bsr <= shadow_bsr;
            shadow_instruction <= shadow_instruction;
            shadow_id_code <= shadow_id_code;
            bsr[3:1] <= bsr[3:1];
            instruction <= instruction;
            case (next_state)
                test_logic_reset: begin
                    tdo <= 0;
                    bypass <= 0;
                    shadow_bsr <= 0;
                    shadow_instruction <= 0;
                    shadow_id_code <= 0;
                    bsr <= 0;
                    instruction <= 0;
                end

                run_idle_test: begin
                    if (instruction == 2'b10)
                        tdo <= bsr[0];
                end

                shift_dr, exit_1_dr: begin
                    case (instruction)
                        2'b11: begin tdo <= bypass; bypass <= tdi; end
                        2'b01: begin tdo <= shadow_id_code[0]; shadow_id_code <= {tdi, shadow_id_code[7:1]}; end
                        2'b10: begin shadow_bsr <= {tdi, shadow_bsr[1]}; end
                        default: begin end
                    endcase
                end

                capture_ir: begin
                    shadow_instruction <= instruction;
                end

                shift_ir, exit_1_ir: begin
                    shadow_instruction <= {tdi, shadow_instruction[1]};
                    tdo <= shadow_instruction[0];
                end

                update_ir: begin
                    instruction <= shadow_instruction;
                end

                capture_dr: begin
                    if (instruction == 2'b01)
                        shadow_id_code <= id_code;
                    else if (instruction == 2'b10)
                        shadow_bsr <= bsr[3:2];
                end

                update_dr: begin
                    if (instruction == 2'b10)
                        bsr[3:2] <= shadow_bsr;
                    else if (instruction == 2'b11)
                        tdo <= 0;
                end

                pause_dr : begin
                    if (instruction == 2'b11) 
                        tdo <= 0;
                end

                default : begin
                end
            endcase
        end
    end


d_flip_flop f1 (bsr[3], bsr[2], trst, bsr_wire);
endmodule
