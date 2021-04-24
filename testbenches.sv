`default_nettype none

module volume_fsm_tb();
    logic clk, reset;
    logic [7:0] sample;
    logic [7:0] outVolume;
    logic start; 
    logic finish; 

    volume_fsm DUT(clk, reset, sample, outVolume, start, finish);

    initial begin
        clk = 1'b0; #1;
        forever begin
            clk = 1'b1; #1;
            clk = 1'b0; #1;
        end
    end

    initial begin
        start = 1'b0; #40;
        forever begin
            start = 1'b1; #10;
            start = 1'b0; #10;
        end
    end

    initial begin
        reset = 1'b1; #10;
        reset = 1'b0; #10;
        sample = 8'b11000010;
        #20;
        #5000;
        #1000;
        $stop();


    end
endmodule

module audio_ctrl_tb();
    logic clk, reset;
    logic [31:0] inData;
    logic [7:0] audioData;
    logic getNewData;
    logic [22:0] address;
    logic [23:0] start_address, end_address;
    logic start;
    logic finish;

    audio_ctrl DUT (clk, reset, inData, audioData, getNewData, address, start_address, end_address, start, finish);

    // Rom is treated as flash control eg. getNewData
    ROM EPCS128_flash(address, getNewData, inData);

    initial begin
        clk = 1'b1; #5;
        forever begin
            clk = 1'b0; #5;
            clk = 1'b1; #5;
        end
    end

    initial begin
        start_address = 24'd403; end_address = 24'd411; reset = 1'b0;  start = 1'b0;
        #10;
        reset = 1'b1; #5;
        reset = 1'b0; #5;
        start = 1'b1; #10;
        start = 1'b0; #10;
        #100;
        #20;
        // Finished first audio, feed new one
        start_address = 24'd2548; end_address = 24'd2555;
        start = 1'b1; #10;
        start = 1'b0; #10;
        #100;

        $stop();
    end
endmodule

module flash_ctrl_tb();
    logic           clk, reset;    
    logic           read;          
    logic [3:0]     byteEnable;   
    logic [31:0]    readData;      
    logic           waitRequest;    
    logic           readDataValid;
    logic [31:0]    outData;       
    logic           start;      
    logic           finish;        

    flash_ctrl DUT(clk, reset, read, byteEnable, waitRequest, readData, readDataValid, outData, start, finish);

    initial begin
        clk = 1'b0; #5;
        forever begin
            clk = 1'b1; #5;
            clk = 1'b0; #5;
        end
    end

    initial begin
        reset = 1'b1; waitRequest = 1'b0; readDataValid = 1'b0; start = 1'b0; readData = 32'd123456789;
        #10;
        reset = 1'b0;
        #10;
        start = 1'b1;
        #10;
        start = 1'b0;
        #50;
        readDataValid = 1'b1; #10;
        #50;

        $stop();
    end
endmodule

module ROM(address, clock, q);
    parameter ADDR_WIDTH = 23;
    parameter DATA_WIDTH = 32;
    parameter DEPTH = 700;

    input logic [ADDR_WIDTH - 1:0] address;
    input logic clock;
    output reg [DATA_WIDTH - 1:0] q;

    wire [DATA_WIDTH - 1:0] mem [0:DEPTH-1];

    // First phoneme
    // Word address 100-102
    // Byte address 400 - 412
    assign mem[100] = {8'd3, 8'd2, 8'd1, 8'd0};
    assign mem[101] = {8'd7, 8'd6, 8'd5, 8'd4};
    assign mem[102] = {8'd11, 8'd10, 8'd9, 8'd8};

    // Second phoneme
    // Byte address 2548 - 2555
    // Word address 637 - 693
    assign mem[637] = {8'd15, 8'd14, 8'd13, 8'd12};
    assign mem[638] = {8'd19, 8'd18, 8'd17, 8'd16};
    assign mem[639] = {8'd23, 8'd22, 8'd21, 8'd20};

    always @(posedge clock) begin
        q <= mem[address];
    end
    
endmodule