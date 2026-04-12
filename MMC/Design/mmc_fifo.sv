//////////////////////////////////////////////////////////////
// DATA FIFO
//
// FIX: simultaneous read + write both updated count correctly
//      using a combined always block with priority encoding
//////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module data_fifo(

    input        clk,
    input        rst,

    input  [7:0] write_data,
    output reg [7:0] read_data,

    input        wr_en,
    input        rd_en,

    output       empty,
    output       full

);

localparam DEPTH = 16;

reg [7:0] fifo_mem [0:DEPTH-1];

reg [3:0] wr_ptr;
reg [3:0] rd_ptr;
reg [4:0] count;

assign empty = (count == 0);
assign full  = (count == DEPTH);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        wr_ptr    <= 0;
        rd_ptr    <= 0;
        count     <= 0;
        read_data <= 0;
    end
    else
    begin
        // FIX: handle simultaneous R+W — count stays same in that case
        case({wr_en & ~full, rd_en & ~empty})
            2'b10: count <= count + 1;
            2'b01: count <= count - 1;
            2'b11: count <= count;     // simultaneous R+W — no change
            default: ;
        endcase

        if(wr_en && !full)
        begin
            fifo_mem[wr_ptr] <= write_data;
            wr_ptr <= wr_ptr + 1;
        end

        if(rd_en && !empty)
        begin
            read_data <= fifo_mem[rd_ptr];
            rd_ptr    <= rd_ptr + 1;
        end
    end
end

endmodule
