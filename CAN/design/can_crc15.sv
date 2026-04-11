// can_crc15.v
module can_crc15 #(
    parameter [14:0] CRC_POLY        = 15'h4599,
    parameter [14:0] CRC_SEED        = 15'h7FFF,
    parameter        CRC_OUT_INVERT  = 1'b0
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        crc_init,
    input  wire        crc_enable,
    input  wire        crc_bit_in,
    output wire [14:0] crc_out
);

    reg [14:0] crc_reg;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            crc_reg <= CRC_SEED;
        end else if (crc_init) begin
            crc_reg <= CRC_SEED;
        end else if (crc_enable) begin
            if (crc_reg[14] ^ crc_bit_in)
                crc_reg <= {crc_reg[13:0], 1'b0} ^ CRC_POLY;
            else
                crc_reg <= {crc_reg[13:0], 1'b0};
        end
    end

    assign crc_out = CRC_OUT_INVERT ? ~crc_reg : crc_reg;

endmodule
