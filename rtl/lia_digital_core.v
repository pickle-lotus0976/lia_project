// TOP-LEVEL MODULE
module lia_digital_core (
    // Clock and Reset
    clk,
    rst_n,

    // ADC Interface
    adc_data,
    adc_valid,

    // NCO Control
    phase_increment,

    // Mixer Outputs (I/Q channels)
    mixer_i_out,
    mixer_q_out,
    mixer_valid
);

  // Parameters
  parameter integer DATA_WIDTH = 12;
  parameter integer NCO_WIDTH = 12;
  parameter integer MIXER_WIDTH = 24;
  parameter integer PHASE_WIDTH = 32;
  parameter integer LUT_DEPTH = 256;
  parameter integer LUT_ADDR_WIDTH = 8;

  input clk;
  input rst_n;
  input signed [DATA_WIDTH-1:0] adc_data;
  input adc_valid;
  input [PHASE_WIDTH-1:0] phase_increment;
  output signed [MIXER_WIDTH-1:0] mixer_i_out;
  output signed [MIXER_WIDTH-1:0] mixer_q_out;
  output mixer_valid;

  wire signed [NCO_WIDTH-1:0] nco_sin;
  wire signed [NCO_WIDTH-1:0] nco_cos;
  wire nco_valid;

  // NCO Instance
  nco_with_lut #(
      .PHASE_WIDTH(PHASE_WIDTH),
      .OUTPUT_WIDTH(NCO_WIDTH),
      .LUT_DEPTH(LUT_DEPTH),
      .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH)
  ) nco_inst (
      .clk(clk),
      .rst_n(rst_n),
      .enable(1'b1),
      .phase_increment(phase_increment),
      .sin_out(nco_sin),
      .cos_out(nco_cos),
      .valid(nco_valid)
  );

  // I-Channel Mixer
  lia_mixer #(
      .ADC_WIDTH(DATA_WIDTH),
      .NCO_WIDTH(NCO_WIDTH),
      .OUTPUT_WIDTH(MIXER_WIDTH)
  ) mixer_i (
      .clk(clk),
      .rst_n(rst_n),
      .adc_data(adc_data),
      .adc_valid(adc_valid),
      .nco_data(nco_sin),
      .nco_valid(nco_valid),
      .mixed_out(mixer_i_out),
      .valid(mixer_valid)
  );

  // Q-Channel Mixer
  lia_mixer #(
      .ADC_WIDTH(DATA_WIDTH),
      .NCO_WIDTH(NCO_WIDTH),
      .OUTPUT_WIDTH(MIXER_WIDTH)
  ) mixer_q (
      .clk(clk),
      .rst_n(rst_n),
      .adc_data(adc_data),
      .adc_valid(adc_valid),
      .nco_data(nco_cos),
      .nco_valid(nco_valid),
      .mixed_out(mixer_q_out),
      .valid()
  );

endmodule

