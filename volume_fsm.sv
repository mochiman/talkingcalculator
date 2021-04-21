// Volume FSM
// Takes 256 samples of audio data, gets the absolute value, averages them, 
// and outputs volume from left to right in format XXXXXX00 based on MSB
module volume_fsm(clk, reset, sample, outVolume, start, finish);
    input logic clk, reset;
    input logic [7:0] sample;
    output logic [7:0] outVolume;
    input logic start;      // Process current audio sample
    output logic finish;    // Indicates idle

    // State encoding
    // 4 states represented by 2 bits and control signals in trailing 5 bits
    logic [6:0] current_state;

    parameter wait_for_sample       =   7'b00_00001;
    parameter process_sample        =   7'b01_11000;
    parameter average_samples       =   7'b10_10110;
    parameter update_volume         =   7'b11_00100;

    // Control signal assignment
    assign {load_sample_sum, load_sample_count, load_volume, average_sum, finish} = current_state[4:0];
    
    // Sampling and volume signals
    logic [15:0]    sample_sum,     next_sample_sum;    // Sum of samples
    logic [7:0]     sample_count,   next_sample_count;  // Number of samples counted
    logic [7:0]     next_volume;                        // Output volume

    // Load enables for FFs
    logic   load_sample_sum,    load_sample_count,  load_volume;  

    // Flipflops to save sum, count, and volume
    vDFFE #(16) sample_sum_FF   (clk,   reset,    load_sample_sum,      next_sample_sum,    sample_sum);
    vDFFE #(8)  sample_count_FF (clk,   reset,    load_sample_count,    next_sample_count,  sample_count);
    vDFFE #(8)  volume_FF       (clk,   reset,    load_volume,          next_volume,        outVolume);

    // Counter for sample count
    counter #(.width(8), .increment(1), .min(0), .max(255)) sample_counter(1'b0, sample_count, next_sample_count);

    // Absolute value logic
    logic [7:0] sample_abs_value;
    absolute_value #(8) get_sample_abs_value(sample, sample_abs_value);

    // Summation logic
    logic average_sum;
    assign next_sample_sum = average_sum ? (sample_sum >> 8) : (sample_sum + sample_abs_value);

    // Volume logic
    // Volume FF is load enabled after sum is averaged 
    sum_to_volume volumeOut(sample_sum[7:0], next_volume);

    // State machine with asynchronous reset
    always_ff @(posedge clk or posedge reset) begin
        if (reset) current_state <= wait_for_sample;

        else case (current_state)
            // Wait in this state until start signal is issued and new sample exists to process
            wait_for_sample: if (start) current_state <= process_sample;

            // Process by adding absolute value to sum
            // Update volume using current sum if count is 255
            process_sample: begin
                if (sample_count == 8'd255) current_state <= average_samples;
                else current_state <= wait_for_sample;
            end

            // Average samples by setting load_sample_sum and average_sum
            average_samples: current_state <= update_volume;

            // Load volume ff, then reset sample sum and count
            update_volume: current_state <= wait_for_sample;

            default: current_state <= wait_for_sample;
        endcase
    end
endmodule

// Outputs absolute value of input
module absolute_value(in, out);
    parameter width = 8;
    input logic [width-1:0] in;
    output logic [width-1:0] out;

    always_comb begin
        if (in[width-1] == 1'b1) out = -in;

        else out = in;
    end
endmodule

// Takes sum and represents it as xxxxx0 based on MSB
// Similar to priority encoder
module sum_to_volume(sum, volume);
    input logic [7:0]   sum;
    output logic [7:0]  volume;

    always_comb begin
        if      (sum[7] == 1'b1)    volume = 8'b11111111;
        else if (sum[6] == 1'b1)    volume = 8'b11111110;
        else if (sum[5] == 1'b1)    volume = 8'b11111100;
        else if (sum[4] == 1'b1)    volume = 8'b11111000;
        else if (sum[3] == 1'b1)    volume = 8'b11110000;
        else if (sum[2] == 1'b1)    volume = 8'b11100000;
        else if (sum[1] == 1'b1)    volume = 8'b10000000;
        else                        volume = 8'b00000000;
    end
endmodule