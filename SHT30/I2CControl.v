module I2CControl(
    input clk_50K,
    input rstn,
    inout i2c_scl,
    inout i2c_sda,
    input start,
    input [7:0] wdata,
    input last_wdata,
    input expect_reponse,
    output sda_valid,
    output reg ack_returned,
    output reg [5:0] rindex,
    output reg [47:0] rdata,
    output reg [2:0] i2c_state
);

parameter I2C_IDLE = 3'b000, I2C_START = 3'b001, I2C_WRITE = 3'b010, I2C_WAIT_ACK = 3'b011, I2C_READ = 3'b100, I2C_SEND_ACK = 3'b101, I2C_STOP = 3'b110;

reg [1:0] scl_reg;
reg       sda_reg;
// reg [2:0] i2c_state;
reg [2:0] next_i2c_state;
reg [2:0] windex;

assign sda_valid = i2c_state == I2C_START | i2c_state == I2C_WRITE | i2c_state == I2C_STOP | i2c_state == I2C_SEND_ACK;
assign i2c_scl   = scl_reg[1];
assign i2c_sda   = sda_valid ? sda_reg : 1'bz;

// windex
always @(posedge clk_50K) begin
    if(~rstn) begin
        windex <= 3'd7;
    end else if(start & i2c_state == I2C_IDLE) begin
        windex <= 3'd7;
    end else if(i2c_state == I2C_WRITE & scl_reg == 2'b11) begin
        windex <= windex - 3'd1;
    end else begin
        windex <= windex;
    end
end

// scl_reg
always @(posedge clk_50K) begin
    if(~rstn) begin
        scl_reg <= 2'b01;
    end else if(i2c_state == I2C_IDLE) begin
        scl_reg <= 2'b10;
    end else if(i2c_state != I2C_IDLE) begin
        scl_reg <= scl_reg + 2'b01;
    end else begin
        scl_reg <= scl_reg;
    end
end

// sda_reg
always @(posedge clk_50K) begin
    if(~rstn) begin
        sda_reg <= 1'b1;
    end else if(i2c_state == I2C_IDLE)begin
        sda_reg <= 1'b1;
    end else if(i2c_state == I2C_START) begin
        if(scl_reg[1]) begin
            sda_reg <= 1'b0;
        end else begin
            sda_reg <= 1'b1;
        end
    end else if(i2c_state == I2C_WRITE) begin
        sda_reg <= wdata[windex];
    end else if(i2c_state == I2C_STOP) begin
        if(scl_reg == 2'b10) begin
            sda_reg <= 1'b1;
        end else begin
            sda_reg <= sda_reg;
        end
    end else if(i2c_state == I2C_SEND_ACK) begin
        sda_reg <= 1'b0;
    end else begin
        sda_reg <= sda_reg;
    end
end

// ack_returned
always @(posedge clk_50K) begin
    if(~rstn) begin
        ack_returned <= 1'b0;
    end else if(i2c_state == I2C_WRITE) begin
        ack_returned <= 1'b0;
    end else if(i2c_state == I2C_WAIT_ACK & i2c_scl & ~i2c_sda) begin
        ack_returned <= 1'b1;
    end else begin
        ack_returned <= ack_returned;
    end
end

// rdata
always @(posedge clk_50K) begin
    if(~rstn) begin
        rdata <= 47'd0;
    end else if(i2c_state == I2C_START & expect_reponse) begin
        rdata <= 47'd0;
    end else if(i2c_state == I2C_READ & i2c_scl === 1'b1 & scl_reg == 2'b11) begin
        rdata <= {rdata[46:0], i2c_sda};
    end else begin
        rdata <= rdata;
    end
end

// rindex
always @(posedge clk_50K) begin
    if(~rstn) begin
        rindex <= 6'd0;
    end else if(i2c_state == I2C_START) begin
        rindex = 6'd0;
    end else if(i2c_state == I2C_READ & i2c_scl === 1'b1 & scl_reg == 2'b11) begin
        rindex <= rindex + 6'd1;
    end else begin
        rindex <= rindex;
    end
end

// i2c_state
always @(posedge clk_50K) begin
    if(~rstn) begin
        i2c_state <= I2C_IDLE;
    end else begin
        i2c_state <= next_i2c_state;
    end
end

// i2c_state
always @* begin
  case(i2c_state)
    I2C_IDLE   :
    if(start)                                                                next_i2c_state <= I2C_START;
    else                                                                     next_i2c_state <= I2C_IDLE;

    I2C_START :
    if(i2c_scl & ~i2c_sda)                                                   next_i2c_state <= I2C_WRITE;
    else                                                                     next_i2c_state <= I2C_START;

    I2C_WRITE:
    if(windex == 3'd0 & scl_reg == 2'b11)                                    next_i2c_state <= I2C_WAIT_ACK;
    else                                                                     next_i2c_state <= I2C_WRITE;

    I2C_WAIT_ACK :
    if(ack_returned & scl_reg == 2'b11 & ~last_wdata)                        next_i2c_state <= I2C_WRITE;
    else if (ack_returned & scl_reg == 2'b11 & last_wdata & ~expect_reponse) next_i2c_state <= I2C_STOP;
    else if (ack_returned & scl_reg == 2'b11 & last_wdata & expect_reponse)  next_i2c_state <= I2C_READ;
    else                                                                     next_i2c_state <= I2C_WAIT_ACK;

    I2C_READ :
    if((rindex & 6'h07) == 6'h07 & i2c_scl & scl_reg == 2'b11)               next_i2c_state <= I2C_SEND_ACK;
    else                                                                     next_i2c_state <= I2C_READ;

    I2C_SEND_ACK :
    if(i2c_scl === 1'b1 & scl_reg == 2'b11 & ~i2c_sda & rindex < 6'd47)      next_i2c_state <= I2C_READ;
    else if(i2c_scl === 1'b1 & scl_reg == 2'b11 & ~i2c_sda & rindex >= 6'd47)next_i2c_state <= I2C_STOP;
    else                                                                     next_i2c_state <= I2C_SEND_ACK;

    I2C_STOP :
    if(i2c_scl & i2c_sda)                                                    next_i2c_state <= I2C_IDLE;
    else                                                                     next_i2c_state <= I2C_STOP;

    default  :
    next_i2c_state <= I2C_IDLE;
    endcase
end

endmodule

