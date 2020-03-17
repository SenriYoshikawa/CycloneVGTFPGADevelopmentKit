module LCD(
    input clk_50M,
    input rstn,    
    inout i2c_scl,
    inout i2c_sda,
    input [1:0] button,
    output reg [2:0] led
);

wire clk_50K;
wire sda_valid;
reg mode;
reg [3:0] data_count;
wire [3:0] data_clear_number = 4'd3;
wire [3:0] data_hello_number = 4'd14;
wire [7:0] data_clear[2:0];
assign data_clear[0]  = 8'h50; // address
assign data_clear[1]  = 8'hfe; // Clear screen prefix
assign data_clear[2]  = 8'h51; // Clear screen command
wire [7:0] data_hello[13:0];
assign data_hello[0]  = 8'h50; // address
assign data_hello[1]  = 8'h48; // H
assign data_hello[2]  = 8'h65; // e
assign data_hello[3]  = 8'h6c; // l
assign data_hello[4]  = 8'h6c; // l
assign data_hello[5]  = 8'h6f; // o
assign data_hello[6]  = 8'h2c; // ,
assign data_hello[7]  = 8'h20; // 
assign data_hello[8]  = 8'h77; // w
assign data_hello[9]  = 8'h6f; // o
assign data_hello[10] = 8'h72; // r
assign data_hello[11] = 8'h6c; // l
assign data_hello[12] = 8'h64; // d
assign data_hello[13] = 8'h21; // !
wire [7:0] data = mode ? data_hello[data_count] : data_clear[data_count];
wire [3:0] data_number = mode ? data_hello_number : data_clear_number;

reg [1:0] hello_buf;
wire hello_start = hello_buf == 2'b01;
reg [1:0] clear_buf;
wire clear_start = clear_buf == 2'b01;

wire ack_returned;
reg ack_returned_buf;
wire ack_returned_edge = {ack_returned_buf, ack_returned} == 2'b01;

Clk50K iClk50K(
    .clk_50M(clk_50M),
    .rstn(rstn),
    .clk_50K(clk_50K)
);

I2CControl iI2CControl(
    .clk_50K(clk_50K),
    .rstn(rstn),
    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda),

    .start(hello_start | clear_start),
    .data(data),
    .last_data(data_count >= data_number),

    .sda_valid(sda_valid),
    .ack_returned(ack_returned)
);

// mode
always @(posedge clk_50K) begin
    if(~rstn) begin
        mode <= 1'b0;
    end else if(clear_start) begin
        mode <= 1'b0;
    end else if(hello_start) begin
        mode <= 1'b1;
    end else begin
        mode <= mode;
    end
end

// clear_buf
always @(posedge clk_50K) begin
    clear_buf <= {clear_buf[0], button[0]};
end

// hello_buf
always @(posedge clk_50K) begin
    hello_buf <= {hello_buf[0], button[1]};
end

// ack_returned_buf
always @(posedge clk_50K) begin
    ack_returned_buf <= ack_returned;
end

// led
always @(posedge clk_50K) begin
    if(~rstn) begin
        led <= 3'b111;
    end else begin
        led <= {~mode, ~sda_valid, ~ack_returned};
    end
end

// data_count
always @( posedge clk_50K ) begin
    if(~rstn) begin
        data_count <= 4'd0;
    end else if(hello_start | clear_start) begin
        data_count <= 4'd0;
    end else if(ack_returned_edge) begin
        data_count <= data_count + 4'd1;
    end else begin
        data_count <= data_count;
    end
end

endmodule
