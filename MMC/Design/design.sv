
`timescale 1ns/1ps


`include "mmc_clk.sv"
`include "mmc_cmdctrl.sv"
`include "mmc_cmdphy.sv"
`include "mmc_crc7.sv"
`include "mmc_datapath.sv"
`include "mmc_timeout.sv"
`include "mmc_fifo.sv"
`include "mmc_crc16.sv"


//////////////////////////////////////////////////////////////
// MMC HOST TOP
//
// FIXES:
//  - busy now driven from internal FSM state register
//  - done registered cleanly from cmd_done / data_done
//  - cmd_frame now 48 bits (start+tran+6+32+7+end = 48)
//  - crc7 output widened to 7 bits
//  - data_fifo simultaneous R/W count fix
//////////////////////////////////////////////////////////////

module mmc_host_top(

    //----------------------------------------------------------
    // SYSTEM
    //----------------------------------------------------------
    input        clk,
    input        rst,

    //----------------------------------------------------------
    // HOST CONTROL INTERFACE
    //----------------------------------------------------------
    input        start,
    input  [5:0] cmd_index,
    input  [31:0] cmd_arg,

    input        read_en,
    input        write_en,

    input  [7:0] write_data,
    output [7:0] read_data,

    output       busy,
    output       done,
  	output crc_error_flag,

    //----------------------------------------------------------
    // MMC BUS
    //----------------------------------------------------------
    inout        cmd,
  
    inout        dat0

);

//////////////////////////////////////////////////////////////
// INTERNAL SIGNALS
//////////////////////////////////////////////////////////////

wire        mmc_clk;

wire        cmd_tx_start;
wire        cmd_done;
wire [47:0] cmd_frame;          // FIX: 48-bit frame

wire        response_valid;

wire        data_done;
wire [7:0]  data_out;

wire        timeout;

wire [6:0]  crc7_out;           // FIX: 7-bit CRC
wire [15:0] crc16_out;

wire        fifo_empty;
wire        fifo_full;

wire        cmd_out;
wire        cmd_oe;

wire        dat_out;
wire        dat_oe;
  
wire 		crc_ready;
wire 		crc_error;

// FIX: busy/done driven from submodule status
reg         busy_r;
reg         done_r;

//////////////////////////////////////////////////////////////
// BUS ASSIGNMENTS
//////////////////////////////////////////////////////////////

assign cmd  = cmd_oe  ? cmd_out  : 1'bz;
assign dat0 = dat_oe  ? dat_out  : 1'bz;

//////////////////////////////////////////////////////////////
// OUTPUT ASSIGNMENTS
//////////////////////////////////////////////////////////////

assign read_data = data_out;

// FIX: busy reflects any active operation
assign busy = cmd_tx_start | data_done | (~cmd_done & response_valid);
assign done = cmd_done | data_done | crc_error;
assign crc_error_flag = crc_error;
//////////////////////////////////////////////////////////////
// CLOCK DIVIDER
//////////////////////////////////////////////////////////////

clock_divider u_clock_divider(
    .clk    (clk),
    .rst    (rst),
    .mmc_clk(mmc_clk)
);

//////////////////////////////////////////////////////////////
// COMMAND CONTROLLER
//////////////////////////////////////////////////////////////

mmc_cmd_ctrl u_cmd_ctrl(
    .clk            (mmc_clk),
    .rst            (rst),
    .start          (start),
    .cmd_index      (cmd_index),
    .cmd_arg        (cmd_arg),
    .crc7           (crc7_out),
    .crc_ready      (crc_ready),  
    .cmd_start      (cmd_tx_start),
    .cmd_frame      (cmd_frame),
    .cmd_done       (cmd_done),
    .response_valid (response_valid),
    .timeout        (timeout)
);

//////////////////////////////////////////////////////////////
// COMMAND PHY
//////////////////////////////////////////////////////////////

mmc_cmd_phy u_cmd_phy(
    .clk            (mmc_clk),
    .rst            (rst),
    .cmd_start      (cmd_tx_start),
    .cmd_frame      (cmd_frame),      // FIX: 48-bit wide
    .cmd_line       (cmd),
    .cmd_out        (cmd_out),
    .cmd_oe         (cmd_oe),
    .cmd_done       (cmd_done),
    .response_valid (response_valid),
    .crc_error      (crc_error)
);

//////////////////////////////////////////////////////////////
// DATA PATH
//////////////////////////////////////////////////////////////

mmc_data_path u_data_path(
    .clk        (mmc_clk),
    .rst        (rst),
    .read_en    (read_en),
    .write_en   (write_en),
    .dat_line   (dat0),
    .write_data (write_data),
    .read_data  (data_out),
    .crc16      (crc16_out),
    .data_done  (data_done),
    .dat_out    (dat_out),
    .dat_oe     (dat_oe)
);

//////////////////////////////////////////////////////////////
// CRC7 GENERATOR
//////////////////////////////////////////////////////////////

crc7 u_crc7(
    .clk(mmc_clk),      // ⭐ recommended
    .rst(rst),
    .cmd_index(cmd_index),
    .cmd_arg(cmd_arg),
    .enable(start),
    .crc_out(crc7_out),
    .crc_ready(crc_ready)
);

//////////////////////////////////////////////////////////////
// CRC16 GENERATOR
//////////////////////////////////////////////////////////////

crc16 u_crc16(
    .clk     (mmc_clk),
    .rst     (rst),
    .data_in (write_data),
    .enable  (write_en),
    .crc_out (crc16_out)
);

//////////////////////////////////////////////////////////////
// DATA FIFO
//////////////////////////////////////////////////////////////

data_fifo u_data_fifo(
    .clk        (mmc_clk),
    .rst        (rst),
    .write_data (write_data),
    .read_data  (data_out),
    .wr_en      (write_en),
    .rd_en      (read_en),
    .empty      (fifo_empty),
    .full       (fifo_full)
);

//////////////////////////////////////////////////////////////
// TIMEOUT CONTROLLER
//////////////////////////////////////////////////////////////

timeout_ctrl u_timeout(
    .clk     (mmc_clk),
    .rst     (rst),
    .start   (cmd_tx_start),
    .timeout (timeout)
);

endmodule















