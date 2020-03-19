`timescale 1ns/1ps

module test_SHT30;

/* 各種定数 */
localparam integer STEP  = 20;
localparam integer KSTEP  = 20000;

/* システムクロックおよびリセット */
reg         clk_50M;
reg         rstn;
reg [1:0]  button;
wire [4:0] led;
wire [2:0] i2c_state;
wire       i2c_scl;
wire       i2c_sda;
reg        sda;
reg        sda_out;
assign i2c_sda = sda_out ? sda : 1'bz;

/* 各種クロック */
always begin
    clk_50M = 0; #(STEP/2);
    clk_50M = 1; #(STEP/2);
end

SHT30 SHT30(
    .clk_50M(clk_50M),
    .rstn(rstn),
    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda),
    .button(button),
    .led(led),
    .i2c_state(i2c_state)
);

initial begin
    rstn = 1'b1;
    sda_out = 1'b0;
    #KSTEP;
    rstn = 1'b0;
    button = 2'b11;
    #KSTEP;
    rstn = 1'b1;
    #KSTEP;
    button = 2'b10;
    #KSTEP;
    button = 2'b11;
    #33000;
    #(KSTEP*4); // START
    #(KSTEP*4); // WRITE 0
    #(KSTEP*4); // WRITE 1
    #(KSTEP*4); // WRITE 2
    #(KSTEP*4); // WRITE 3
    #(KSTEP*4); // WRITE 4
    #(KSTEP*4); // WRITE 5
    #(KSTEP*4); // WRITE 6
    #(KSTEP*4); // WRITE 7
    sda_out = 1'b1;
    sda = 1'b0;
    #(KSTEP*4); // ACK
    sda_out = 1'b0;
    sda = 1'b1;
    #(KSTEP*4); // WRITE 0
    #(KSTEP*4); // WRITE 1
    #(KSTEP*4); // WRITE 2
    #(KSTEP*4); // WRITE 3
    #(KSTEP*4); // WRITE 4
    #(KSTEP*4); // WRITE 5
    #(KSTEP*4); // WRITE 6
    #(KSTEP*4); // WRITE 7
    sda_out = 1'b1;
    sda = 1'b0;
    #(KSTEP*4); // ACK
    sda = 1'b1;
    sda_out = 1'b0;
    #(KSTEP*4); // WRITE 0
    #(KSTEP*4); // WRITE 1
    #(KSTEP*4); // WRITE 2
    #(KSTEP*4); // WRITE 3
    #(KSTEP*4); // WRITE 4
    #(KSTEP*4); // WRITE 5
    #(KSTEP*4); // WRITE 6
    #(KSTEP*4); // WRITE 7
    sda_out = 1'b1;
    sda = 1'b0;
    #(KSTEP*4); // 
    sda = 1'b1;
    sda_out = 1'b0;
    #(KSTEP*4); // STOP;
    #(KSTEP*4);
    $finish;
end

endmodule