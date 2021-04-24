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
            start = 1'b1; #5;
            start = 1'b0; #5;
        end
    end

    initial begin
        reset = 1'b1; #10;
        reset = 1'b0; #10;
        sample = 8'b10000001;
        #20;
        #5000;
        #1000;
        $stop();


    end
endmodule

module audioController_tb();
    logic clk, reset;
    logic [31:0] inData;
    logic [7:0] audioData;
    logic getNewData;
    logic [23:0] address;
    logic [23:0] start_address, end_address;
    logic silent;
    logic start;
    logic finish;

    audioController DUT (clk, reset, inData, audioData, getNewData, address, start_address, end_address, start, finish);

    ROM testFlash(address, getNewData, inData);

    initial begin
        clk = 1'b0; #5;
        forever begin
            clk = 1'b1; #5;
            clk = 1'b0; #5;
        end
    end

    initial begin
        start_address = 24'd27; end_address = 24'd35; reset = 1'b1;  start = 1'b0; silent = 1'b0;
        #10;
        reset = 1'b0; #10;
        start = 1'b1; #10;
        start = 1'b0; #10;
        #100;
        start = 1'b1;
        #10;
        start = 1'b0;
        #50;

        $stop();
    end
endmodule


module flashController_tb();
    logic clk, reset;
    logic [31:0] inData;
    logic [7:0] audioData;
    logic getNewData;
    logic [23:0] address;
    logic [23:0] start_address, end_address;
    logic silent;
    logic start;
    logic finish;

    audioController DUT (clk, reset, inData, audioData, getNewData, address, start_address, end_address, start, finish);

    ROM testFlash(address, getNewData, inData);

    initial begin
        clk = 1'b0; #5;
        forever begin
            clk = 1'b1; #5;
            clk = 1'b0; #5;
        end
    end

    initial begin
        start_address = 24'd27; end_address = 24'd35; reset = 1'b1;  start = 1'b0; silent = 1'b0;
        #10;
        reset = 1'b0; #10;
        start = 1'b1; #10;
        start = 1'b0; #10;
        #100;
        start = 1'b1;
        #10;
        start = 1'b0;
        #50;

        $stop();
    end
endmodule

// Flash storage simulation of the EPCS128 
module EPCS128_flash(clk, address, q);
    input [22:0] address;
    input clock;
    output reg [31:0] q;

    // Corresponds to byte address 
    always_comb begin
        case (address) 
        24'd625: q = {8'd4, 8'd3, 8'd2, 8'd1};
        24'd626: q = {8'd8, 8'd7, 8'd6, 8'd5};
        24'd627: q = {8'd12, 8'd11, 8'd10, 8'd9};
        24'd628: q = {8'd16, 8'd15, 8'd14, 8'd13};
        default: q = 32'dx;

        endcase
    end 
    
endmodule