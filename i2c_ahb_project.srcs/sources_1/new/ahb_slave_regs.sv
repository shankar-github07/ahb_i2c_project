`timescale 1ns / 1ps

module ahb_slave_regs (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        HSEL,
    input  logic [31:0] HADDR,
    input  logic        HWRITE,
    input  logic [1:0]  HTRANS,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,

    output logic        start,
    input  logic        busy,
    input  logic        done,
    output logic [6:0]  addr,
    output logic [7:0]  data,
    output logic        rw
);

    logic [31:0] ctrl, status;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            ctrl <= 0;
            addr <= 0;
            data <= 0;
            rw   <= 0;
        end else if (HSEL && HWRITE && HTRANS[1]) begin
            case (HADDR[7:0])
                8'h00: ctrl <= HWDATA;
                8'h08: addr <= HWDATA[6:0];
                8'h0C: data <= HWDATA[7:0];
                8'h10: rw   <= HWDATA[0];
            endcase
        end
    end

    assign start = ctrl[1];

    always_comb begin
        status = 0;
        status[0] = busy;
        status[1] = done;
    end

    always_comb begin
        case (HADDR[7:0])
            8'h00: HRDATA = ctrl;
            8'h04: HRDATA = status;
            8'h08: HRDATA = {25'h0, addr};
            8'h0C: HRDATA = {24'h0, data};
            8'h10: HRDATA = {31'h0, rw};
            default: HRDATA = 0;
        endcase
    end
endmodule
