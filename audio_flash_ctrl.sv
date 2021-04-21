`default_nettype none

// Continously reads from memory and outputs readData as outData
// Will increment address and fetch new data at posedge of the start signal
module flashController(clk, reset, start, read, byteEnable, waitRequest, readData, readDataValid, outData, direction);
    input logic clk, reset; // 50Mhz clock
    input logic start; // Tells flashController to retrieve new data from next address
    // output logic [22:0] address; // Address to read
    output logic read; 
    output logic [3:0] byteEnable;
    input logic [31:0] readData; // Data in memory
    input logic waitRequest; // Indicates master must wait before sending more read requests
    input logic readDataValid; // Indicates readData has valid data to be read by master
    output logic [31:0] outData; // Output of read audio data
    input logic direction; // 0 = forward, 1 = backwards
    // output logic done; // Data has been read, is idling

    // STATES
    parameter cleanState = 4'b0000;
    parameter sendRead = 4'b0001;
    parameter waitForData = 4'b0010;
    parameter updatePC = 4'b0100;
    parameter idle = 4'b1000;

    logic updateData;

    // STATE LOGIC
    logic [3:0] current_state, next_state, next_state_reset;
    vDFFE #(4) stateFF(clk, 1'b0, 1'b1, next_state_reset, current_state);

    assign next_state_reset = reset ? cleanState : next_state;

    // SAMPLING LOGIC
    logic readNewData, reset_newData;
    vDFFE #(1) newDataFF(start, reset_newData, 1'b1, 1'b1, readNewData);

    // DATA OUTPUT LOGIC
    logic enable_dataOut, reset_dataOut;
    vDFFE #(32) updateDataFF(clk, reset_dataOut, enable_dataOut, readData, outData); 

    always_comb begin
        // Initialize variables to default values
        next_state = 4'bxxxx; read = 1'b0; byteEnable = 4'b1111; 
        reset_newData = 1'b0;
        enable_dataOut = 1'b0; reset_dataOut = 1'b0;

        case (current_state)
            cleanState: begin
                // reset_pc = 1'b1; 
                reset_newData = 1'b1;
                reset_dataOut = 1'b1;
                next_state = idle;
            end

            idle: begin
                if (readNewData) begin 
                    next_state = sendRead;
                end
                else next_state = idle;
            end

            sendRead: begin
                // Make sure no new data will be read after this
                reset_newData = 1'b1;
                read = 1'b1;
                next_state = waitForData;
            end

            waitForData: begin
                enable_dataOut = 1'b1;
                if (readDataValid) begin
                    next_state = idle;
                end

                else next_state = waitForData;
            end

            default: begin
                next_state = 4'bxxxx; read = 1'b0; byteEnable = 4'b1111; 
                reset_newData = 1'b0;
                enable_dataOut = 1'b0; reset_dataOut = 1'b0;
            end
        endcase
        
    end
endmodule

// Takes 32-bit audio data and samples 4 times
// finished is fed into FSM to tell it to retrieve new data after 
// all data has been parsed
// audio_data =  inData[(current_address %4) * 4 + 4:(current_address %4) * 4]
// start command from pico, finish sent to pico
// pico controlls pretty much
module audioController(clk, reset, inData, audioData, getNewData, address, start_address, end_address, silent, start, finish);
    input logic clk, reset;
    input logic [31:0] inData;
    output logic [7:0] audioData;
    output logic getNewData;
    output logic [23:0] address;
    input logic [23:0] start_address, end_address;
    input logic silent;
    input logic start;
    output logic finish;

    parameter state1 = 1'b0;
    parameter state2 = 1'b1;

    // ADDRESS CONTROL LOGIC
    logic enable_address;
    logic [23:0] current_address, next_address; // current_address counts byte addresses

    vDFFE #(24) addressFF(clk, reset, 1'b1, next_address, current_address);

    // SYNCRONIZATION LOGIC
    // Sync the start signal
    logic synced_start;
    single_pulse_edgeTrap startTrap(clk, start, synced_start);

    // ADDRESSING LOGIC
    logic [23:0] word_address;
    logic [1:0]  memory_position; //, high_address, low_address; 
    // word_address is the address used to access the byte position in flash data
    assign word_address = current_address / 24'd4;
    //assign address = word_address;

    // memory position is the current byte position in memory eg. 0-3 for 4 samples in each 32-bit word
    assign memory_position = current_address % 24'd4;

    // MEMORY LOGIC
    // save value of inData only on clock pulse to sync with audio controller
    logic [31:0] saved_audio_data;
    logic load_audio_data;
    vDFFE #(32) audio_data_ff(clk, reset, load_audio_data, inData, saved_audio_data);

    // STATE LOGIC
    logic current_state, next_state;
    vDFFE #(1) stateFF(clk, reset, 1'b1, next_state, current_state);

    always_comb begin
        next_state = current_state; 
        getNewData = 1'b0;     
        finish = 1'b0;
        load_audio_data = 1'b0;
        address = word_address;

        case (current_state) 
            state1: begin
                audioData = 8'd0;
                finish = 1'b1;
                next_address = start_address;                
                if (synced_start) begin 
                    next_state = state2;
                    getNewData = 1'b1; // Load new audio data from player
                    load_audio_data = 1'b1;
                end
            end

            state2: begin
                // Memory to read depends on byte 

                if (silent) audioData = 8'd0;
                else case (memory_position)
                    2'd0:   audioData = saved_audio_data[7:0];
                    2'd1:   audioData = saved_audio_data[15:8];
                    2'd2:   audioData = saved_audio_data[23:16];
                    2'd3:   audioData = saved_audio_data[31:24];
                    default: audioData = 8'bx;
                endcase
                next_address = current_address + 24'd1;

                // If were at the last address, finish
                if (current_address == end_address) next_state = state1;

                // Otherwise if were at the last byte, read new flash data
                else if (memory_position == 3) begin 
                    address = word_address + 24'd1;
                    getNewData = 1'b1;
                    load_audio_data = 1'b1;
                end
            end

            default: begin
            next_address = 24'bx;
            next_state = state1;
            end
        endcase
    end
endmodule

// Increases or decreases frequency divider divisor based on speeding up, down, or reset
module speedController(clk, speedUp, speedDown, reset, currentSpeed);
    parameter defaultSpeed = 32'd6944; // 7200hz
    parameter speedFactor = 32'd10;

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