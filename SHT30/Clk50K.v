module Clk50K(
    input clk_50M,
    input rstn,
    output reg clk_50K
);

reg [1:0] rstn_buf;
reg [9:0] count_50K;

// rstn_buf
always @(posedge clk_50M) begin
    rstn_buf <= {rstn_buf[0], rstn};
end

// count_50K
always @(posedge clk_50M) begin
    if(rstn_buf == 2'b10) begin
        count_50K <= 0;
    end else if(count_50K >= 499) begin
        count_50K <= 0;
    end else begin
        count_50K <= count_50K + 10'd1;
    end
end

// clk_50K
always @(posedge clk_50M) begin
    if(rstn_buf == 2'b10) begin
        clk_50K <= 1'b0;
    end else if(count_50K >= 499) begin
        clk_50K <= ~clk_50K;
    end else begin
        clk_50K <= clk_50K;
    end
end

endmodule