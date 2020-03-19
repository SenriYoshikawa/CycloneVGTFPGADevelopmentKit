module SHT30(
    input clk_50M,
    input rstn,    
    inout i2c_scl,
    inout i2c_sda,
    input [1:0] button,
    output reg [4:0] led,
    output [2:0] i2c_staten
);

wire clk_50K;
wire sda_valid;
reg [2:0] state;
reg [2:0] next_state;
parameter S_IDLE = 3'b000, S_SREQ = 3'b001, S_WAIT_DCLEAR_START = 3'b010, S_DCLEAR = 3'b011, S_WAIT_SREAD_START = 3'b100, S_SREAD = 3'b101, S_DWRITE = 3'b110;

wire [5:0] rindex;
wire [47:0] rdata;
reg [4:0] data_count;

wire [31:0] temp1 = 32'd175 * rdata[47:32];
wire [31:0] temp2 = temp1[31:16] - 16'd45;
wire [31:0] humi1 = 32'd100 * rdata[23:8];
wire [31:0] humi2 = humi1[31:16];
wire [15:0] temp_ten = temp2 / 16'd10;
wire [15:0] temp_one = temp2 % 16'd10;
wire [15:0] humi_ten = humi2 / 16'd10;
wire [15:0] humi_one = humi2 % 16'd10;

function [7:0]convert_for_lcd;
    input [3:0]data;
    
    case(data)
        4'h0: convert_for_lcd = 8'h30;
        4'h1: convert_for_lcd = 8'h31;
        4'h2: convert_for_lcd = 8'h32;
        4'h3: convert_for_lcd = 8'h33;
        4'h4: convert_for_lcd = 8'h34;
        4'h5: convert_for_lcd = 8'h35;
        4'h6: convert_for_lcd = 8'h36;
        4'h7: convert_for_lcd = 8'h37;
        4'h8: convert_for_lcd = 8'h38;
        4'h9: convert_for_lcd = 8'h39;
        4'ha: convert_for_lcd = 8'h61;
        4'hb: convert_for_lcd = 8'h62;
        4'hc: convert_for_lcd = 8'h63;
        4'hd: convert_for_lcd = 8'h64;
        4'he: convert_for_lcd = 8'h65;
        4'hf: convert_for_lcd = 8'h66;
        default: convert_for_lcd = 8'h20;
    endcase
    
endfunction

// 温湿度計測用データ
wire [4:0] data_sreq_number = 5'd3;
wire [7:0] data_sreq[2:0];
assign data_sreq[0]  = 8'h88; // address
assign data_sreq[1]  = 8'h2c; // clock stretching enabled
assign data_sreq[2]  = 8'h06; // high repeatability

// 温湿度読み出し用データ
wire [4:0] data_sread_number = 5'd1;
wire [7:0] data_sread = 8'h89;

// LCDクリア用データ
wire [4:0] data_dclear_number = 5'd3;
wire [7:0] data_dclear[2:0];
assign data_dclear[0]  = 8'h50; // address
assign data_dclear[1]  = 8'hfe; // Clear screen prefix
assign data_dclear[2]  = 8'h51; // Clear screen command

