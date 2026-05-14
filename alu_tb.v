`timescale 1ns / 1ps

module tb_alu();

  // --- Parameters ---
  parameter data_width = 8;

  // --- Signals ---
  logic [data_width-1:0] opa, opb;
  logic cin, CLK, rst, ce, Mode;
  logic [1:0] INP_valid;
  logic [3:0] Cmd;

  logic oflow, cout, g, l, e, err;
  logic [2*data_width-1:0] res;

  // --- Instantiate DUT ---
  alu #(
    .data_width(data_width)
  ) dut (
    .opa(opa),
    .opb(opb),
    .cin(cin),
    .CLK(CLK),
    .rst(rst),
    .ce(ce),
    .Mode(Mode),
    .INP_valid(INP_valid),
    .Cmd(Cmd),
    .oflow(oflow),
    .cout(cout),
    .g(g),
    .l(l),
    .e(e),
    .err(err),
    .res(res)
  );

  initial begin
    CLK = 0;
    forever #5 CLK = ~CLK; 
  end

  logic [2*data_width-1:0] exp_res;
  logic exp_oflow, exp_cout, exp_g, exp_l, exp_e, exp_err;

  int error_count = 0;
  int test_count = 0;

 
  task compute_expected(
    input logic Mode_i, 
    input logic [3:0] Cmd_i, 
    input logic [1:0] INP_valid_i, 
    input logic [data_width-1:0] a, 
    input logic [data_width-1:0] b, 
    input logic cin_i
  );
    logic [data_width-1:0] t_res;
    logic [2*data_width-1:0] b_res, process_r;
    logic [data_width-1:0] inc_opa, inc_opb, shl_opa;

    exp_err = 0; exp_oflow = 0; exp_cout = 0; 
    exp_g = 0; exp_l = 0; exp_e = 0;
    t_res = 0; b_res = 0; process_r = 0; exp_res = 0;

    inc_opa = a + 1'b1;
    inc_opb = b + 1'b1;
    shl_opa = a << 1;

    if (!Mode_i) begin 
      case (Cmd_i)
        0:  begin if(INP_valid_i!=3) exp_err=1; else t_res = a & b; end
        1:  begin if(INP_valid_i!=3) exp_err=1; else t_res = ~(a & b); end
        2:  begin if(INP_valid_i!=3) exp_err=1; else t_res = a | b; end
        3:  begin if(INP_valid_i!=3) exp_err=1; else t_res = ~(a | b); end
        4:  begin if(INP_valid_i!=3) exp_err=1; else t_res = a ^ b; end
        5:  begin if(INP_valid_i!=3) exp_err=1; else t_res = ~(a ^ b); end
        // Allow valid=11 for single operands
        6:  begin if(INP_valid_i!=1 && INP_valid_i!=3) exp_err=1; else t_res = ~a; end
        7:  begin if(INP_valid_i!=2 && INP_valid_i!=3) exp_err=1; else t_res = ~b; end
        8:  begin if(INP_valid_i!=1 && INP_valid_i!=3) exp_err=1; else t_res = a << 1; end
        9:  begin if(INP_valid_i!=2 && INP_valid_i!=3) exp_err=1; else t_res = b << 1; end
        10: begin if(INP_valid_i!=1 && INP_valid_i!=3) exp_err=1; else t_res = a >> 1; end
        11: begin if(INP_valid_i!=2 && INP_valid_i!=3) exp_err=1; else t_res = b >> 1; end
        12: begin
          if(INP_valid_i!=3 || (|b[data_width-1:3])) begin
            exp_err=1; t_res = (a << b[2:0]) | (a >> (data_width - b[2:0]));
          end else t_res = (a << b[2:0]) | (a >> (data_width - b[2:0]));
        end
        13: begin
          if(INP_valid_i!=3 || (|b[data_width-1:3])) begin
            exp_err=1; t_res = (a >> b[2:0]) | (a << (data_width - b[2:0]));
          end else t_res = (a >> b[2:0]) | (a << (data_width - b[2:0]));
        end
        default: exp_err=1; // Catch invalid commands
      endcase
      exp_res = {{data_width{1'b0}}, t_res};
    end 
    else begin // Arithmetic Operations (Mode = 1)
      case (Cmd_i)
        0:  begin if(INP_valid_i!=3) exp_err=1; else {exp_cout, b_res} = {1'b0, a} + {1'b0, b}; end
        1:  begin if(INP_valid_i!=3) exp_err=1; else begin b_res = a - b; exp_oflow = (a < b); end end
        2:  begin if(INP_valid_i!=3) exp_err=1; else {exp_cout, b_res} = {1'b0, a} + {1'b0, b} + cin_i; end
        3:  begin if(INP_valid_i!=3) exp_err=1; else {exp_oflow, b_res} = {1'b0, a} - {1'b0, b} - cin_i; end
        // Allow valid=11 for single operands
        4:  begin if(INP_valid_i!=1 && INP_valid_i!=3) exp_err=1; else b_res = a + 1; end
        5:  begin if(INP_valid_i!=1 && INP_valid_i!=3) exp_err=1; else b_res = a - 1; end
        6:  begin if(INP_valid_i!=2 && INP_valid_i!=3) exp_err=1; else b_res = b + 1; end
        7:  begin if(INP_valid_i!=2 && INP_valid_i!=3) exp_err=1; else b_res = b - 1; end
        8:  begin if(INP_valid_i==3) begin exp_g = a > b; exp_e = a == b; exp_l = a < b; end else exp_err=1; end
        11: begin 
          if(INP_valid_i!=3) exp_err=1;
          else begin
            b_res = $signed(a) + $signed(b);
            exp_oflow = (a[data_width-1] == b[data_width-1]) && (b_res[data_width-1] != a[data_width-1]);
          end
        end
        12: begin 
          if(INP_valid_i!=3) exp_err=1;
          else begin
            b_res = $signed(a) - $signed(b);
            exp_oflow = (a[data_width-1] != b[data_width-1]) && (b_res[data_width-1] != a[data_width-1]);
          end
        end
        9:  begin if(INP_valid_i==3) process_r = inc_opa * inc_opb; else exp_err=1; end
        10: begin if(INP_valid_i==3) process_r = shl_opa * b; else exp_err=1; end
        default: exp_err=1; // Catch invalid commands
      endcase
      
      if (Cmd_i == 9 || Cmd_i == 10) exp_res = process_r;
      else exp_res = b_res;
    end
  endtask

  // --- Output Checking Task ---
  task check_outputs(input string name);
    test_count++;
    if (res !== exp_res || err !== exp_err || oflow !== exp_oflow || 
        cout !== exp_cout || g !== exp_g || l !== exp_l || e !== exp_e) begin
      $display("[FAIL] %s", name);
      $display("  [EXP] res=%0h, err=%b, oflow=%b, cout=%b, g=%b, l=%b, e=%b", exp_res, exp_err, exp_oflow, exp_cout, exp_g, exp_l, exp_e);
      $display("  [ACT] res=%0h, err=%b, oflow=%b, cout=%b, g=%b, l=%b, e=%b", res, err, oflow, cout, g, l, e);
      error_count++;
    end else begin
      $display("[PASS] %s", name);
    end
  endtask

  // --- Dynamic Stimulus Task ---
  task do_op(
    input string name, input logic m, input logic [3:0] c, input logic [1:0] v, 
    input logic [7:0] a, input logic [7:0] b, input logic ci
  );
    @(negedge CLK);
    Mode = m; Cmd = c; INP_valid = v; opa = a; opb = b; cin = ci; ce = 1;
    compute_expected(m, c, v, a, b, ci);

    if (m == 1 && (c == 9 || c == 10)) repeat(3) @(posedge CLK);
    else repeat(2) @(posedge CLK);

    @(negedge CLK);
    check_outputs(name);
    
    // Freeze pipeline during idle time between tests
    ce = 0; 
  endtask

  // --- Mid-Op Changes Task (Tests 38-41, 45-48) ---
  task test_mid_op_change(input string name, input logic [3:0] init_cmd, input int test_type);
    // test_type: 1=Mode, 2=Cmd, 3=Operand, 4=CE Deassert
    @(negedge CLK);
    Mode = 1; Cmd = init_cmd; INP_valid = 2'b11; opa = 8'h02; opb = 8'h03; ce = 1;
    compute_expected(1, init_cmd, 2'b11, 8'h02, 8'h03, 0);

    @(posedge CLK); // Cycle 1 (Inputs registered)
    @(negedge CLK); 

   
    if (test_type == 1) begin Mode = 0; compute_expected(0, init_cmd, 2'b11, 8'h02, 8'h03, 0); end
    if (test_type == 2) begin Cmd = 4;  compute_expected(1, 4, 2'b11, 8'h02, 8'h03, 0); end
    if (test_type == 3) begin opa=8'hFF; opb=8'hFF; end 
    if (test_type == 4) ce = 0;               

    if (test_type == 4) begin
      repeat(3) @(posedge CLK); // Pipeline frozen
      @(negedge CLK); ce = 1;   // Resume
      repeat(2) @(posedge CLK); // Finish cycles
    end else begin
      repeat(2) @(posedge CLK); 
    end

    @(negedge CLK);
    check_outputs(name);
    
    // Freeze pipeline during idle time between tests
    ce = 0; 
  endtask

  // --- Execution Block ---
  initial begin
    $display("==================================================");
    $display("STARTING ALU TEST MATRIX VERIFICATION");
    $display("==================================================");
    
    // TC 2: Reset assert/deassert asynchronously
    rst = 1; opa = 0; opb = 0; cin = 0; ce = 0; Mode = 0; INP_valid = 0; Cmd = 0;
    repeat(2) @(posedge CLK);
    rst = 0;
    @(posedge CLK);

    // --------------------------------------------------------
    // GENERAL & CONFIGURATION (TC 3 - TC 13)
    // --------------------------------------------------------
    // Note: TC 3 & 4 (CE assert/deassert) are inherently tested in test_mid_op_change
    // Note: TC 5 & 6 (Mode=1 / Mode=0) are tested throughout via do_op calls
    do_op("TC_07_invalid_cmd_mode1",        1, 15, 2'b11, 8'h00, 8'h00, 0); 
    do_op("TC_08_invalid_cmd_mode0",        0, 15, 2'b11, 8'h00, 8'h00, 0); 
    do_op("TC_09_inp_valid_00",             1, 0,  2'b00, 8'h10, 8'h10, 0);
    do_op("TC_10_inp_valid_01_2op",         1, 0,  2'b01, 8'h10, 8'h10, 0);
    do_op("TC_11_inp_valid_10_2op",         1, 0,  2'b10, 8'h10, 8'h10, 0);
    do_op("TC_12_inp_valid_single_operand", 1, 4,  2'b01, 8'h10, 8'h10, 0);
    do_op("TC_13_inp_valid_11",             1, 0,  2'b11, 8'h10, 8'h10, 0);

    // --------------------------------------------------------
    // ARITHMETIC OPERATIONS (TC 14 - TC 55)
    // --------------------------------------------------------
    do_op("TC_14_add_random",               1, 0,  2'b11, 8'h12, 8'h34, 0);
    do_op("TC_15_add_invalid_inp",          1, 0,  2'b01, 8'h12, 8'h34, 0);
    do_op("TC_16_add_with_cout",            1, 0,  2'b11, 8'hFF, 8'h01, 0);
    do_op("TC_17_sub_random",               1, 1,  2'b11, 8'h50, 8'h20, 0);
    do_op("TC_18_sub_invalid_inp",          1, 1,  2'b10, 8'h50, 8'h20, 0);
    do_op("TC_19_sub_with_borrow",          1, 1,  2'b11, 8'h00, 8'h01, 0);
    do_op("TC_20_add_cin_invalid",          1, 2,  2'b00, 8'h10, 8'h10, 1);
    do_op("TC_21_add_with_cin_1",           1, 2,  2'b11, 8'hFE, 8'h01, 1);
    do_op("TC_22_add_with_cin_0",           1, 2,  2'b11, 8'hFF, 8'h00, 0);
    do_op("TC_23_sub_cin_invalid",          1, 3,  2'b01, 8'h10, 8'h10, 1);
    do_op("TC_24_sub_with_cin_1_no_of",     1, 3,  2'b11, 8'hFF, 8'h00, 1);
    do_op("TC_25_sub_with_cin_1_oflow",     1, 3,  2'b11, 8'h00, 8'h00, 1);
    do_op("TC_26_increment_a_invalid",      1, 4,  2'b10, 8'h55, 8'h00, 0);
    do_op("TC_27_increment_a",              1, 4,  2'b01, 8'h55, 8'h00, 0);
    do_op("TC_28_decrement_a_invalid",      1, 5,  2'b10, 8'h55, 8'h00, 0);
    do_op("TC_29_decrement_a",              1, 5,  2'b01, 8'h55, 8'h00, 0);
    do_op("TC_30_increment_b_invalid",      1, 6,  2'b01, 8'h00, 8'hAA, 0);
    do_op("TC_31_increment_b",              1, 6,  2'b10, 8'h00, 8'hAA, 0);
    do_op("TC_32_decrement_b_invalid",      1, 7,  2'b01, 8'h00, 8'hAA, 0);
    do_op("TC_33_decrement_b",              1, 7,  2'b10, 8'h00, 8'hAA, 0);
    do_op("TC_34_comparator_invalid",       1, 8,  2'b01, 8'h10, 8'h10, 0);
    do_op("TC_35_comparator_valid",         1, 8,  2'b11, 8'h10, 8'h05, 0);
    
    // INC_AND_MUL
    do_op("TC_36_inc_mul_basic",            1, 9,  2'b11, 8'h02, 8'h03, 0);
    do_op("TC_37_inc_mul_invalid",          1, 9,  2'b01, 8'h02, 8'h03, 0);
    test_mid_op_change("TC_38_inc_mul_mode_chg", 9, 1);
    test_mid_op_change("TC_39_inc_mul_cmd_chg",  9, 2);
    test_mid_op_change("TC_40_inc_mul_op_chg",   9, 3);
    test_mid_op_change("TC_41_inc_mul_ce_toggle",9, 4);
    do_op("TC_42_inc_mul_corner_case",      1, 9,  2'b11, 8'hFF, 8'hFF, 0);
    
    // SHIFT_AND_MUL
    do_op("TC_43_shift_mul_basic",          1, 10, 2'b11, 8'h02, 8'h03, 0);
    do_op("TC_44_shift_mul_invalid",        1, 10, 2'b10, 8'h02, 8'h03, 0);
    test_mid_op_change("TC_45_shift_mul_mode_chg", 10, 1);
    test_mid_op_change("TC_46_shift_mul_cmd_chg",  10, 2);
    test_mid_op_change("TC_47_shift_mul_op_chg",   10, 3);
    test_mid_op_change("TC_48_shift_mul_ce_toggle",10, 4);
    do_op("TC_49_shift_mul_corner",         1, 10, 2'b11, 8'h80, 8'h02, 0); // 128 << 1 is 0 for 8-bit

    // SIGNED MATH
    do_op("TC_50_sadd_basic",               1, 11, 2'b11, 8'h05, 8'h02, 0);
    do_op("TC_51_sadd_overflow",            1, 11, 2'b11, 8'h7F, 8'h01, 0); // 127 + 1 = -128 (Overflow)
    do_op("TC_52_sadd_invalid",             1, 11, 2'b01, 8'h05, 8'h02, 0);
    do_op("TC_53_ssub_basic",               1, 12, 2'b11, 8'h05, 8'h02, 0);
    do_op("TC_54_ssub_overflow",            1, 12, 2'b11, 8'h80, 8'h01, 0); // -128 - 1 = 127 (Overflow)
    do_op("TC_55_ssub_invalid",             1, 12, 2'b10, 8'h05, 8'h02, 0);

    // --------------------------------------------------------
    // LOGICAL OPERATIONS (TC 56 - TC 83)
    // --------------------------------------------------------
    do_op("TC_56_nand_basic",               0, 1,  2'b11, 8'hA5, 8'h5A, 0);
    do_op("TC_57_nand_invalid",             0, 1,  2'b01, 8'hA5, 8'h5A, 0);
    do_op("TC_58_or_basic",                 0, 2,  2'b11, 8'hA5, 8'h5A, 0);
    do_op("TC_59_or_invalid",               0, 2,  2'b10, 8'hA5, 8'h5A, 0);
    do_op("TC_60_nor_basic",                0, 3,  2'b11, 8'hA5, 8'h5A, 0);
    do_op("TC_61_nor_invalid",              0, 3,  2'b00, 8'hA5, 8'h5A, 0);
    do_op("TC_62_xor_basic",                0, 4,  2'b11, 8'hA5, 8'h5A, 0);
    do_op("TC_63_xor_invalid",              0, 4,  2'b01, 8'hA5, 8'h5A, 0);
    do_op("TC_64_xnor_basic",               0, 5,  2'b11, 8'hA5, 8'h5A, 0);
    do_op("TC_65_xnor_invalid",             0, 5,  2'b10, 8'hA5, 8'h5A, 0);
    
    // NOT
    do_op("TC_66_not_a_basic",              0, 6,  2'b01, 8'hF0, 8'h00, 0);
    do_op("TC_67_not_a_invalid",            0, 6,  2'b10, 8'hF0, 8'h00, 0);
    do_op("TC_68_not_b_basic",              0, 7,  2'b10, 8'h00, 8'h0F, 0);
    do_op("TC_69_not_b_invalid",            0, 7,  2'b01, 8'h00, 8'h0F, 0);
    
    // SHIFT LOGICAL
    // Note: Parameter mapping check (8 = shl_a, 9 = shl_b, 10 = shr_a, 11 = shr_b based on user's DUT mapping)
    do_op("TC_70_shr_a_basic",              0, 10, 2'b01, 8'h81, 8'h00, 0);
    do_op("TC_71_shr_a_invalid",            0, 10, 2'b10, 8'h81, 8'h00, 0);
    do_op("TC_72_shl_a_basic",              0, 8,  2'b01, 8'h81, 8'h00, 0);
    do_op("TC_73_shl_a_invalid",            0, 8,  2'b10, 8'h81, 8'h00, 0);
    do_op("TC_74_shr_b_basic",              0, 11, 2'b10, 8'h00, 8'h81, 0);
    do_op("TC_75_shr_b_invalid",            0, 11, 2'b01, 8'h00, 8'h81, 0);
    do_op("TC_76_shl_b_basic",              0, 9,  2'b10, 8'h00, 8'h81, 0);
    do_op("TC_77_shl_b_invalid",            0, 9,  2'b01, 8'h00, 8'h81, 0);
    
    // ROTATE 
    do_op("TC_78_rol_a_valid",              0, 12, 2'b11, 8'h81, 8'h01, 0);
    do_op("TC_79_rol_a_invalid_validity",   0, 12, 2'b01, 8'h81, 8'h01, 0);
    do_op("TC_80_rol_a_err_gt_8",           0, 12, 2'b11, 8'h81, 8'h08, 0); // B >= 8 throws ERR
    do_op("TC_81_ror_a_valid",              0, 13, 2'b11, 8'h81, 8'h01, 0);
    do_op("TC_82_ror_a_invalid_validity",   0, 13, 2'b10, 8'h81, 8'h01, 0);
    do_op("TC_83_ror_a_err_gt_8",           0, 13, 2'b11, 8'h81, 8'h08, 0); // B >= 8 throws ERR

    $display("==================================================");
    $display("VERIFICATION COMPLETE");
    $display("Total Matrix Tests Attempted: %0d / 83", test_count);
    $display("Tests Failed:   %0d", error_count);
    if (error_count == 0) $display(">>> ALL TESTS PASSED <<<");
    else $display(">>> %0d TESTS FAILED - Check console for [FAIL] tags <<<", error_count);
    $display("==================================================");
    $finish;
  end

endmodule
