//can_bus_if.v
module can_bus_if (
    input  wire clk,
    input  wire reset_n,

    input  wire can_rx_i,
    output reg  can_tx_o,

    input  wire bit_tick,
    input  wire sample_point,

    input  wire tx_data_bit,

    input  wire ack_req,

    input  wire in_ack_slot,

    output wire can_rx_sync
);

    assign can_rx_sync = can_rx_i;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            can_tx_o <= 1'b1;
        end else begin
            if (in_ack_slot) begin
                can_tx_o <= (ack_req ? 1'b0 : 1'b1);
            end else begin
                can_tx_o <= tx_data_bit;
            end
        end
    end

endmodule
