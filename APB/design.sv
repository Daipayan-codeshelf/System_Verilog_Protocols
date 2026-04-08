// Code your design here
`timescale 1ns/1ps
module apb_bus_1m4s
#(
    parameter integer ADDR_W = 8,
    parameter integer DATA_W = 32,
    parameter integer SEL_HI = 7,
    parameter integer SEL_LO = 6,
    parameter integer S0_IDX = 0,
    parameter integer S1_IDX = 1,
    parameter integer S2_IDX = 2,
    parameter integer S3_IDX = 3
)
(
    input                       PCLK,
    input                       PRESETn,

    input                       M_PSEL,
    input                       M_PENABLE,
    input                       M_PWRITE,
    input      [ADDR_W-1:0]     M_PADDR,
    input      [DATA_W-1:0]     M_PWDATA,
    output reg [DATA_W-1:0]     M_PRDATA,
    output reg                  M_PREADY,
    output reg                  M_PSLVERR,

    output                      S_PENABLE,
    output                      S_PWRITE,
    output     [ADDR_W-1:0]     S_PADDR,
    output     [DATA_W-1:0]     S_PWDATA,

    output reg                  S0_PSEL,
    output reg                  S1_PSEL,
    output reg                  S2_PSEL,
    output reg                  S3_PSEL,

    input      [DATA_W-1:0]     S0_PRDATA,
    input      [DATA_W-1:0]     S1_PRDATA,
    input      [DATA_W-1:0]     S2_PRDATA,
    input      [DATA_W-1:0]     S3_PRDATA,

    input                       S0_PREADY,
    input                       S1_PREADY,
    input                       S2_PREADY,
    input                       S3_PREADY,

    input                       S0_PSLVERR,
    input                       S1_PSLVERR,
    input                       S2_PSLVERR,
    input                       S3_PSLVERR
);

    wire [SEL_HI-SEL_LO:0] idx;
    assign idx = M_PADDR[SEL_HI:SEL_LO];

    assign S_PENABLE = M_PENABLE;
    assign S_PWRITE  = M_PWRITE;
    assign S_PADDR   = M_PADDR;
    assign S_PWDATA  = M_PWDATA;

    always @(*) begin

        S0_PSEL = 0;
        S1_PSEL = 0;
        S2_PSEL = 0;
        S3_PSEL = 0;

        M_PRDATA  = 0;
        M_PREADY  = 0;
        M_PSLVERR = 0;

        if (M_PSEL) begin

            case (idx)
                S0_IDX: begin
                    S0_PSEL = 1;
                    M_PRDATA  = S0_PRDATA;
                    M_PREADY  = S0_PREADY;
                    M_PSLVERR = S0_PSLVERR;
                end
                S1_IDX: begin
                    S1_PSEL = 1;
                    M_PRDATA  = S1_PRDATA;
                    M_PREADY  = S1_PREADY;
                    M_PSLVERR = S1_PSLVERR;
                end
                S2_IDX: begin
                    S2_PSEL = 1;
                    M_PRDATA  = S2_PRDATA;
                    M_PREADY  = S2_PREADY;
                    M_PSLVERR = S2_PSLVERR;
                end
                S3_IDX: begin
                    S3_PSEL = 1;
                    M_PRDATA  = S3_PRDATA;
                    M_PREADY  = S3_PREADY;
                    M_PSLVERR = S3_PSLVERR;
                end
                default: begin
                    // No slave selected
                end
            endcase

        end
    end

endmodule


module apb_slave_simple
#(
    parameter integer ADDR_W      = 8,
    parameter integer DATA_W      = 32,
    parameter integer INDEX_W     = 4,
    parameter integer DEPTH       = 16,
    parameter integer WAIT_CYCLES = 0
)
(
    input                       PCLK,
    input                       PRESETn,
    input                       PSEL,
    input                       PENABLE,
    input      [ADDR_W-1:0]     PADDR,
    input                       PWRITE,
    input      [DATA_W-1:0]     PWDATA,
    output reg [DATA_W-1:0]     PRDATA,
    output reg                  PREADY,
    output                      PSLVERR
);

    reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [7:0] wait_cnt;
    wire [INDEX_W-1:0] index;

    assign index = PADDR[INDEX_W-1:0];
    assign PSLVERR = 1'b0;

    integer i;

    always @(posedge PCLK or negedge PRESETn)
    begin
        if (!PRESETn) begin
            PREADY   <= 0;
            PRDATA   <= 0;
            wait_cnt <= 0;
            for (i=0;i<DEPTH;i=i+1)
                mem[i] <= 0;
        end
        else begin
            PREADY <= 0;

            if (PSEL && PENABLE) begin
                if (wait_cnt < WAIT_CYCLES) begin
                    wait_cnt <= wait_cnt + 1;
                end
                else begin
                    PREADY <= 1;
                    wait_cnt <= 0;

                    if (PWRITE)
                        mem[index] <= PWDATA;
                    else
                        PRDATA <= mem[index];
                end
            end
            else begin
                wait_cnt <= 0;
            end
        end
    end

endmodule
