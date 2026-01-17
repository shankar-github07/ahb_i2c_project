`timescale 1ns / 1ps
module ahb_i2c_top (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        HSEL,
    input  logic [31:0] HADDR,
    input  logic        HWRITE,
    input  logic [1:0]  HTRANS,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic        HREADYOUT,
    output logic        HRESP,
    output logic        scl,
    inout  wire         sda
);

    logic start_pulse;
    logic busy, done;
    logic [6:0] addr;
    logic [7:0] data;
    logic rw;

    ahb_slave_regs u_regs (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HSEL(HSEL), .HADDR(HADDR), .HWRITE(HWRITE),
        .HTRANS(HTRANS), .HWDATA(HWDATA),
        .HRDATA(HRDATA),
        .start(start_pulse),
        .busy(busy), .done(done),
        .addr(addr), .data(data), .rw(rw)
    );

    i2c_master_fsm u_i2c (
        .clk(HCLK), .rst_n(HRESETn),
        .start(start_pulse),
        .addr(addr),
        .data_in(data),
        .rw(rw),
        .busy(busy),
        .done(done),
        .scl(scl),
        .sda(sda)
    );

    assign HREADY    = 1'b1;
    assign HREADYOUT = 1'b1;
    assign HRESP     = 1'b0;

endmodule