// Code your design here
// Code your design here

module alu #(parameter data_width=8)(input [data_width-1:0]opa,opb,input cin,CLK,rst,ce,Mode,input [1:0]INP_valid,input [3:0]Cmd,output reg oflow,cout,g,l,e,err,output reg [2*data_width-1:0]res);
  // mode=0
 localparam And=0,Nand=1,Or=2,Nor=3,Xor=4,Xnor=5,Not_a=6,Not_b=7,shl_a=8,shl_b=9,shr_a=10,shr_b=11,rol_a=12,ror_a=13;
  // mode=1
 localparam add=0,sub=1,add_cin=2,sub_cin=3,inc_a=4,dec_a=5,inc_b=6,dec_b=7,cmp=8,incr_mult=9,shift_mult=10,signed_add=11,signed_sub=12;

  reg [1:0]cnt=0;
  reg t_cout;
  wire clk = ce & CLK;
  reg t_oflow,t_l,t_e,t_g;
  reg [1:0] inp_valid;
  reg [data_width-1:0]s_opa,s_opb;
  reg [data_width-1:0]t_res;
  reg [2*data_width-1:0]b_res;
  reg t_err;
  reg [2*data_width-1:0] process_r;  
  reg [2*data_width-1:0] final_r;  
  reg [data_width-1:0]inc_dec; 
  reg mode;
  reg [3:0]cmd;

  function [data_width-1:0] rotate_left;
    input [data_width-1:0] val;
    input [2:0]amt;
    begin
      rotate_left =(val<<amt)|(val >> (data_width - amt));
    end
  endfunction

  function [data_width-1:0] rotate_right;
    input [data_width-1:0] val;
    input [2:0] amt;
    begin
      rotate_right =(val>>amt)|(val<<(data_width - amt));
    end
  endfunction


  always@(*) begin
      process_r = 0;
        if(cmd == incr_mult) begin
         if(inp_valid == 3) process_r = (s_opa + 1)*(s_opb + 1);
         else t_err=1;
        end
        else if(cmd == shift_mult) begin
          if(inp_valid == 3) process_r =(s_opa << 1)* s_opb;
          else t_err=1;
        end
      end
   
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      {oflow,cout,g,l,e,err} <= 0;
      res<= 0;
      cnt<= 0;
      process_r<=0;
      b_res<=0;
      t_res<=0;
    end
    else begin 
    if(cmd == incr_mult || cmd == shift_mult) begin
        cnt<=cnt + 1;
        if(cnt == 2) begin
          res<= process_r;
          cnt<= 0;      
        end
      end
      else begin
      res<= mode?b_res:{{data_width{1'b0}}, t_res};
      cnt<= 0;
      oflow<= t_oflow;
      cout<= t_cout;
      g<=t_g;
      l<=t_l;
      e<=t_e;
      err<=t_err;
      cmd<=Cmd;
      mode<=Mode;
    end
    end
 
   end

  always@(posedge clk or posedge rst) begin
    if(cnt != 1 && !rst) begin   
      s_opa<=opa;
      s_opb<=opb;
      inp_valid<=INP_valid;
    end
  end


  always@(*) begin
    t_res=0;
    b_res=0;
    t_err=0;
    t_oflow=0;
    t_cout=0;
    t_g=0;
    t_l=0;
    t_e=0;

    if(!mode) begin
      case(cmd)
        And:begin
          if(inp_valid!=3) {t_res,t_err}=1;
          else t_res=s_opa&s_opb;
        end
        Nand:begin
          if(inp_valid!=3) {t_res,t_err}=1;
          else t_res=~(s_opa&s_opb);
        end
        Or:begin
          if(inp_valid!=3) {t_res,t_err}=1;
          else t_res=s_opa|s_opb;
        end
        Nor:begin
          if(inp_valid!=3) {t_res,t_err}=1;
          else t_res=~(s_opa|s_opb);
        end
        Xor:begin
          if(inp_valid!=3) {t_res,t_err}=1;
          else t_res=s_opa^s_opb;
        end
        Xnor:begin
          if(inp_valid!=3) {t_res,t_err}=1;
          else t_res=~(s_opa^s_opb);
        end
        Not_a:begin
          if(inp_valid!=1) {t_res,t_err}=1;
          else t_res=~(s_opa);
        end
        Not_b:begin
          if(inp_valid!=2) {t_res,t_err}=1;
          else t_res=~(s_opb);
        end
        shr_a:begin
          if(inp_valid!=1) {t_res,t_err}=1;
          else t_res=s_opa>>1;
        end
        shl_a:begin
          if(inp_valid!=1) {t_res,t_err}=1;
          else t_res=s_opa<<1;
        end
        shr_b:begin
          if(inp_valid!=2) {t_res,t_err}=1;
          else t_res=s_opb>>1;
        end
        shl_b:begin
          if(inp_valid!=2) {t_res,t_err}=1;
          else t_res=s_opb<<1;
        end
        rol_a:begin
          if(inp_valid!=3) begin
            t_err=1;
            t_res=0;
          end
          else if(s_opb[7] | s_opb[6] | s_opb[5] | s_opb[4]) begin
            t_err=1;
            t_res=rotate_left(s_opa,s_opb[2:0]);
          end
          else begin
            t_err=0;
            t_res=rotate_left(s_opa,s_opb[2:0]);
          end
        end
        ror_a:begin
          if(inp_valid!=3) begin
            t_err=1;
            t_res=0;
          end
          else if(s_opb[7] | s_opb[6] | s_opb[5] | s_opb[4]) begin
            t_err=1;
            t_res=rotate_right(s_opa,s_opb[2:0]);
          end
          else begin
            t_err=0;
            t_res=rotate_right(s_opa,s_opb[2:0]);
          end
        end
      endcase
    end
    else begin
      case(cmd)
        add: begin
          if(inp_valid!=3) begin
            t_err=1;
            b_res=0;
          end
          else begin
            {t_cout, b_res}={1'b0,s_opa}+{1'b0, s_opb};
          end
        end
        sub:begin
          if(inp_valid!=3) begin
            t_err=1;
            b_res=0;
          end
          else begin
            b_res=s_opa-s_opb;
            t_oflow=(s_opa < s_opb);
          end
        end
        add_cin:begin
          if(inp_valid!=3) begin
            t_err=1;
            b_res=0;
          end
          else begin
            {t_cout,b_res}= {1'b0,s_opa}+{1'b0,s_opb}+cin;
          end
        end
        sub_cin:begin
          if(inp_valid!=3) begin
            t_err=1;
            b_res=0;
          end
          else begin
            {t_oflow, b_res} = {1'b0, s_opa}-{1'b0, s_opb}-cin;
          end
        end
        inc_a:begin
          if(inp_valid!=1) begin
            t_err=1;
            b_res=0;
          end
          else begin
            inc_dec=s_opa+1;
            b_res=inc_dec;
            inc_dec=0;
          end
        end
        inc_b:begin
          if(inp_valid!=2) begin
            t_err=1;
            b_res=0;
          end
          else begin
           inc_dec=s_opb+1;
           b_res=inc_dec;
           inc_dec=0;
          end
        end
        dec_a:begin
          if(inp_valid!=1) begin
            t_err=1;
            b_res=0;
          end
          else begin
            inc_dec=s_opa-1;
            b_res=inc_dec;
            inc_dec=0;
          end
        end
        dec_b:begin
          if(inp_valid!=2) begin
            t_err=1;
            b_res=0;
          end
          else begin
            inc_dec=s_opb-1;
            b_res=inc_dec;
            inc_dec=0;
          end
        end
        cmp:begin
          if(inp_valid!=3) {t_g,t_e,t_l}=0; 
          else begin
            t_g=s_opa>s_opb;
            t_e=s_opa==s_opb;
            t_l=s_opa<s_opb;
          end
        end
        signed_add:begin
          if(inp_valid!=3) begin
            t_err=1;
            b_res=0;
            t_oflow=0;
          end
          else begin
            b_res=$signed(s_opa)+$signed(s_opb);
            t_oflow=(s_opa[data_width-1]==s_opb[data_width-1]) &&
                    (b_res[data_width-1]!=s_opa[data_width-1]);
          end
        end
        signed_sub: begin
          if(inp_valid != 3) begin
            t_err = 1;
            b_res = 0;
            t_oflow = 0;
          end
          else begin
            b_res = $signed(s_opa) - $signed(s_opb);
            t_oflow = (s_opa[data_width-1] != s_opb[data_width-1]) &&
                      (b_res[data_width-1] != s_opa[data_width-1]);
            t_err = 0;
          end
        end
      endcase
    end
  end

endmodule
