`timescale 1ns / 1ps

module lia_postlayout_tb;

    // Clock and control
    reg clk;
    reg rst_n;

    // ADC interface
    reg signed [11:0] adc_data;
    reg adc_valid;

    // NCO control
    reg [31:0] phase_increment;

    // Mixer outputs
    wire signed [23:0] mixer_i_out;
    wire signed [23:0] mixer_q_out;
    wire mixer_valid;

    // Test parameters
    parameter CLK_PERIOD = 20;           // 50MHz clock
    parameter SIGNAL_FREQ = 10.0e3;      // 10kHz test signal
    parameter SIGNAL_AMP = 1000.0;       // ADC amplitude
    parameter NUM_SAMPLES = 500;         // Number of test samples

    // File and loop variables
    integer file_output;
    integer i;
    real time_sec;
    real adc_real;

    // Device Under Test (gate-level netlist)
    lia_digital_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .adc_data(adc_data),
        .adc_valid(adc_valid),
        .phase_increment(phase_increment),
        .mixer_i_out(mixer_i_out),
        .mixer_q_out(mixer_q_out),
        .mixer_valid(mixer_valid)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Calculate NCO phase increment for 10kHz
    initial begin
        phase_increment = 32'd858993459;  // Pre-calculated for 10kHz @ 50MHz
        $display("========================================");
        $display("Post-Layout Simulation Starting");
        $display("  Clock: 50 MHz");
        $display("  Signal: 10 kHz");
        $display("  Samples: %0d", NUM_SAMPLES);
        $display("========================================");
    end

    // Main test sequence
    initial begin
        // Initialize all signals
        rst_n = 0;
        adc_data = 0;
        adc_valid = 0;

        // Open output file
        file_output = $fopen("postlayout_iq_data.txt", "w");
        if (file_output == 0) begin
            $display("ERROR: Could not open output file!");
            $finish;
        end

        // Apply reset
        #100;
        @(posedge clk);
        #1;
        rst_n = 1;

        // Wait for pipeline to fill
        repeat(10) @(posedge clk);

        $display("Starting signal generation...");

        // Generate test signal
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(posedge clk);
            #1;  // Small delay after clock edge

            // Calculate time
            time_sec = $itor(i) * CLK_PERIOD / 1.0e9;

            // Generate sine wave input
            adc_real = SIGNAL_AMP * $sin(2.0 * 3.141592653589793 * SIGNAL_FREQ * time_sec);
            adc_data = $rtoi(adc_real);

            // Clip to 12-bit signed range
            if (adc_data > 2047) adc_data = 2047;
            if (adc_data < -2048) adc_data = -2048;

            adc_valid = 1'b1;

            // Write output data when valid
            if (mixer_valid) begin
                $fwrite(file_output, "%d %d\n", mixer_i_out, mixer_q_out);
            end

            // Progress display
            if (i % 100 == 0) begin
                $display("[%0t ns] Sample %3d: ADC=%5d, I=%8d, Q=%8d, Valid=%b",
                         $time, i, adc_data, mixer_i_out, mixer_q_out, mixer_valid);
            end
        end

        // Finish
        adc_valid = 1'b0;
        repeat(20) @(posedge clk);

        $fclose(file_output);

        $display("========================================");
        $display("Post-Layout Simulation Complete!");
        $display("Output saved to: postlayout_iq_data.txt");
        $display("========================================");

        $finish;
    end

    // Safety timeout
    initial begin
        #(CLK_PERIOD * (NUM_SAMPLES + 500));
        $display("ERROR: Simulation timeout!");
        $finish;
    end

    // Waveform dump (optional, makes large files)
    initial begin
        $dumpfile("postlayout_waves.vcd");
        $dumpvars(0, lia_postlayout_tb);
    end

endmodule
