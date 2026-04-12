//////////////////////////////////////////////////////////////
// TIMEOUT CTRL — unchanged, correct as-is
//////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module timeout_ctrl(

    input      clk,
    input      rst,

    input      start,

    output reg timeout

);

localparam TIMEOUT_LIMIT = 100;

reg [15:0] counter;
reg        running;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        counter <= 0;
        timeout <= 0;
        running <= 0;
    end
    else
    begin
        if(start)
        begin
            counter <= 0;
            timeout <= 0;
            running <= 1;
        end
        else if(running)
        begin
            if(counter < TIMEOUT_LIMIT)
                counter <= counter + 1;
            else
            begin
                timeout <= 1;
                running <= 0;
            end
        end
    end
end

endmodule
