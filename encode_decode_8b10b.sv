// Encodes inData as 8b10b, then decodes it back into regular data
module encode_decode_8b10b(clk, reset, inControl, outControl, inData, outData);
  input logic clk, reset;
  input logic inControl;
  output logic outControl;
  input logic [7:0] inData;
  output logic [7:0] outData;

  logic [9:0] encoder_output;

  // 8b10b ENCODER/DECODER
encoder_8b10b encode_audio (
  .reset(reset),
  .SBYTECLK(clk),
  .K(inControl),
  .ebi(inData),
  .tbi(encoder_output),
  .disparity()
);

decoder_8b10b decode_audio (
  .reset(reset),
  .RBYTECLK(clk),
  .tbi(encoder_output),
  .K_out(outControl),
  .ebi(outData),
  .coding_err(),
  .disparity(),
  .disparity_err()
);

endmodule

module encode_decode_tb();
  logic clk, reset;
  logic inControl;
  logic outControl;
  logic [7:0] inData;
  logic [7:0] outData;

  encode_decode_8b10b DUT(clk, reset, inControl, outControl, inData, outData);

  initial begin
    clk = 1'b0; #5;
    forever begin
      clk = 1'b1; #5;
      clk = 1'b0; #5;
    end
  end

  initial begin
    inControl = 1'b0; inData = 8'd43; 
    reset = 1'b1; #15; reset = 1'b0; #10; 
    #20;
    #20;
    inData = 8'd189; inControl = 1'b1; #500;
    //inControl = 1'b1; #90;
    //inControl = 1'b0; #90;
    $stop();
  end

endmodule