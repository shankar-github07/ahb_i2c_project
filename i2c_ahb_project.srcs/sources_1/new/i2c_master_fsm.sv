`timescale 1ns / 1ps

module i2c_master_fsm (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic [6:0] addr,
    input  logic [7:0] data_in,
    input  logic       rw,
    output logic       busy,
    output logic       done,
    output logic       scl,
    inout  wire        sda
);

    logic sda_out, sda_oe;
    assign sda = sda_oe ? sda_out : 1'bz;

    typedef enum logic [2:0] {IDLE, START, ADDR, DATA, STOP} state_t;
    state_t state;
    
    assign scl = clk; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sda_out <= 1'b1;
            sda_oe <= 1'b0;
            busy <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        busy <= 1;
                        state <= START;
                    end
                end
                START: begin
                    sda_oe <= 1;
                    sda_out <= 0;
                    state <= ADDR;
                end
                ADDR: begin
                    state <= DATA;
                end
                DATA: begin
                    state <= STOP;
                end
                STOP: begin
                    sda_out <= 1;
                    sda_oe <= 0;
                    busy <= 0;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule