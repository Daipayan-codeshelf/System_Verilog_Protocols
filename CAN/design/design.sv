`include "can_reg_if.sv"
`include "can_tx.sv"
`include "can_rx.sv"
`include "can_crc15.sv"
`include "can_btu.sv"
`include "can_bus_if.sv"

module can_top (
    input  wire        clk,
    input  wire        reset_n,

    // CPU interface
    input  wire        cpu_wr_en,
    input  wire        cpu_rd_en,
    input  wire [7:0]  cpu_addr,
    input  wire [31:0] cpu_data_in,
    output wire [31:0] cpu_data_out,

    // Physical CAN pins
    input  wire        can_rx_i,
    output wire        can_tx_o,

    // Debug / TB outputs
    output wire        tx_done_o,
    output wire        rx_done_o,
    output wire [10:0] rx_id_o,
    output wire [3:0]  rx_dlc_o,
    output wire [63:0] rx_data_o,
    output wire        rx_crc_error_o,
    output wire        rx_stuff_error_o,
    output wire        rx_form_error_o,
  
    output wire [14:0] tx_crc_dbg_o,
    output wire [14:0] rx_crc_dbg_o,
    output wire        tx_busy_o,
    output wire        bit_tick_o
);

    // Internal wires
    wire bit_tick;
    wire sample_point;
    wire sof_detect;
    wire hard_resync;
    wire bus_idle;
    wire intermission_done;
    wire can_rx_sync;

    // TX
    wire [10:0] tx_id;
    wire [3:0]  tx_dlc;
    wire [63:0] tx_data;
    wire        tx_start;
    wire        tx_done;
    wire        arb_lost;
    wire        tx_no_ack;
    wire        tx_error;
    wire        tx_busy;
    wire        tx_data_bit;

    // TX CRC
    wire        tx_crc_init;
    wire        tx_crc_enable;
    wire        tx_crc_bit_in;
    wire [14:0] tx_crc_out;

    // RX
    wire [10:0] rx_id;
    wire [3:0]  rx_dlc;
    wire [63:0] rx_data;
    wire        rx_done;
    wire        ack_req;
    wire        rx_crc_error;
    wire        rx_stuff_error;
    wire        rx_form_error;

    // RX CRC
    wire        rx_crc_init;
    wire        rx_crc_enable;
    wire        rx_crc_bit_in;
    wire [14:0] rx_crc_out;

    wire ack_slot_o;
    wire in_ack_slot;

    // BUS INTERFACE
    can_bus_if u_bus_if (
        .clk(clk),
        .reset_n(reset_n),

        .can_rx_i(can_rx_i),
        .can_tx_o(can_tx_o),

        .bit_tick(bit_tick),
        .sample_point(sample_point),

        .tx_data_bit(tx_data_bit),
        .ack_req(ack_req),
        .in_ack_slot(in_ack_slot),

        .can_rx_sync(can_rx_sync)
    );

    // BIT TIMING UNIT
    can_btu u_btu (
        .clk(clk),
        .reset_n(reset_n),

        .can_rx_async(can_rx_sync),

        .bit_tick(bit_tick),
        .sample_point(sample_point),
        .sof_detect(sof_detect),
        .hard_resync(hard_resync),
        .bus_idle(bus_idle),
        .intermission_done(intermission_done)
    );

    // REGISTER INTERFACE
    can_reg_if u_regs (
        .clk(clk),
        .reset_n(reset_n),

        .cpu_wr_en(cpu_wr_en),
        .cpu_rd_en(cpu_rd_en),
        .cpu_addr(cpu_addr),
        .cpu_data_in(cpu_data_in),
        .cpu_data_out(cpu_data_out),

        .tx_id(tx_id),
        .tx_dlc(tx_dlc),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_done(tx_done),
        .arb_lost(arb_lost),
        .tx_no_ack(tx_no_ack),

        .rx_done(rx_done),
        .rx_id(rx_id),
        .rx_dlc(rx_dlc),
        .rx_data(rx_data),
        .rx_crc_error(rx_crc_error),
        .rx_stuff_error(rx_stuff_error),
        .rx_form_error(rx_form_error),

        .rx_overflow(1'b0),
        .bus_idle(bus_idle)
    );

    // CRC ENGINES
    can_crc15 u_crc_tx (
        .clk(clk),
        .reset_n(reset_n),
        .crc_init(tx_crc_init),
        .crc_enable(tx_crc_enable),
        .crc_bit_in(tx_crc_bit_in),
        .crc_out(tx_crc_out)
    );

    can_crc15 u_crc_rx (
        .clk(clk),
        .reset_n(reset_n),
        .crc_init(rx_crc_init),
        .crc_enable(rx_crc_enable),
        .crc_bit_in(rx_crc_bit_in),
        .crc_out(rx_crc_out)
    );

    // TRANSMITTER
    can_tx u_tx (
        .clk(clk),
        .reset_n(reset_n),

        .tx_start(tx_start),
        .id(tx_id),
        .dlc(tx_dlc),
        .data_in(tx_data),

        .bit_tick(bit_tick),
        .sample_point(sample_point),

        .can_rx(can_rx_sync),
        .can_tx(tx_data_bit),

        .tx_done(tx_done),
        .arb_lost(arb_lost),
        .tx_no_ack(tx_no_ack),
        .tx_error(tx_error),
        .tx_busy(tx_busy),

        .crc_init(tx_crc_init),
        .crc_enable(tx_crc_enable),
        .crc_bit_in(tx_crc_bit_in),
        .crc_out(tx_crc_out),

        .ack_slot_o(ack_slot_o)
    );

    assign in_ack_slot = ack_slot_o;

    // RECEIVER
    can_rx u_rx (
        .clk(clk),
        .reset_n(reset_n),

        .can_rx(can_rx_sync),
        .sample_point(sample_point),
        .sof_detect(sof_detect),

        .crc_out(rx_crc_out),
        .crc_init(rx_crc_init),
        .crc_enable(rx_crc_enable),
        .crc_bit_in(rx_crc_bit_in),

        .id_out(rx_id),
        .dlc_out(rx_dlc),
        .data_out(rx_data),

        .rx_done(rx_done),
        .ack_req(ack_req),

        .rx_crc_error(rx_crc_error),
        .rx_stuff_error(rx_stuff_error),
        .rx_form_error(rx_form_error)
    );

    // TB EXPORTS
    assign tx_done_o        = tx_done;
    assign rx_done_o        = rx_done;
    assign rx_id_o          = rx_id;
    assign rx_dlc_o         = rx_dlc;
    assign rx_data_o        = rx_data;
    assign rx_crc_error_o   = rx_crc_error;
    assign rx_stuff_error_o = rx_stuff_error;
    assign rx_form_error_o  = rx_form_error;

    assign tx_crc_dbg_o = tx_crc_out;
    assign rx_crc_dbg_o = rx_crc_out;
    assign tx_busy_o    = tx_busy;
    assign bit_tick_o   = bit_tick;

endmodule
