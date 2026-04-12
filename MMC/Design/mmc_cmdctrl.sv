//////////////////////////////////////////////////////////////
// MMC CMD CTRL
//
// FIXES:
//  - crc7 port widened to [6:0]
//  - cmd_frame widened to [47:0] (48 bits):
//    {start(1), tran(1), cmd_index(6), cmd_arg(32), crc7(7), end(1)} = 48
//////////////////////////////////////////////////////////////



module mmc_cmd_ctrl(

    input clk,
    input rst,

    input start,
    input [5:0] cmd_index,
    input [31:0] cmd_arg,

    input [6:0] crc7,
    input crc_ready,

    input response_valid,
    input timeout,

    output reg cmd_start,
    output reg [47:0] cmd_frame,
    output reg cmd_done

);

reg [2:0] state;

localparam IDLE       = 0;
localparam WAIT_CRC   = 1;
localparam SEND_CMD   = 2;
localparam WAIT_RESP  = 3;
localparam DONE       = 4;
localparam TIMEOUT_ST = 5;

always @(posedge clk or posedge rst)
begin

    if(rst)
    begin
        state <= IDLE;
        cmd_start <= 0;
        cmd_done <= 0;
        cmd_frame <= 0;
    end

    else
    begin
        // Default assignments every clock cycle
        cmd_start <= 0;
        cmd_done  <= 0;

        case(state)

        IDLE:
        begin
            if(start)
                state <= WAIT_CRC;
        end


        WAIT_CRC:
        begin
            if(crc_ready)
            begin
                cmd_frame <= {1'b0,1'b1,cmd_index,cmd_arg,crc7,1'b1};
                state <= SEND_CMD;
            end
        end


        SEND_CMD:
        begin
            cmd_start <= 1;
            state <= WAIT_RESP;
        end


        WAIT_RESP:
        begin
            if(response_valid)
                state <= DONE;

            else if(timeout)
                state <= TIMEOUT_ST;
        end


        DONE:
        begin
            cmd_done <= 1;
            state <= IDLE;
        end


        TIMEOUT_ST:
        begin
            cmd_done <= 1;
            state <= IDLE;
        end

        endcase

    end

end

endmodule
