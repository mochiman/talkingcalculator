`default_nettype none

// When it recieves the start signal, it will perform routine to retrieve memory
// from address controlled by audio controller and output it to outData via FF.
module flash_controller(clk, reset, read, byteEnable, waitRequest, readData, readDataValid, outData, start, finish);
    input   logic           clk, reset;     // 50Mhz clock
    output  logic           read;           // Flash read signal
    output  logic [3:0]     byteEnable;     // Assigned to 4'b1111
    input   logic [31:0]    readData;       // Data from memory
    input   logic           waitRequest;    // Indicates master must wait before sending more read requests
    input   logic           readDataValid;  // Indicates readData has valid data to be read by master
    output  logic           [31:0] outData; // Output of read audio data
    input   logic           start;          // Tells flashController to retrieve new data from next address
    output  logic           finish;         // Incicates flash controller is finished retrieving memory and is idling

    // STATES
    logic [4:0] state;
    parameter idle          = 4'b00_001;
    parameter sendRead      = 4'b01_010;
    parameter waitForData   = 4'b10_100;

    assign {enable_outData, read, finish} = state[2:0];
    assign byteEnable = 4'b1111; // 32 bits

    // SYNCHRONIZATION LOGIC
    // Single pulse edge capture on start signal
    logic synced_start;
    single_pulse_edgeTrap start_trap(clk, start, synced_start);

    // DATA OUTPUT LOGIC
    logic enable_outData;
    vDFFE #(32) updateDataFF(clk, reset, enable_outData, readData, outData);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) state <= idle;

        else case (state)
            idle: if (synced_start) state <= sendRead;

            sendRead: state <= waitForData;

            waitForData: begin
                if (readDataValid) state <= idle;
            end

            default: state <= idle;
        endcase
    end
endmodule

// Takes 32-bit audio data and outputs samples from byte addresses 
// start_address to end_address which are read from flash using the getNewData signal
module audio_controller(clk, reset, inData, audioData, getNewData, address, start_address, end_address, start, finish);
    input   logic           clk, reset;
    input   logic [31:0]    inData;
    output  logic [7:0]     audioData;
    output  logic           getNewData;
    output  logic [22:0]    address;
    input   logic [23:0]    start_address, end_address;
    input   logic           start;
    output  logic           finish;

    // STATE LOGIC
    parameter idle = 1'b0;   
    parameter playback = 1'b1; 

    logic current_state, next_state;
    vDFFE #(1) stateFF(clk, reset, 1'b1, next_state, current_state);

    // SYNCHRONIZATION LOGIC
    // Sync the start signal to only posedge
    logic synced_start;
    single_pulse_edgeTrap startTrap(clk, start, synced_start);

     // ADDRESS CONTROL LOGIC
    logic enable_address;
    logic [23:0] current_byte_address, next_byte_address; 
    vDFFE #(24) addressFF(clk, reset, 1'b1, next_byte_address, current_byte_address);

    // ADDRESSING LOGIC
    logic [22:0] word_address;
    logic [1:0]  memory_position;
    assign word_address = current_byte_address / 24'd4;
    assign memory_position = current_byte_address % 24'd4;

    // MEMORY LOGIC
    // save value of inData only on clock pulse to sync with audio controller
    logic [31:0] saved_audio_data;
    logic load_audio_data;
    vDFFE #(32) audio_data_ff(clk, reset, load_audio_data, inData, saved_audio_data);

    always_comb begin
        next_state = current_state; 
        getNewData = 1'b0;     
        finish = 1'b0;
        load_audio_data = 1'b0;
        address = word_address;

        case (current_state) 
            idle: begin
                audioData = 8'd0;
                finish = 1'b1;
                next_byte_address = start_address;   

                // Start signal recieved, load new audio from flash
                if (synced_start) begin 
                    next_state = playback;
                    getNewData = 1'b1; 
                    load_audio_data = 1'b1;
                end
            end

            playback: begin
                // Sample to output depends on byte 
                case (memory_position)
                    2'd0:   audioData = saved_audio_data[7:0];
                    2'd1:   audioData = saved_audio_data[15:8];
                    2'd2:   audioData = saved_audio_data[23:16];
                    2'd3:   audioData = saved_audio_data[31:24];
                    default: audioData = 8'd0;
                endcase
                
                next_byte_address = current_byte_address + 24'd1;

                // If were at the last address, finish
                if (current_byte_address == end_address) next_state = idle;

                // Otherwise if were at the last byte, read new flash data
                else if (memory_position == 3) begin 
                    address = word_address + 24'd1; // While were on byte 3, read next flash address
                    getNewData = 1'b1;
                    load_audio_data = 1'b1;
                end
            end

            default: next_state = idle;
        endcase
    end
endmodule

// Increases or decreases frequency divider divisor based on speeding up, down, or reset
module speed_controller(clk, speedUp, speedDown, reset, currentSpeed);
    parameter defaultSpeed = 32'd6944; // 7200hz
    parameter speedFactor = 32'd50;

    input logic clk, speedUp, speedDown, reset;
    output logic [31:0] currentSpeed = defaultSpeed; 

    always @(posedge clk) begin
        if (reset)
            currentSpeed <= defaultSpeed;
        else if (speedUp)
            currentSpeed <= currentSpeed + speedFactor;
        else if (speedDown)
            currentSpeed <= currentSpeed - speedFactor;
    end

endmodule