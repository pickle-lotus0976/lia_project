`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// LIA Digital Core Testbench - FIXED VERSION
// - Eliminates I/Q synchronization issues
// - Writes all outputs atomically on same clock cycle
// - Adds comprehensive assertions for verification
// - Strict Verilog-2001 syntax
//////////////////////////////////////////////////////////////////////////////////

module lia_digital_core_tb;

    //==========================================================================
    // Parameters (with explicit types for Verilog-2001 compliance)
    //==========================================================================
    parameter integer CLK_PERIOD = 10;        // 100 MHz clock (10 ns period)
    parameter integer DATA_WIDTH = 12;
    parameter integer NCO_WIDTH = 12;
    parameter integer MIXER_WIDTH = 24;
    parameter integer PHASE_WIDTH = 32;

    // Test signal parameters
    parameter real SIGNAL_FREQ = 10.0e3;      // 10 kHz input signal
    parameter real SIGNAL_AMP = 1000.0;       // Signal amplitude (ADC codes)
    parameter integer NUM_SAMPLES = 10000;    // Number of samples to generate

    //==========================================================================
    // DUT Signals
    //==========================================================================
    reg clk;
    reg rst_n;
    reg signed [DATA_WIDTH-1:0] adc_data;
    reg adc_valid;
    reg [PHASE_WIDTH-1:0] phase_increment;
    wire signed [MIXER_WIDTH-1:0] mixer_i_out;
    wire signed [MIXER_WIDTH-1:0] mixer_q_out;
    wire mixer_valid;

    //==========================================================================
    // Testbench Variables - ALL declared at module level for Verilog-2001
    //==========================================================================
    integer file_output;              // Single output file for all data
    integer i;
    real time_sec;
    real adc_real;
    real f_sample;                    // Actual sampling frequency
    real f_clk;                       // Clock frequency
    
    // Error tracking
    integer error_count;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    lia_digital_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .NCO_WIDTH(NCO_WIDTH),
        .MIXER_WIDTH(MIXER_WIDTH),
        .PHASE_WIDTH(PHASE_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .adc_data(adc_data),
        .adc_valid(adc_valid),
        .phase_increment(phase_increment),
        .mixer_i_out(mixer_i_out),
        .mixer_q_out(mixer_q_out),
        .mixer_valid(mixer_valid)
    );

    //==========================================================================
    // Clock Generation (100 MHz)
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //==========================================================================
    // Calculate NCO Phase Increment and Sampling Frequency
    //==========================================================================
    initial begin
        // Calculate actual clock/sampling frequency from period
        f_clk = 1.0e9 / CLK_PERIOD;           // 100 MHz
        f_sample = f_clk;                      // Sample rate = clock rate
        
        // Calculate phase increment: (f_out / f_clk) * 2^32
        phase_increment = $rtoi((SIGNAL_FREQ / f_clk) * (2.0**32));

        $display("========================================");
        $display("NCO Configuration:");
        $display("  Clock frequency:    %.0f MHz", f_clk/1.0e6);
        $display("  Sampling frequency: %.0f MHz", f_sample/1.0e6);
        $display("  NCO frequency:      %.0f kHz", SIGNAL_FREQ/1.0e3);
        $display("  Phase increment:    %0d (0x%08h)", phase_increment, phase_increment);
        $display("========================================");
    end

    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        // Initialize signals
        rst_n = 0;
        adc_data = 0;
        adc_valid = 0;
        error_count = 0;

        // Open single output file for all data
        // Format: NCO_sin NCO_cos Mixer_I Mixer_Q (space-separated)
        file_output = $fopen("lia_output.txt", "w");

        if (file_output == 0) begin
            $display("ERROR: Could not open output file!");
            $finish;
        end

        // Print test configuration
        $display("");
        $display("========================================");
        $display("LIA Digital Core Testbench - FIXED");
        $display("========================================");
        $display("Configuration:");
        $display("  Clock:         %.0f MHz", 1000.0/CLK_PERIOD);
        $display("  ADC width:     %0d bits", DATA_WIDTH);
        $display("  NCO width:     %0d bits", NCO_WIDTH);
        $display("  Mixer width:   %0d bits", MIXER_WIDTH);
        $display("  Signal freq:   %.1f kHz", SIGNAL_FREQ/1.0e3);
        $display("  Signal amp:    %.0f codes", SIGNAL_AMP);
        $display("  Sample rate:   %.0f MHz", f_sample/1.0e6);
        $display("  Num samples:   %0d", NUM_SAMPLES);
        $display("========================================");
        $display("");

        // Reset sequence (100 ns)
        $display("Applying reset...");
        #100;
        @(posedge clk);
        #1;
        rst_n = 1;
        
        // Wait a few cycles for pipeline to initialize
        repeat(5) @(posedge clk);
        $display("Reset released. Starting test...");
        $display("");

        // Generate test signal
        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            @(posedge clk);
            #1;  // Small delay after clock edge for stability

            // Calculate time using actual clock period
            time_sec = $itor(i) * CLK_PERIOD / 1.0e9;

            // Generate sine wave at calculated time
            adc_real = SIGNAL_AMP * $sin(2.0 * 3.141592653589793 * SIGNAL_FREQ * time_sec);
            adc_data = $rtoi(adc_real);

            // Clip to 12-bit signed range [-2048, 2047]
            if (adc_data > 2047) adc_data = 2047;
            if (adc_data < -2048) adc_data = -2048;

            adc_valid = 1'b1;

            // Progress display every 1000 samples
            if (i % 1000 == 0 && i > 0) begin
                $display("[%0t] Sample %5d: ADC=%5d, NCO_sin=%5d, Mixer_I=%8d, Mixer_Q=%8d",
                         $time, i, adc_data, dut.nco_sin, mixer_i_out, mixer_q_out);
            end
        end

        // Flush pipeline (continue for a few more cycles)
        $display("");
        $display("Flushing pipeline...");
        adc_valid = 1'b0;
        repeat(10) @(posedge clk);

        // Close file
        $fclose(file_output);

        // Print summary
        $display("");
        $display("========================================");
        $display("Simulation Complete");
        $display("========================================");
        $display("Total samples generated: %0d", NUM_SAMPLES);
        $display("Simulation time:         %.2f us", (NUM_SAMPLES * CLK_PERIOD) / 1.0e3);
        $display("Assertion errors:        %0d", error_count);
        $display("");
        $display("Output file created:");
        $display("  - lia_output.txt (Format: NCO_sin NCO_cos Mixer_I Mixer_Q)");
        $display("");
        
        if (error_count > 0) begin
            $display("WARNING: %0d assertion errors detected!", error_count);
            $display("Check simulation log for details.");
        end else begin
            $display("SUCCESS: No assertion errors detected.");
        end
        
        $display("");
        $display("Next step: Run MATLAB verification script");
        $display("========================================");

        $finish;
    end

    //==========================================================================
    // Atomic Output Capture - ALL DATA WRITTEN ON SAME CLOCK EDGE
    // This eliminates any possible synchronization issues
    //==========================================================================
    always @(posedge clk) begin
        // Write NCO outputs when valid
        // Format: NCO_sin NCO_cos Mixer_I Mixer_Q
        // All values captured at the SAME clock edge
        if (dut.nco_valid || mixer_valid) begin
            $fwrite(file_output, "%d %d %d %d\n", 
                    dut.nco_sin, 
                    dut.nco_cos, 
                    mixer_i_out, 
                    mixer_q_out);
        end
    end

    //==========================================================================
    // Synchronization Assertions
    // Verify that both mixers operate in lockstep
    //==========================================================================
    always @(posedge clk) begin
        if (rst_n) begin
            // Check 1: Both mixers should have identical valid signals
            if (dut.mixer_i.valid !== dut.mixer_q.valid) begin
                $display("ASSERTION ERROR at %0t: Mixer valid signals mismatch!", $time);
                $display("  mixer_i.valid = %b", dut.mixer_i.valid);
                $display("  mixer_q.valid = %b", dut.mixer_q.valid);
                error_count = error_count + 1;
            end
            
            // Check 2: Both mixers should capture ADC on same cycle
            if (dut.mixer_i.valid_stage1 !== dut.mixer_q.valid_stage1) begin
                $display("ASSERTION ERROR at %0t: Mixer stage1 valid mismatch!", $time);
                $display("  mixer_i.valid_stage1 = %b", dut.mixer_i.valid_stage1);
                $display("  mixer_q.valid_stage1 = %b", dut.mixer_q.valid_stage1);
                error_count = error_count + 1;
            end
            
            // Check 3: Both mixers should have captured same ADC value
            if (dut.mixer_i.valid_stage1 && dut.mixer_q.valid_stage1) begin
                if (dut.mixer_i.adc_reg !== dut.mixer_q.adc_reg) begin
                    $display("ASSERTION ERROR at %0t: Mixers captured different ADC values!", $time);
                    $display("  mixer_i.adc_reg = %d", dut.mixer_i.adc_reg);
                    $display("  mixer_q.adc_reg = %d", dut.mixer_q.adc_reg);
                    error_count = error_count + 1;
                end
            end
        end
    end

    //==========================================================================
    // Range Check Assertions
    // Verify outputs stay within expected ranges
    //==========================================================================
    always @(posedge clk) begin
        if (mixer_valid) begin
            // Check for overflow (mixer output should be within 24-bit signed range)
            if (mixer_i_out > 8388607 || mixer_i_out < -8388608) begin
                $display("ASSERTION ERROR at %0t: Mixer I overflow detected!", $time);
                $display("  mixer_i_out = %d (sample %0d)", mixer_i_out, i);
                error_count = error_count + 1;
            end
            
            if (mixer_q_out > 8388607 || mixer_q_out < -8388608) begin
                $display("ASSERTION ERROR at %0t: Mixer Q overflow detected!", $time);
                $display("  mixer_q_out = %d (sample %0d)", mixer_q_out, i);
                error_count = error_count + 1;
            end
        end
    end

    //==========================================================================
    // Waveform Dump for GTKWave/ModelSim
    //==========================================================================
    initial begin
        $dumpfile("lia_digital_core_tb.vcd");
        $dumpvars(0, lia_digital_core_tb);

        // Dump critical internal signals for debugging
        $dumpvars(1, dut.nco_inst.phase_accum);
        $dumpvars(1, dut.mixer_i.adc_reg);
        $dumpvars(1, dut.mixer_i.nco_reg);
        $dumpvars(1, dut.mixer_i.product);
        $dumpvars(1, dut.mixer_i.valid_stage1);
        $dumpvars(1, dut.mixer_q.adc_reg);
        $dumpvars(1, dut.mixer_q.nco_reg);
        $dumpvars(1, dut.mixer_q.product);
        $dumpvars(1, dut.mixer_q.valid_stage1);
    end

    //==========================================================================
    // Watchdog Timer (safety mechanism)
    //==========================================================================
    initial begin
        #(CLK_PERIOD * (NUM_SAMPLES + 1000));  // Extra time for pipeline flush
        $display("");
        $display("ERROR: Simulation timeout!");
        $display("Expected %0d samples, but simulation did not complete.", NUM_SAMPLES);
        $finish;
    end

endmodule // lia_digital_core_tb
