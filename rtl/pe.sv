`ifndef PE_V
`define PE_V

`timescale 1ns/1ps

module pe #(
  parameter  QI = 8,
  parameter  QF = 8,
  localparam DW = QI + QF
)(
  input  logic                 clk,
  input  logic                 rst,

  // north
  input  logic signed [DW-1:0] pe_psum_in,
  input  logic signed [DW-1:0] pe_weight_in,
  input  logic                 pe_accept_w_in,

  // west
  input  logic signed [DW-1:0] pe_input_in,
  input  logic                 pe_valid_in,
  input  logic                 pe_switch_in,
  input  logic                 pe_enabled,

  // south
  output logic signed [DW-1:0] pe_psum_out,
  output logic signed [DW-1:0] pe_weight_out,

  // east
  output logic signed [DW-1:0] pe_input_out,
  output logic                 pe_valid_out,
  output logic                 pe_switch_out
);

  // Weight storage

  logic signed [DW-1:0] weight_bg;
  logic signed [DW-1:0] weight_active;

  // MAC

  logic signed [DW-1:0] mult_out;
  logic signed [DW-1:0] mac_out;

  fxp_mul #(QI,QF) u_mul (pe_input_in, weight_active, mult_out, );
  fxp_add #(QI,QF) u_add (mult_out,    pe_psum_in,    mac_out,  );

  // TODO: weight promotion. Which register does the multiplier read?

  always_comb begin
    if(pe_switch_in) weight_active= weight_bg;
    else weight_active = pe_weight_out;
  end

  // TODO: weight staging. When does weight_bg capture pe_weight_in?

  always_ff @( posedge clk or posedge rst ) begin
    if ( rst )
      weight_bg <= 0;
    else if (pe_accept_w_in) weight_bg <= pe_weight_in;
      else weight_bg <= weight_bg;
  end

  // TODO: streaming datapath. Drive all five outputs.

  always_ff @( posedge clk or posedge rst ) begin
    if ( rst ) begin
      pe_psum_out   <= '0;
      pe_weight_out <= '0;
      pe_input_out  <= '0;
      pe_valid_out  <= 1'b0;
      pe_switch_out <= 1'b0;
    end
    else if ( !pe_enabled ) begin
        // hold all output regs

    end
    else if(!pe_valid_in) begin
      pe_valid_out <= 0;
      pe_weight_out <= weight_active;
      pe_switch_out <= pe_switch_in;
      

    end

    else begin
        pe_psum_out <= mac_out;
        pe_weight_out <= weight_active;
        pe_input_out <= pe_input_in;
        pe_valid_out <= pe_valid_in;
        pe_switch_out <= pe_switch_in;
    end
  end

endmodule

`endif
`ifndef FXP_V
`define FXP_V

`timescale 1ns/1ps
`default_nettype none

// Signed fixed-point add, Q(QI).(QF). Saturates.

module fxp_add #(
  parameter  QI = 8,
  parameter  QF = 8,
  localparam W  = QI + QF
)(
  input  wire signed [W-1:0] ina,
  input  wire signed [W-1:0] inb,
  output wire signed [W-1:0] out,
  output wire                overflow
);

  wire signed [W:0] sum = ina + inb;

  assign overflow = ( sum[W] != sum[W-1] );

  assign out = overflow ? ( sum[W] ? {1'b1, {(W-1){1'b0}}}
                                   : {1'b0, {(W-1){1'b1}}} )
                        : sum[W-1:0];

endmodule

// Signed fixed-point multiply, Q(QI).(QF). Truncates the low QF bits.

module fxp_mul #(
  parameter  QI = 8,
  parameter  QF = 8,
  localparam W  = QI + QF
)(
  input  wire signed [W-1:0] ina,
  input  wire signed [W-1:0] inb,
  output wire signed [W-1:0] out,
  output wire                overflow
);

  wire signed [2*W-1:0] prod = ina * inb;

  assign out = prod[W+QF-1 : QF];

  assign overflow = ~( (&prod[2*W-1 : W+QF-1]) | (~|prod[2*W-1 : W+QF-1]) );

endmodule

`default_nettype wire
`endif