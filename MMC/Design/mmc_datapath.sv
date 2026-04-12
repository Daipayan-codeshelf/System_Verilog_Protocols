
//////////////////////////////////////////////////////////////
// MMC DATA PATH
//
// FIXES:
//  - READ_RX: capture read_data with the final bit included
//    by latching shift_reg one cycle after bit_cnt hits 0
//  - bit_cnt is [2:0] (counts 7..0 for 8 bits)
//////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module mmc_data_path(

    input        clk,
    input        rst,

    input        read_en,
    input        write_en,

    input        dat_line,

    output reg   dat_out,
    output reg   dat_oe,

    input  [7:0] write_data,
    output reg [7:0] read_data,

    input  [15:0] crc16,

    output reg   data_done

);

reg [7:0] shift_reg;
reg [2:0] bit_cnt;   // FIX: 3-bit — counts 7 downto 0
reg [2:0] state;

localparam IDLE     = 3'd0;
localparam WRITE_ST = 3'd1;
localparam WRITE_TX = 3'd2;
localparam READ_ST  = 3'd3;
localparam READ_RX  = 3'd4;
localparam DONE     = 3'd5;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        state     <= IDLE;
        dat_out   <= 1'b1;
        dat_oe    <= 0;
        data_done <= 0;
        shift_reg <= 0;
        bit_cnt   <= 0;
        read_data <= 0;
    end
    else
    begin
        case(state)

        IDLE:
        begin
            data_done <= 0;
            dat_oe    <= 0;

            if(write_en)
            begin
                shift_reg <= write_data;
                bit_cnt   <= 3'd7;
                state     <= WRITE_ST;
            end
            else if(read_en)
            begin
                bit_cnt   <= 3'd7;
                shift_reg <= 8'd0;
                state     <= READ_ST;
            end
        end

        WRITE_ST:
        begin
            dat_oe  <= 1;
            dat_out <= 0;   // start bit
            state   <= WRITE_TX;
        end

        WRITE_TX:
        begin
            dat_out <= shift_reg[bit_cnt];

            if(bit_cnt == 0)
                state <= DONE;
            else
                bit_cnt <= bit_cnt - 1;
        end

        READ_ST:
        begin
            if(dat_line == 0)   // start bit detected
                state <= READ_RX;
        end

        // FIX: sample into shift_reg; on last bit latch read_data
        READ_RX:
        begin
            shift_reg[bit_cnt] <= dat_line;

            if(bit_cnt == 0)
            begin
                read_data <= {shift_reg[7:1], dat_line}; // include final bit
                state     <= DONE;
            end
            else
                bit_cnt <= bit_cnt - 1;
        end

        DONE:
        begin
            dat_oe    <= 0;
            data_done <= 1;
            state     <= IDLE;
        end

        default:
            state <= IDLE;

        endcase
    end
end

endmodule
