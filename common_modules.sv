`default_nettype none

// Counter with controllable min and max
// Counts up or down based on control, 0 = up, 1 = down
// Resets to min when counting up and reaching max value, 
// resets to max when counting down and reaching min value
module counter(control, current_count, next_count);
    parameter width = 32;
    parameter increment = 'd1;
    parameter min = 'd0;
    parameter max = 'h7FFFF;

    input logic control; // First bit for reset, second bit for direction
    input logic [width-1:0] current_count;
    output logic [width-1:0] next_count;

    always_comb begin
        case (control)
            1'b0: begin
                if (current_count == max) next_count = min;
                else next_count = current_count + increment;
            end
            1'b1: begin
                if (current_count == min) next_count = max;
                else next_count = current_count - increment;
            end
            default: next_count = current_count;
        endcase
    end
endmodule

// DFF with enable and asynchronous reset
module vDFFE(clk, reset, enable, d, q);
    parameter width = 8;
    
    input logic clk, enable, reset;
    input logic [width-1:0] d;
    output logic [width-1:0] q = 0;

    logic [width-1:0] dataSelector;

    assign dataSelector = enable ? d : q;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) q <= 0;
        else q <= dataSelector;
    end
endmodule


// Clock divider, outClock will be the inClock divided by the divisor
// 32 bit divisor
module clockdivider32(inClock, outClock, divisor);
    input logic inClock;
    output logic outClock;
    input logic [31:0] divisor;

    logic [31:0] counter = 32'd0;

    always_ff @(posedge inClock) begin
        counter <= counter + 32'd1;
        if (counter >= (divisor - 1))
            counter <= 32'd0;

        outClock <= (counter < divisor / 2) ? 1'b1 : 1'b0;
    end

endmodule

// Edge trapper
// Upon detected edge, out will be high for one clock pulse of destination clock
// then be reset to 0
// Input clk is the destination domain's clock
// Additional FF for metastability
module single_pulse_edgeTrap(clk, in, out);
    input logic clk, in;
    output logic out;

    logic trapped_pulse, synced_pulse;

    vDFFE #(1) trap_ff(in, out, 1'b1, 1'b1, trapped_pulse);
    vDFFE #(1) sync_ff(clk, out, 1'b1, trapped_pulse, synced_pulse);
    vDFFE #(1) out_ff(clk, 1'b0, 1'b1, synced_pulse, out);
endmodule

// Regular edge trap with reset
// Additional FF for metastability
module edge_trap(clk, reset, in, out);
    input logic clk, reset, in;
    output logic out;

    logic trapped_pulse, synced_pulse;

    vDFFE #(1) trap_ff(in, reset, 1'b1, 1'b1, trapped_pulse);
    vDFFE #(1) sync_ff(clk, reset, 1'b1, trapped_pulse, synced_pulse);
    vDFFE #(1) out_ff(clk, reset, 1'b1, synced_pulse, out);
endmodule

// 2:1 variable width MUX
module mux2_1(a0, a1, select, out);
parameter width = 8;

input logic [width-1:0] a0, a1;
input logic select;
output reg [width-1:0] out;

assign out = select ? a1 : a0;

endmodule

// 4:1 variable width MUX
// Constructed using three 2:1 muxes
module mux4_1(a0, a1, a2, a3, select, out);
parameter width = 8;

input logic [width-1:0] a0, a1, a2, a3;
input logic [1:0] select;
output logic [width-1:0] out;

wire [width-1:0] muxA_out, muxB_out;

mux2_1 #(width) muxA(a0, a1, select[0], muxA_out);
mux2_1 #(width) muxB(a2, a3, select[0], muxB_out);
mux2_1 #(width) muxC(muxA_out, muxB_out, select[1], out);

endmodule

// 8:1 variable width MUX
// Constructed using two 4:1 muxes and one 2:1 mux
module mux8_1(a0, a1, a2, a3, a4, a5, a6, a7, select, out);
parameter width = 8;

input logic [width-1:0] a0, a1, a2, a3, a4, a5, a6, a7;
input logic [2:0] select;
output logic [width-1:0] out;

wire [width-1:0] muxA_out, muxB_out;

mux4_1 #(width) muxA(a0, a1, a2, a3, select[1:0], muxA_out);
mux4_1 #(width) muxB(a4, a5, a6, a7, select[1:0], muxB_out);
mux2_1 #(width) muxC(muxA_out, muxB_out, select[2], out);

endmodule

// Variable input and width MUX
// Inefficient for large muxes but simple when necessary
module variableMux (out, sel, in);
    parameter INPUTS = 4;
    parameter WIDTH = 8;

    output logic [WIDTH-1:0] out;
    input logic sel [INPUTS];
    input logic [WIDTH-1:0] in [0:INPUTS-1];

    always_comb
    begin
        out = {WIDTH{1'b0}};
        for (int unsigned index = 0; index < INPUTS; index++)
        begin
            out |= {WIDTH{sel[index]}} & in[index];
        end
    end
endmodule

// Isolates rightmost bit of input and outputs it
module isolate_rightmost_bit(in_bits, out_bits);
    parameter width = 8;
    
    input logic [width-1:0] in_bits;
    output logic [width-1:0] out_bits;

    initial begin
        out_bits = {width{1'b0}};
    end

    always @(*) begin
        out_bits = in_bits & (-in_bits);
    end

endmodule

// Converts unpacked wire to packed wire
module arrayToWire(inputArray, outputWire);
    parameter width = 8;
    input logic inputArray [width-1:0];
    output logic [width-1:0] outputWire;

    genvar i;
    generate
    for (i = 0; i < width; i = i + 1) begin : unpack
        assign outputWire[i] = inputArray[i];
    end
    endgenerate
endmodule

module encoder4_2 (a, b, c);
    input logic [3:0] a;
    output logic [1:0] b;
    output logic c;

    assign b[1] = a[3] | a[2];
    assign b[0] = a[3] | a[1];
    assign c = |a;
    
endmodule

// 16:4 encoder built from 4:2 encoders
module encoder16_4 (a, b, f);
    input logic [15:0] a;
    output logic [3:0] b;
    output logic f;

    logic [7:0] c; // Intermediate result of first stage
    logic [3:0] d; // Any set in group of 4

    // Four encoders each include 4-bits of input
    encoder4_2 e0(a[3:0], c[1:0], d[0]);
    encoder4_2 e1(a[7:4], c[3:2], d[1]);
    encoder4_2 e2(a[11:8], c[5:4], d[2]);
    encoder4_2 e3(a[15:12], c[7:6], d[3]);

    // MSB encoder gives MSB of output
    logic e;
    encoder4_2 e4(
        .a(d[3:0]), 
        .b(b[3:2]),
        .c()
    );

    // Two or gates combine encoders
    assign b[1:0] = c[1:0] | c[3:2] | c[5:4] | c[7:6];

    // If any are set 
    assign f = |a;


endmodule

// 64:6 encoder built from 4 16:4 encoders and 1 4:2 encoder
module encoder64_6 (a,b);
    input logic [63:0] a;
    output logic [5:0] b;

    logic [3:0] d;
    logic [15:0] c;

    // Four encoders each include 4-bits of input
    encoder16_4 e0(a[15:0],  c[3:0], d[0]);
    encoder16_4 e1(a[31:16], c[7:4], d[1]);
    encoder16_4 e2(a[47:32], c[11:8], d[2]);
    encoder16_4 e3(a[63:48], c[15:12], d[3]);

    // MSB encoder gives MSB of output
    encoder4_2 e4(
        .a(d[3:0]), 
        .b(b[5:4]), 
        .c()
    );

    // Two or gates combine encoders
    assign b[3:0] = c[3:0] | c[7:4] | c[11:8] | c[15:12];
    
endmodule