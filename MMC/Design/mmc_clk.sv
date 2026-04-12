//////////////////////////////////////////////////////////////
// CLOCK DIVIDER — unchanged, correct as-is
//////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module clock_divider(

    input      clk,
    input      rst,

    output reg mmc_clk

);

localparam DIV = 4;

reg [7:0] counter;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        counter  <= 0;
        mmc_clk  <= 0;
    end
    else
    begin
        if(counter == (DIV-1))
        begin
            counter <= 0;
            mmc_clk <= ~mmc_clk;
        end
        else
            counter <= counter + 1;
    end
end

endmodule
