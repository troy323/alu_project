`timescale 1ns / 1ps

module alu #(parameter data_width=8)(
  input [data_width-1:0] opa, opb,
  input cin, CLK, rst, ce, Mode,
  input [1:0] INP_valid,
  input [3:0] Cmd,
  output reg oflow, cout, g, l, e, err,
  output reg [2*data_width-1:0] res
);

  // mode=0
  localparam And=0, Nand=1, Or=2, Nor=3, Xor=4, Xnor=5, Not_a=6, Not_b=7;
  localparam shl_a=8, shl_b=9, shr_a=10, shr_b=11, rol_a=12, ror_a=13;
  // mode=1
  localparam add=0, sub=1, add_cin=2, sub_cin=3, inc_a=4, dec_a=5, inc_b=6, dec_b=7;
  localparam cmp=8, incr_mult=9, shift_mult=10, signed_add=11, signed_sub=12;

  reg [1:0] cnt;
  reg t_cout, t_oflow, t_l, t_e, t_g, t_err;
  reg [1:0] inp_valid;
  reg [data_width-1:0] s_opa, s_opb;
  reg [data_width-1:0] t_res;
  reg [2*data_width-1:0] b_res, process_r;
  
  wire [data_width-1:0] inc_opa = s_opa + 1'b1;
  wire [data_width-1:0] inc_opb = s_opb + 1'b1;
  wire [data_width-1:0] shl_opa = s_opa << 1;

  function [data_width-1:0] rotate_left(input [data_width-1:0] val, input [2:0] amt);
    begin rotate_left = (val << amt) | (val >> (data_width - amt)); end
  endfunction

  function [data_width-1:0] rotate_right(input [data_width-1:0] val, input [2:0] amt);
    begin rotate_right = (val >> amt) | (val << (data_width - amt)); end
  endfunction


  always@(posedge CLK or posedge rst) begin
    if(rst) begin
      s_opa <= 0; s_opb <= 0; inp_valid <= 0;
    end
    else if(ce) begin
      if(cnt != 1) begin   
        s_opa <= opa; s_opb <= opb; inp_valid <= INP_valid;
      end
    end
  end

  // Pipeline Controller
  always @(posedge CLK or posedge rst) begin
    if (rst) begin
      {oflow, cout, g, l, e, err} <= 0;
      res <= 0;
      cnt <= 0;
    end 
    else if (ce) begin 
      if (Mode == 1 && (Cmd == incr_mult || Cmd == shift_mult)) begin
        if (cnt == 2) begin
          res   <= process_r;
          err   <= t_err;
          oflow <= t_oflow; cout <= t_cout; g <= t_g; l <= t_l; e <= t_e;
          cnt   <= 0;      
        end else begin
          cnt <= cnt + 1;
        end
      end 
      else begin
        res   <= Mode ? b_res : {{data_width{1'b0}}, t_res};
        cnt   <= 0;
        oflow <= t_oflow; cout<= t_cout; g <= t_g; l <= t_l; e <= t_e; err<= t_err;
      end
    end
  end

  // Combinational Logic Block
  always@(*) begin

    t_res = 0; b_res = 0; t_err = 0; t_oflow = 0; t_cout = 0;
    t_g = 0; t_l = 0; t_e = 0; process_r = 0;

    if(!Mode) begin
      case(Cmd)
        And:   begin if(inp_valid!=3) t_err=1; else t_res=s_opa&s_opb; end
        Nand:  begin if(inp_valid!=3) t_err=1; else t_res=~(s_opa&s_opb); end
        Or:    begin if(inp_valid!=3) t_err=1; else t_res=s_opa|s_opb; end
        Nor:   begin if(inp_valid!=3) t_err=1; else t_res=~(s_opa|s_opb); end
        Xor:   begin if(inp_valid!=3) t_err=1; else t_res=s_opa^s_opb; end
        Xnor:  begin if(inp_valid!=3) t_err=1; else t_res=~(s_opa^s_opb); end
     
        Not_a: begin if(inp_valid!=1 && inp_valid!=3) t_err=1; else t_res=~s_opa; end
        Not_b: begin if(inp_valid!=2 && inp_valid!=3) t_err=1; else t_res=~s_opb; end
        shr_a: begin if(inp_valid!=1 && inp_valid!=3) t_err=1; else t_res=s_opa>>1; end
        shl_a: begin if(inp_valid!=1 && inp_valid!=3) t_err=1; else t_res=s_opa<<1; end
        shr_b: begin if(inp_valid!=2 && inp_valid!=3) t_err=1; else t_res=s_opb>>1; end
        shl_b: begin if(inp_valid!=2 && inp_valid!=3) t_err=1; else t_res=s_opb<<1; end
        
        rol_a: begin
          if(inp_valid!=3 || (|s_opb[data_width-1:3])) begin
            t_err=1; t_res=rotate_left(s_opa,s_opb[2:0]);
          end else t_res=rotate_left(s_opa,s_opb[2:0]);
        end
        ror_a: begin
          if(inp_valid!=3 || (|s_opb[data_width-1:3])) begin
            t_err=1; t_res=rotate_right(s_opa,s_opb[2:0]);
          end else t_res=rotate_right(s_opa,s_opb[2:0]);
        end
        default: t_err = 1; 
      endcase
    end
    else begin
      case(Cmd)
        add:     begin if(inp_valid!=3) t_err=1; else {t_cout, b_res}={1'b0,s_opa}+{1'b0, s_opb}; end
        sub:     begin if(inp_valid!=3) t_err=1; else begin b_res=s_opa-s_opb; t_oflow=(s_opa < s_opb); end end
        add_cin: begin if(inp_valid!=3) t_err=1; else {t_cout,b_res}= {1'b0,s_opa}+{1'b0,s_opb}+cin; end
        sub_cin: begin if(inp_valid!=3) t_err=1; else {t_oflow, b_res} = {1'b0, s_opa}-{1'b0, s_opb}-cin; end
        
        inc_a:   begin if(inp_valid!=1 && inp_valid!=3) t_err=1; else b_res=s_opa+1; end
        inc_b:   begin if(inp_valid!=2 && inp_valid!=3) t_err=1; else b_res=s_opb+1; end
        dec_a:   begin if(inp_valid!=1 && inp_valid!=3) t_err=1; else b_res=s_opa-1; end
        dec_b:   begin if(inp_valid!=2 && inp_valid!=3) t_err=1; else b_res=s_opb-1; end
        
        cmp: begin
          if(inp_valid==3) begin
            t_g=s_opa>s_opb; t_e=s_opa==s_opb; t_l=s_opa<s_opb;
          end else t_err=1;
        end
        signed_add: begin
          if(inp_valid!=3) t_err=1;
          else begin
            b_res=$signed(s_opa)+$signed(s_opb);
            t_oflow=(s_opa[data_width-1]==s_opb[data_width-1]) && (b_res[data_width-1]!=s_opa[data_width-1]);
          end
        end
        signed_sub: begin
          if(inp_valid!=3) t_err=1;
          else begin
            b_res = $signed(s_opa) - $signed(s_opb);
            t_oflow = (s_opa[data_width-1] != s_opb[data_width-1]) && (b_res[data_width-1] != s_opa[data_width-1]);
          end
        end
        incr_mult: begin
          if(inp_valid == 3) process_r = inc_opa * inc_opb;
          else t_err=1;
        end
        shift_mult: begin
          if(inp_valid == 3) process_r = shl_opa * s_opb;
          else t_err=1;
        end
        default: t_err = 1; 
      endcase
    end
  end
endmodule