// NCO WITH SINE LUT
module nco_with_lut (
    clk,
    rst_n,
    enable,
    phase_increment,
    sin_out,
    cos_out,
    valid
);
  parameter integer PHASE_WIDTH = 32;
  parameter integer OUTPUT_WIDTH = 12;
  parameter integer LUT_DEPTH = 256;
  parameter integer LUT_ADDR_WIDTH = 8;

  input clk;
  input rst_n;
  input enable;
  input [PHASE_WIDTH-1:0] phase_increment;
  output signed [OUTPUT_WIDTH-1:0] sin_out;
  output signed [OUTPUT_WIDTH-1:0] cos_out;
  output valid;

  reg [PHASE_WIDTH-1:0] phase_accum;
  reg valid_reg;

  wire [LUT_ADDR_WIDTH-1:0] lut_addr_sin;
  wire [LUT_ADDR_WIDTH-1:0] lut_addr_cos;

  // Phase Accumulator
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      phase_accum <= 32'd0;
    end else if (enable) begin
      phase_accum <= phase_accum + phase_increment;
    end
  end

  /* LUT Addressing.
 Take the top 8 bits of 32-bit phase accumulator */
  assign lut_addr_sin = phase_accum[PHASE_WIDTH-1:PHASE_WIDTH-LUT_ADDR_WIDTH];
  assign lut_addr_cos = lut_addr_sin + 8'd64; // Cosine = Sine with 90° phase shift (add 64 for 256-entry LUT)
  // Sine LUT
  sine_lut_rom #(
      .OUTPUT_WIDTH(OUTPUT_WIDTH),
      .LUT_DEPTH(LUT_DEPTH),
      .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH)
  ) sine_lut (
      .clk(clk),
      .rst_n(rst_n),
      .addr(lut_addr_sin),
      .data_out(sin_out)
  );

  // Cosine LUT
  sine_lut_rom #(
      .OUTPUT_WIDTH(OUTPUT_WIDTH),
      .LUT_DEPTH(LUT_DEPTH),
      .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH)
  ) cosine_lut (
      .clk(clk),
      .rst_n(rst_n),
      .addr(lut_addr_cos),
      .data_out(cos_out)
  );

  // Valid Signal (1 cycle delay for LUT ROM)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_reg <= 1'b0;
    end else begin
      valid_reg <= enable;
    end
  end

  assign valid = valid_reg;

endmodule

// SINE LUT ROM
module sine_lut_rom (
    clk,
    rst_n,
    addr,
    data_out
);

  parameter integer OUTPUT_WIDTH = 12;
  parameter integer LUT_DEPTH = 256;
  parameter integer LUT_ADDR_WIDTH = 8;

  input clk;
  input rst_n;
  input [LUT_ADDR_WIDTH-1:0] addr;
  output reg signed [OUTPUT_WIDTH-1:0] data_out;

  reg signed [OUTPUT_WIDTH-1:0] rom_data[0:LUT_DEPTH-1];

  initial begin
    $readmemh("sine_lut_rom_256b_12w.mem", rom_data);
  end

  // Synchronous ROM read
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out <= 12'd0;
    end else begin
      data_out <= rom_data[addr];
    end
  end

endmodule

// MIXER MODULE
module lia_mixer (
    clk,
    rst_n,
    adc_data,
    adc_valid,
    nco_data,
    nco_valid,
    mixed_out,
    valid
);

  parameter integer ADC_WIDTH = 12;
  parameter integer NCO_WIDTH = 12;
  parameter integer OUTPUT_WIDTH = 24;

  input clk;
  input rst_n;
  input signed [ADC_WIDTH-1:0] adc_data;
  input adc_valid;
  input signed [NCO_WIDTH-1:0] nco_data;
  input nco_valid;
  output reg signed [OUTPUT_WIDTH-1:0] mixed_out;
  output reg valid;

  reg signed [ADC_WIDTH-1:0] adc_reg;
  reg signed [NCO_WIDTH-1:0] nco_reg;
  reg valid_stage1;

  reg signed [OUTPUT_WIDTH-1:0] product;
  reg valid_stage2;

  // Pipeline Stage 1: Input Registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      adc_reg <= 12'd0;
      nco_reg <= 12'd0;
      valid_stage1 <= 1'b0;
    end else begin
      adc_reg <= adc_data;
      nco_reg <= nco_data;
      valid_stage1 <= adc_valid && nco_valid;
    end
  end

  // Pipeline Stage 2: Multiplication
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      product <= 24'd0;
      valid_stage2 <= 1'b0;
    end else begin
      product <= adc_reg * nco_reg;
      valid_stage2 <= valid_stage1;
    end
  end

  reg signed [OUTPUT_WIDTH-1:0] product_delayed;
  reg valid_stage2_buff;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      product_delayed   <= 24'd0;
      valid_stage2_buff <= 1'b0;
    end else begin
      product_delayed   <= product;
      valid_stage2_buff <= valid_stage2;
    end
  end

  // Pipeline Stage 3: Output Register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mixed_out <= 24'd0;
      valid <= 1'b0;
    end else begin
      mixed_out <= product_delayed;
      valid <= valid_stage2_delayed;
    end
  end

endmodule  // lia_mixer
