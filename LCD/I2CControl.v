module I2CControl(
    input clk_50K,
    input rstn,
    inout i2c_scl,
    inout i2c_sda,
    input start,
    input [7:0] data,
    input last_data,
    output sda_valid,
    output reg ack_returned
);

parameter S_IDLE = 3'b000, S_START = 3'b001, S_OPERATION = 3'b011, S_WAIT_ACK = 3'b010, S_STOP = 3'b110;

reg [1:0] scl_reg;
reg       sda_reg;
reg [2:0] state;
reg [2:0] next_state;
reg [2:0] index;

assign sda_valid = state == S_START | state == S_OPERATION | state == S_STOP;
assign i2c_scl   = scl_reg[1];
assign i2c_sda   = sda_valid ? sda_reg : 1'bz;

// index
always @(posedge clk_50K) begin
    if(~rstn) begin
        index <= 3'd7;
    end else if(start) begin
        index <= 3'd7;
    end else if(state == S_OPERATION & scl_reg == 2'b11) begin
        index <= index - 3'd1;
    end else begin
        index <= index;
    end
end

// scl_reg
always @(posedge clk_50K) begin
    if(~rstn) begin
        scl_reg <= 2'b01;
    end else if(state == S_IDLE) begin
        scl_reg <= 2'b10;
    end else if(state != S_IDLE) begin
        scl_reg <= scl_reg + 2'b01;
    end else begin
        scl_reg <= scl_reg;
    end
end

// sda_reg
always @(posedge clk_50K) begin
    if(~rstn) begin
        sda_reg <= 1'b1;
    end else if(state == S_IDLE)begin
        sda_reg <= 1'b1;
    end else if(state == S_START) begin
        if(scl_reg[1]) begin
            sda_reg <= 1'b0;
        end else begin
            sda_reg <= 1'b1;
        end
    end else if(state == S_OPERATION) begin
        sda_reg <= data[index];
    end else if(state == S_STOP) begin
        if(scl_reg == 2'b10) begin
            sda_reg <= 1'b1;
        end else begin
            sda_reg <= sda_reg;
        end
    end else begin
        sda_reg <= sda_reg;
    end
end

// ack_returned
always @(posedge clk_50K) begin
    if(~rstn) begin
        ack_returned <= 1'b0;
    end else if(state == S_OPERATION) begin
        ack_returned <= 1'b0;
    end else if(state == S_WAIT_ACK & i2c_scl & ~i2c_sda) begin
        ack_returned <= 1'b1;
    end else begin
        ack_returned <= ack_returned;
    end
end

// state
always @(posedge clk_50K) begin
    if(~rstn) begin
        state <= S_IDLE;
    end else begin
        state <= next_state;
    end
end

// state
always @* begin
  case(state)
    S_IDLE   :
    if(start)                                             next_state <= S_START;
    else                                                  next_state <= S_IDLE;

    S_START :
    if(i2c_scl & ~i2c_sda)                                next_state <= S_OPERATION;
    else                                                  next_state <= S_START;

    S_OPERATION :
    if(index == 3'd0 & scl_reg == 2'b11)                  next_state <= S_WAIT_ACK;
    else                                                  next_state <= S_OPERATION;

    S_WAIT_ACK :
    if(ack_returned & scl_reg == 2'b11 & ~last_data)      next_state <= S_OPERATION;
    else if (ack_returned & scl_reg == 2'b11 & last_data) next_state <= S_STOP;
    else                                                  next_state <= S_WAIT_ACK;

    S_STOP :
    if(i2c_scl & i2c_sda)                                 next_state <= S_IDLE;
    else                                                  next_state <= S_STOP;

    default  :
    next_state <= S_IDLE;
    endcase
end

endmodule

