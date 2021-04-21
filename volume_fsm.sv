// Volume FSM
// Takes 256 samples of audio data, gets the absolute value, averages them, 
// and outputs volume from left to right
module volume_fsm(clk, reset, sample, outVolume, start, finish);
    input logic clk, reset;
    input logic [7:0] sample;
    output logic [7:0] outVolume;
    input logic start;  // Indicates new audio sample has been recieved
    output logic finish; // Indicates idle

    // State encoding
    // 4 states represented by 2 bits
    // State encoding represented as 6 bits and includes in order:
    // load_sample_sum, load_sample_count, load_volume, reset_sample_sum, reset_sample_count, finish
    logic [7:0] current_state;

    parameter reset_fsm =           8'b00_000110;
    parameter wait_for_sample =     8'b00_000001;
    parameter process_sample =      8'b01_110000;
    parameter update_volume =       8'b10_001000;

    logic [15:0] sample_sum, next_sample_sum;           // Sum of samples, every time a sample is recieved add to this reg
    logic [7:0]  sample_count, next_sample_count;       // Number of samples counted
    logic [7:0]  next_volume;
    logic load_sample_sum, load_sample_count, load_volume;
    logic reset_sample_sum, reset_sample_count;

    // Flipflops to save sum, count, and volume
    vDFFE #(16) sample_sum_FF   (clk, reset_sample_sum,     load_sample_sum,    next_sample_sum,    sample_sum);
    vDFFE #(8)  sample_count_FF (clk, reset_sample_count,   load_sample_count,  next_sample_count,  sample_count);
    vDFFE #(8)  volume_FF       (clk, reset,                load_volume,        next_volume,        outVolume);

    // Counter for sample count
    counter #(.width(8), .increment(1), .min(0), .max(255)) sample_counter(1'b0, sample_count, next_sample_count);

    // Absolute value logic
    logic [7:0] sample_abs_value;
    absolute_value #(8) get_sample_abs_value(sample, sample_abs_value);

    // Summation logic
    assign next_sample_sum = sample_sum + sample_abs_value;

    // Volume logic
    sum_to_volume volumeOut(sample_sum[15:8], next_volume);

    // State encoding
    assign {load_sample_sum, load_sample_count, load_volume, reset_sample_sum, reset_sample_count, finish} = current_state[5:0];

    // State machine with synchronous reset
    always_ff @(posedge clk) begin
        if (reset) current_state <= reset_fsm;

        else case (current_state)
            reset_fsm: current_state <= wait_for_sample;

            wait_for_sample: if (start) current_state <= process_sample;

            process_sample: begin
                if (sample_count == 8'd255) current_state <= update_volume;
                else current_state <= wait_for_sample;
            end

            update_volume: current_state <= reset_fsm;

            default: current_state <= reset_fsm;
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