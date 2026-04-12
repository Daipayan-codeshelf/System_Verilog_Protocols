//////////////////////////////////////////////////////////////
// MMC CMD PHY
//
// FIXES:
//  - cmd_frame widened to [47:0]
//  - bit_cnt widened to [5:0], initialised to 47
//  - SEND_CMD: output bit then decrement; move to WAIT_RESP
//    only after bit 0 has been shifted out (bit_cnt already 0)
//  - WAIT_RESP: clear response_valid when entering state
//  - DONE: deassert cmd_done before returning to IDLE
//////////////////////////////////////////////////////////////


`timescale 1ns/1ps

module mmc_cmd_phy(

    input        clk,
    input        rst,

    input        cmd_start,
    input [47:0] cmd_frame,

    input        cmd_line,

    output reg   cmd_out,
    output reg   cmd_oe,

    output reg   cmd_done,
    output reg   response_valid,
    output reg   crc_error

);

//////////////////////////////////////////////////////////////
// REGISTERS
//////////////////////////////////////////////////////////////

reg [47:0] shift_reg;
reg [47:0] resp_shift;

reg [5:0] bit_cnt;
reg [2:0] state;

//////////////////////////////////////////////////////////////
// STATE MACHINE
//////////////////////////////////////////////////////////////

localparam IDLE      = 3'd0;
localparam SEND_CMD  = 3'd1;
localparam WAIT_RESP = 3'd2;
localparam RECV_RESP = 3'd3;
localparam DONE      = 3'd4;

//////////////////////////////////////////////////////////////
// CRC FUNCTION
//////////////////////////////////////////////////////////////

function [6:0] crc7_calc;

input [38:0] data;

integer i;
reg [6:0] crc;
reg inv;

begin

    crc = 7'd0;

    for(i=38;i>=0;i=i-1)
    begin

        inv = data[i] ^ crc[6];

        crc[6] = crc[5];
        crc[5] = crc[4];
        crc[4] = crc[3];
        crc[3] = crc[2] ^ inv;
        crc[2] = crc[1];
        crc[1] = crc[0];
        crc[0] = inv;

    end

    crc7_calc = crc;

end
endfunction

//////////////////////////////////////////////////////////////
// RESPONSE CRC WIRES
//////////////////////////////////////////////////////////////

wire [6:0] resp_crc;
wire [6:0] calc_crc;

assign resp_crc = resp_shift[7:1];
assign calc_crc = crc7_calc(resp_shift[46:8]);

//////////////////////////////////////////////////////////////
// FSM
//////////////////////////////////////////////////////////////

always @(posedge clk or posedge rst)
begin

    if(rst)
    begin

        state          <= IDLE;
        shift_reg      <= 0;
        resp_shift     <= 0;
        bit_cnt        <= 0;

        cmd_out        <= 1'b1;
        cmd_oe         <= 0;

        cmd_done       <= 0;
        response_valid <= 0;
        crc_error      <= 0;

    end

    else
    begin

        case(state)

        //////////////////////////////////////////////////////
        // IDLE
        //////////////////////////////////////////////////////

        IDLE:
        begin

            cmd_done       <= 0;
            response_valid <= 0;
            crc_error      <= 0;

            cmd_oe  <= 0;
            cmd_out <= 1;

            if(cmd_start)
            begin
                shift_reg <= cmd_frame;
                bit_cnt   <= 47;
                state     <= SEND_CMD;
            end

        end

        //////////////////////////////////////////////////////
        // SEND COMMAND
        //////////////////////////////////////////////////////

        SEND_CMD:
        begin

            cmd_oe  <= 1;
            cmd_out <= shift_reg[bit_cnt];

            if(bit_cnt == 0)
                state <= WAIT_RESP;
            else
                bit_cnt <= bit_cnt - 1;

        end

        //////////////////////////////////////////////////////
        // WAIT RESPONSE
        //////////////////////////////////////////////////////

        WAIT_RESP:
        begin

            cmd_oe  <= 0;
            cmd_out <= 1;

            if(cmd_line == 0)
            begin
                bit_cnt <= 47;
                state   <= RECV_RESP;
            end

        end

        //////////////////////////////////////////////////////
        // RECEIVE RESPONSE
        //////////////////////////////////////////////////////

        RECV_RESP:
        begin

            resp_shift[bit_cnt] <= cmd_line;

            if(bit_cnt == 0)
            begin
                response_valid <= 1;
                state <= DONE;
            end
            else
                bit_cnt <= bit_cnt - 1;

        end

        //////////////////////////////////////////////////////
        // DONE
        //////////////////////////////////////////////////////

        DONE:
        begin

            if(resp_crc != calc_crc)
            begin
                crc_error <= 1;
                $display("[%0t] MMC CRC ERROR DETECTED", $time);
            end
            else
            begin
                crc_error <= 0;
            end

            cmd_done <= 1;
            state    <= IDLE;

        end

        default:
            state <= IDLE;

        endcase

    end

end

endmodule