// LCD表示用データ
wire [4:0] data_dwrite_number = 5'd9;
wire [7:0] data_dwrite[8:0];
assign data_dwrite[0]  = 8'h50; // address
assign data_dwrite[1]  = {4'h3, temp_ten[3:0]}; // Temp
assign data_dwrite[2]  = {4'h3, temp_one[3:0]}; // Temp
assign data_dwrite[3]  = 8'hdf; // circle
assign data_dwrite[4]  = 8'h43; // C
assign data_dwrite[5]  = 8'h20; //
assign data_dwrite[6]  = {4'h3, humi_ten[3:0]}; // Humidity
assign data_dwrite[7]  = {4'h3, humi_one[3:0]}; // Humidity
assign data_dwrite[8]  = 8'h25; // %
// LCD表示生データ用
// wire [4:0] data_dwrite_number = 5'd13;
// wire [7:0] data_dwrite[12:0];
// assign data_dwrite[0]  = 8'h50; // address
// assign data_dwrite[1] = convert_for_lcd(rdata[47:44]);
// assign data_dwrite[2] = convert_for_lcd(rdata[43:40]);
// assign data_dwrite[3] = convert_for_lcd(rdata[39:36]);
// assign data_dwrite[4] = convert_for_lcd(rdata[35:32]);
// assign data_dwrite[5] = convert_for_lcd(rdata[31:28]);
// assign data_dwrite[6] = convert_for_lcd(rdata[27:24]);
// assign data_dwrite[7] = convert_for_lcd(rdata[23:20]);
// assign data_dwrite[8] = convert_for_lcd(rdata[19:16]);
// assign data_dwrite[9] = convert_for_lcd(rdata[15:12]);
// assign data_dwrite[10] = convert_for_lcd(rdata[11:8]);
// assign data_dwrite[11] = convert_for_lcd(rdata[7:4]);
// assign data_dwrite[12] = convert_for_lcd(rdata[3:0]);


wire [7:0] wdata = state == S_SREQ ? data_sreq[data_count] : 
                    state == S_DCLEAR ? data_dclear[data_count] :
                    state == S_DWRITE ? data_dwrite[data_count] : 
                    data_sread;
wire [4:0] data_number = state == S_SREQ ? data_sreq_number : 
                    state == S_DCLEAR ? data_dclear_number :
                    state == S_DWRITE ? data_dwrite_number :
                    data_sread_number;

reg [1:0] sreq_buf;
wire sreq_start = sreq_buf == 2'b01;
reg [9:0] wait_count;
wire sread_start = wait_count == 10'd1023;
wire dclear_start = state == S_WAIT_DCLEAR_START & data_count == 4'd0 & i2c_state == 3'b000;
wire dwrite_start = state == S_DWRITE & data_count == 4'd0;

wire start = sreq_start | sread_start | dwrite_start | dclear_start;

wire ack_returned;
reg ack_returned_buf;
wire ack_returned_edge = {ack_returned_buf, ack_returned} == 2'b01;

wire [2:0] i2c_state;
assign i2c_staten = ~i2c_state;

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

    .start(start),
    .wdata(wdata),
    .last_wdata(data_count >= data_number - 5'd1),
    .expect_reponse(state == S_SREAD),

    .sda_valid(sda_valid),
    .ack_returned(ack_returned),

    .rindex(rindex),
    .rdata(rdata),
    .i2c_state(i2c_state)
);


// sreq_buf
always @(posedge clk_50K) begin
    sreq_buf <= {sreq_buf[0], button[0]};
end

// wait_count
always @(posedge clk_50K) begin
    if(~rstn) begin
        wait_count <= 10'd0;
    end else if(state != S_WAIT_SREAD_START) begin
        wait_count <= 10'd0;
    end else if(state == S_WAIT_SREAD_START) begin
        wait_count <= wait_count + 10'd1;
    end
end

// ack_returned_buf
always @(posedge clk_50K) begin
    ack_returned_buf <= ack_returned;
end

// led
always @(posedge clk_50K) begin
    if(~rstn) begin
        led <= 5'b11111;
    end else begin
        // led <= {~state, ~sda_valid, ~ack_returned};
        led <= {~state, ~i2c_scl, ~i2c_sda};
    end
end

// data_count
always @(posedge clk_50K) begin
    if(~rstn) begin
        data_count <= 5'd0;
    end else if(state != S_DWRITE & state != S_SREQ & state != S_DCLEAR) begin
        data_count <= 5'd0;
    end else if(ack_returned_edge) begin
        data_count <= data_count + 5'd1;
    end else begin
        data_count <= data_count;
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
    if(sreq_start)                next_state <= S_SREQ;
    else                          next_state <= S_IDLE;

    S_SREQ :
    if(data_count >= data_number) next_state <= S_WAIT_DCLEAR_START;
    else                          next_state <= S_SREQ;

    S_WAIT_DCLEAR_START :
    if(dclear_start)              next_state <= S_DCLEAR;
    else                          next_state <= S_WAIT_DCLEAR_START;

    S_DCLEAR :
    if(data_count >= data_number) next_state <= S_WAIT_SREAD_START;
    else                          next_state <= S_DCLEAR;

    S_WAIT_SREAD_START :
    if(sread_start)               next_state <= S_SREAD;
    else                          next_state <= S_WAIT_SREAD_START;

    S_SREAD :
    if(rindex >= 6'd48)           next_state <= S_DWRITE;
    else                          next_state <= S_SREAD;

    S_DWRITE :
    if(data_count >= data_number) next_state <= S_IDLE;
    else                          next_state <= S_DWRITE;

    default  :
    next_state <= S_IDLE;
    endcase
end

endmodule
