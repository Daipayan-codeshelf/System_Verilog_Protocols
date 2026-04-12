//////////////////////////////////////////////////////////////
// CRC16
//
// No functional change — port interface unchanged.
// Minor: use localparam, fix bit_cnt to [3:0] (counts 8..1)
//////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module crc16(

    input        clk,
    input        rst,

    input  [7:0] data_in,
    input        enable,

    output reg [15:0] crc_out

);

reg [15:0] crc;
reg [3:0]  bit_cnt;
reg [7:0]  data_reg;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        crc     <= 16'd0;
        crc_out <= 16'd0;
        bit_cnt <= 0;
        data_reg<= 0;
    end
    else if(enable)
    begin
        data_reg <= data_in;
        bit_cnt  <= 4'd8;
    end
    else if(bit_cnt != 0)
    begin
        begin : crc16_calc
            reg inv;
            inv      = data_reg[bit_cnt-1] ^ crc[15];
            crc[15]  <= crc[14];
            crc[14]  <= crc[13];
            crc[13]  <= crc[12];
            crc[12]  <= crc[11] ^ inv;
            crc[11]  <= crc[10];
            crc[10]  <= crc[9];
            crc[9]   <= crc[8];
            crc[8]   <= crc[7];
            crc[7]   <= crc[6];
            crc[6]   <= crc[5];
            crc[5]   <= crc[4] ^ inv;
            crc[4]   <= crc[3];
            crc[3]   <= crc[2];
            crc[2]   <= crc[1];
            crc[1]   <= crc[0];
            crc[0]   <= inv;
        end

        bit_cnt <= bit_cnt - 1;
    end
    else
        crc_out <= crc;
end

endmodule
