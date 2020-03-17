module PushButtonLED(
    input clk,
    input rstn,
    input [1:0] button,
    output reg [1:0] led
);

// led
always @(posedge clk) begin
    if(~rstn) begin
        led <= 2'b11;
    end else begin
        led <= button;
    end
end

endmodule