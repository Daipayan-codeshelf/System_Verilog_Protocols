// can_reg_if.v
module can_reg_if (
    input  wire        clk,
    input  wire        reset_n,

    // CPU Interface
    input  wire        cpu_wr_en,
    input  wire        cpu_rd_en,
    input  wire [7:0]  cpu_addr,
    input  wire [31:0] cpu_data_in,
    output reg  [31:0] cpu_data_out,

    // TX Interface
    output wire [10:0] tx_id,
    output wire [3:0]  tx_dlc,
    output wire [63:0] tx_data,
    output wire        tx_start,
    input  wire        tx_done,
    input  wire        arb_lost,
    input  wire        tx_no_ack,

    // RX Interface
    input  wire        rx_done,
    input  wire [10:0] rx_id,
    input  wire [3:0]  rx_dlc,
    input  wire [63:0] rx_data,
    input  wire        rx_crc_error,
    input  wire        rx_stuff_error,
    input  wire        rx_form_error,
    input  wire        rx_overflow,

    // Bus Status
    input  wire        bus_idle
);

    reg [10:0] tx_id_reg;
    reg [3:0]  tx_dlc_reg;
    reg [7:0]  tx_data_reg [0:7];

    reg [10:0] rx_id_reg;
    reg [3:0]  rx_dlc_reg;
    reg [7:0]  rx_data_reg [0:7];

    reg [7:0]  status_sticky; // W1C bits [7:0]
    reg        tx_start_pulse;

    integer i;

    assign tx_id  = tx_id_reg;
    assign tx_dlc = tx_dlc_reg;
    assign tx_data = {
        tx_data_reg[0], tx_data_reg[1], tx_data_reg[2], tx_data_reg[3],
        tx_data_reg[4], tx_data_reg[5], tx_data_reg[6], tx_data_reg[7]
    };
    assign tx_start = tx_start_pulse;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tx_id_reg      <= 0;
            tx_dlc_reg     <= 0;
            rx_id_reg      <= 0;
            rx_dlc_reg     <= 0;
            status_sticky  <= 8'd0;
            tx_start_pulse <= 1'b0;

            for (i = 0; i < 8; i = i + 1) begin
                tx_data_reg[i] <= 8'd0;
                rx_data_reg[i] <= 8'd0;
            end
        end else begin
            tx_start_pulse <= 1'b0;

            if (cpu_wr_en) begin
                case (cpu_addr)
                    8'h00: tx_id_reg       <= cpu_data_in[10:0];
                    8'h04: tx_dlc_reg      <= cpu_data_in[3:0];
                    8'h08: tx_data_reg[0]  <= cpu_data_in[7:0];
                    8'h0C: tx_data_reg[1]  <= cpu_data_in[7:0];
                    8'h10: tx_data_reg[2]  <= cpu_data_in[7:0];
                    8'h14: tx_data_reg[3]  <= cpu_data_in[7:0];
                    8'h18: tx_data_reg[4]  <= cpu_data_in[7:0];
                    8'h1C: tx_data_reg[5]  <= cpu_data_in[7:0];
                    8'h20: tx_data_reg[6]  <= cpu_data_in[7:0];
                    8'h24: tx_data_reg[7]  <= cpu_data_in[7:0];
                    8'h28: if (cpu_data_in[0]) tx_start_pulse <= 1'b1;
                    8'h2C: status_sticky    <= status_sticky & ~cpu_data_in[7:0];
                    default: ;
                endcase
            end

            if (tx_done)        status_sticky[0] <= 1'b1;
            if (rx_done)        status_sticky[1] <= 1'b1;
            if (tx_no_ack)      status_sticky[2] <= 1'b1;
            if (arb_lost)       status_sticky[3] <= 1'b1;
            if (rx_overflow)    status_sticky[4] <= 1'b1;
            if (rx_crc_error)   status_sticky[5] <= 1'b1;
            if (rx_stuff_error) status_sticky[6] <= 1'b1;
            if (rx_form_error)  status_sticky[7] <= 1'b1;

            if (rx_done) begin
                rx_id_reg  <= rx_id;
                rx_dlc_reg <= rx_dlc;

                rx_data_reg[0] <= rx_data[63:56];
                rx_data_reg[1] <= rx_data[55:48];
                rx_data_reg[2] <= rx_data[47:40];
                rx_data_reg[3] <= rx_data[39:32];
                rx_data_reg[4] <= rx_data[31:24];
                rx_data_reg[5] <= rx_data[23:16];
                rx_data_reg[6] <= rx_data[15:8];
                rx_data_reg[7] <= rx_data[7:0];
            end
        end
    end

    always @* begin
        cpu_data_out = 32'h0;
        if (cpu_rd_en) begin
            case (cpu_addr)
                8'h00: cpu_data_out = {21'b0, tx_id_reg};
                8'h04: cpu_data_out = {28'b0, tx_dlc_reg};
                8'h08: cpu_data_out = {24'b0, tx_data_reg[0]};
                8'h0C: cpu_data_out = {24'b0, tx_data_reg[1]};
                8'h10: cpu_data_out = {24'b0, tx_data_reg[2]};
                8'h14: cpu_data_out = {24'b0, tx_data_reg[3]};
                8'h18: cpu_data_out = {24'b0, tx_data_reg[4]};
                8'h1C: cpu_data_out = {24'b0, tx_data_reg[5]};
                8'h20: cpu_data_out = {24'b0, tx_data_reg[6]};
                8'h24: cpu_data_out = {24'b0, tx_data_reg[7]};
                8'h2C: cpu_data_out = {23'd0, bus_idle, status_sticky};
                8'h30: cpu_data_out = {21'b0, rx_id_reg};
                8'h34: cpu_data_out = {28'b0, rx_dlc_reg};
                8'h38: cpu_data_out = {24'b0, rx_data_reg[0]};
                8'h3C: cpu_data_out = {24'b0, rx_data_reg[1]};
                8'h40: cpu_data_out = {24'b0, rx_data_reg[2]};
                8'h44: cpu_data_out = {24'b0, rx_data_reg[3]};
                8'h48: cpu_data_out = {24'b0, rx_data_reg[4]};
                8'h4C: cpu_data_out = {24'b0, rx_data_reg[5]};
                8'h50: cpu_data_out = {24'b0, rx_data_reg[6]};
                8'h54: cpu_data_out = {24'b0, rx_data_reg[7]};
                default: cpu_data_out = 32'h0;
            endcase
        end
    end

endmodule
