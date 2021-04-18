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
module audioController(clk, reset, pause, inData, audioData, finished, direction, address);
    input logic clk, reset, pause;
    input logic [32:0] inData;
    output logic [7:0] audioData;
    output logic finished;
    input logic direction;
    output logic [22:0] address;

    parameter state1 = 2'b11;
    parameter state2 = 2'b01;
    parameter state3 = 2'b10;
    parameter state4 = 2'b00;

    // ADDRESS CONTROL LOGIC
    logic enable_pc;
    logic [22:0] pc, next_pc;
    counter #(.width(23), .increment(1), .min(0), .max('h7FFFF)) programCounter(direction, pc, next_pc);

    vDFFE #(23) counterFF(clk, reset, enable_pc, next_pc, pc);
    assign address = pc;

    // STATE LOGIC
    logic [1:0] current_state, next_state, next_state_reset;
    vDFFE #(2) stateFF(clk, 1'b0, pause, next_state_reset, current_state);

    assign next_state_reset = reset ? state4 : next_state;

    always_comb begin
        finished = 1'b0; audioData = 8'bx; next_state = 2'bxx; enable_pc = 1'b0;

        case (current_state) 
            state1: begin
                enable_pc = 1'b1;
                next_state = state2;
                if (direction) audioData = inData[31:24];
                else audioData = inData[7:0];
            end

            state2: begin
                next_state = state3;
                if (direction) audioData = inData[23:16];
                else audioData = inData[15:8];
            end

            state3: begin
                if (direction) audioData = inData[15:8];
                else audioData = inData[23:16];
                next_state = state4;
            end

            state4: begin
                if (direction) audioData = inData[7:0];
                else audioData = inData[31:24];
                finished = 1'b1;
                next_state = state1;
            end

            default: begin 
                finished = 1'b0; audioData = 8'bx; next_state = 2'bxx; enable_pc = 1'b0;
            end

        endcase
    end
endmodule

// Takes in command and outputs resetCommand, pause, and direction for FSMs
module kbdController(clk, reset, command, resetCommand, pause, direction);
    input logic clk, reset;
    input logic [7:0] command;
    output logic resetCommand, pause, direction;

    parameter character_B =8'h42;
    parameter character_D =8'h44;
    parameter character_E =8'h45;
    parameter character_F =8'h46;
    parameter character_R =8'h52;

    logic load_pause, load_direction;
    logic next_resetCommand, next_direction, next_pause;
    logic resetSignal;

    vDFFE #(1) resetFF(clk, 1'b0, 1'b1, next_resetCommand, resetSignal);
    // Synchronization FF, resetCommand only updated on posedge 
    vDFFE #(1) resetComandFF(resetSignal, reset, 1'b1, 1'b1, resetCommand);

    vDFFE #(1) directionFF(clk, 1'b0, load_direction, next_direction, direction);
    vDFFE #(1) pauseFF(clk, 1'b0, load_pause, next_pause, pause);

    always_comb begin
                load_pause = 1'b0; load_direction = 1'b0;
                next_resetCommand = 1'b0; next_direction = 1'b0; next_pause = 1'b0;

        case (command)
            character_B: begin
                next_direction = 1'b1;
                load_direction = 1'b1;
            end
            character_F: begin
                next_direction = 1'b0;
                load_direction = 1'b1;
            end
            character_E: begin 
                next_pause = 1'b1;
                load_pause = 1'b1;
            end
            character_D: begin 
                next_pause = 1'b0;
                load_pause = 1'b1;
            end
            character_R: begin 
                next_resetCommand = 1'b1;
            end
            default: begin
                load_pause = 1'b0; load_direction = 1'b0;
                next_resetCommand = 1'b0; next_direction = 1'b0; next_pause = 1'b0;
            end
        endcase
    end

endmodule

// Increases or decreases frequency divider divisor based on speeding up, down, or reset
module speedController(clk, speedUp, speedDown, reset, currentSpeed);
    parameter defaultSpeed = 32'd1136;
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

module counter(controlPC, current_pc, next_pc);
    parameter width = 32;
    parameter increment = 'd1;
    parameter min = 'd0;
    parameter max = 'h7FFFF;

    input logic controlPC; // First bit for reset, second bit for direction
    input logic [width-1:0] current_pc;
    output logic [width-1:0] next_pc;

    always_comb begin
        case (controlPC)
            1'b0: begin
                if (current_pc == max) next_pc = min;
                else next_pc = current_pc + increment;
            end
            1'b1: begin
                if (current_pc == min) next_pc = max;
                else next_pc = current_pc - increment;
            end
            default: next_pc = current_pc;
        endcase
    end
endmodule

module vDFFE(clk, reset, enable, d, q);
    parameter width = 8;
    parameter startValue = 0;
    
    input logic clk, enable, reset;
    input logic [width-1:0] d;
    output logic [width-1:0] q = startValue;

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