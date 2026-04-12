//////////////////////////////////////////////////////////////
// CRC7
//
// FIXES:
//  - crc_out widened to [6:0] — outputs full 7-bit CRC
//  - crc_out latched correctly from full crc register
//  - data_stream bit-width fixed: tran(1)+index(6)+arg(32)=39 bits
//    indexed [38:0], MSB = bit 38
//////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module crc7(

    input        clk,
    input        rst,

    input  [5:0] cmd_index,
    input  [31:0] cmd_arg,

    input        enable,

    output reg [6:0] crc_out,
    output reg       crc_ready

);

reg [6:0]  crc;
reg [38:0] data_stream;
reg [5:0]  bit_cnt;
reg        active;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        crc         <= 0;
        crc_out     <= 0;
        crc_ready   <= 0;
        active      <= 0;
        bit_cnt     <= 0;
    end

    else if(enable)
    begin
        data_stream <= {1'b1,cmd_index,cmd_arg};
        crc         <= 0;
        bit_cnt     <= 6'd38;
        active      <= 1;
        crc_ready   <= 0;
    end

    else if(active)
    begin

        reg inv;

        inv    = data_stream[bit_cnt] ^ crc[6];

        crc[6] <= crc[5];
        crc[5] <= crc[4];
        crc[4] <= crc[3];
        crc[3] <= crc[2] ^ inv;
        crc[2] <= crc[1];
        crc[1] <= crc[0];
        crc[0] <= inv;

        if(bit_cnt == 0)
        begin
            crc_out   <= crc;
            crc_ready <= 1;
            active    <= 0;
        end
        else
            bit_cnt <= bit_cnt - 1;

    end
end

endmodule
