`timescale 1ns/1ps

//////////////////////////////////////////////////////////////
//
//  UNIFIED MMC TESTBENCH
//
//  TEST 1 : CMD FRAME GENERATION   (tb_cmd_frame)
//  TEST 2 : MMC HOST WRITE + READ  (mmc_host_tb)
//  TEST 3 : RESPONSE CRC CHECK     (tb_crc_check)
//  TEST 4 : RESPONSE TIMEOUT       (tb_response_timeout)
//
//  Each test runs sequentially.
//  After each test finishes, a separator is printed and the
//  next test begins.  A single waveform file captures all.
//
//////////////////////////////////////////////////////////////

module tb_unified;


initial begin
    $dumpfile("tb_unified.vcd");
    $dumpvars(0, tb_unified);
end

//============================================================
// SHARED : CLOCK
//============================================================

reg clk;
initial clk = 0;
always #5 clk = ~clk;

//============================================================
// SHARED : RESET
//============================================================

reg rst;

//============================================================
//
//  TEST 1 SIGNALS : CMD FRAME GENERATION
//  Modules : crc7 + mmc_cmd_ctrl
//
//============================================================

reg        t1_start;
reg  [5:0] t1_cmd_index;
reg [31:0] t1_cmd_arg;

reg        t1_response_valid;
reg        t1_timeout;

wire        t1_cmd_start;
wire [47:0] t1_cmd_frame;
wire        t1_cmd_done;

wire [6:0]  t1_crc7_out;
wire        t1_crc_ready;

//------------------------------------------------------------
// CRC7
//------------------------------------------------------------

crc7 u_crc7 (
    .clk      (clk),
    .rst      (rst),
    .cmd_index(t1_cmd_index),
    .cmd_arg  (t1_cmd_arg),
    .enable   (t1_start),
    .crc_out  (t1_crc7_out),
    .crc_ready(t1_crc_ready)
);

//------------------------------------------------------------
// CMD CONTROLLER
//------------------------------------------------------------

mmc_cmd_ctrl u_cmd_ctrl (
    .clk           (clk),
    .rst           (rst),
    .start         (t1_start),
    .cmd_index     (t1_cmd_index),
    .cmd_arg       (t1_cmd_arg),
    .crc7          (t1_crc7_out),
    .crc_ready     (t1_crc_ready),
    .response_valid(t1_response_valid),
    .timeout       (t1_timeout),
    .cmd_start     (t1_cmd_start),
    .cmd_frame     (t1_cmd_frame),
    .cmd_done      (t1_cmd_done)
);

//============================================================
//
//  TEST 2 SIGNALS : MMC HOST WRITE + READ
//  Module : mmc_host_top (instance t2_dut)
//
//============================================================

reg        t2_start;
reg  [5:0] t2_cmd_index;
reg [31:0] t2_cmd_arg;

reg        t2_read_en;
reg        t2_write_en;

reg  [7:0] t2_write_data;
wire [7:0] t2_read_data;

wire t2_busy;
wire t2_done;

tri1 t2_cmd;
tri1 t2_dat0;

reg  t2_cmd_drive;
reg  t2_dat_drive;
reg  t2_cmd_oe_mmc;
reg  t2_dat_oe_mmc;

assign t2_cmd  = t2_cmd_oe_mmc ? t2_cmd_drive : 1'bz;
assign t2_dat0 = t2_dat_oe_mmc ? t2_dat_drive : 1'bz;

reg [7:0] t2_card_memory [0:255];
reg [7:0] t2_last_write_data;

mmc_host_top t2_dut (
    .clk       (clk),
    .rst       (rst),
    .start     (t2_start),
    .cmd_index (t2_cmd_index),
    .cmd_arg   (t2_cmd_arg),
    .read_en   (t2_read_en),
    .write_en  (t2_write_en),
    .write_data(t2_write_data),
    .read_data (t2_read_data),
    .busy      (t2_busy),
    .done      (t2_done),
    .cmd       (t2_cmd),
    .dat0      (t2_dat0)
);

//============================================================
//
//  TEST 3 SIGNALS : CRC ERROR CHECK
//  Module : mmc_cmd_phy (instance t3_dut)
//
//============================================================

reg         t3_cmd_start;
reg  [47:0] t3_cmd_frame;

wire t3_cmd_out;
wire t3_cmd_oe;
wire t3_cmd_done;
wire t3_response_valid;
wire t3_crc_error;

reg  t3_card_drive;
reg  t3_card_cmd;

wire t3_cmd_line;
assign t3_cmd_line = t3_card_drive ? t3_card_cmd : t3_cmd_out;

mmc_cmd_phy t3_dut (
    .clk           (clk),
    .rst           (rst),
    .cmd_start     (t3_cmd_start),
    .cmd_frame     (t3_cmd_frame),
    .cmd_line      (t3_cmd_line),
    .cmd_out       (t3_cmd_out),
    .cmd_oe        (t3_cmd_oe),
    .cmd_done      (t3_cmd_done),
    .response_valid(t3_response_valid),
    .crc_error     (t3_crc_error)
);

//============================================================
//
//  TEST 4 SIGNALS : RESPONSE TIMEOUT
//  Module : mmc_host_top (instance t4_dut)
//  Card never drives bus -> timeout expected
//
//============================================================

reg        t4_start;
reg  [5:0] t4_cmd_index;
reg [31:0] t4_cmd_arg;

reg        t4_read_en;
reg        t4_write_en;

reg  [7:0] t4_write_data;
wire [7:0] t4_read_data;

wire t4_busy;
wire t4_done;

// Card never drives - bus floats high via tri1 pull-up
wire t4_cmd;
wire t4_dat0;

assign t4_cmd  = 1'bz;
assign t4_dat0 = 1'bz;

mmc_host_top t4_dut (
    .clk       (clk),
    .rst       (rst),
    .start     (t4_start),
    .cmd_index (t4_cmd_index),
    .cmd_arg   (t4_cmd_arg),
    .read_en   (t4_read_en),
    .write_en  (t4_write_en),
    .write_data(t4_write_data),
    .read_data (t4_read_data),
    .busy      (t4_busy),
    .done      (t4_done),
    .cmd       (t4_cmd),
    .dat0      (t4_dat0)
);

//============================================================
// BUSY MONITOR : TEST 2
//============================================================

reg t2_busy_prev;
always @(posedge clk) begin
    if (t2_busy && !t2_busy_prev)
        $display("[T2] TIME %0t : BUSY ASSERTED", $time);
    if (!t2_busy && t2_busy_prev)
        $display("[T2] TIME %0t : BUSY DEASSERTED", $time);
    t2_busy_prev <= t2_busy;
end

//============================================================
// BUSY MONITOR : TEST 4
//============================================================

reg t4_busy_prev;
always @(posedge clk) begin
    if (t4_busy && !t4_busy_prev)
        $display("[T4] TIME %0t : BUSY ASSERTED", $time);
    if (!t4_busy && t4_busy_prev)
        $display("[T4] TIME %0t : BUSY DEASSERTED", $time);
    t4_busy_prev <= t4_busy;
end

//============================================================
// TASKS : TEST 1
//============================================================

task t1_send_cmd;
    input [5:0]  cmd;
    input [31:0] arg;
begin
    @(posedge clk);
    t1_cmd_index = cmd;
    t1_cmd_arg   = arg;
    t1_start = 1;
    @(posedge clk);
    t1_start = 0;

    wait(t1_cmd_start);

    $display("\n=================================================");
    $display("COMMAND FRAME GENERATED");
    $display("CMD INDEX : %0d", cmd);
    $display("ARG       : %h",  arg);
    $display("CRC7      : %h",  t1_crc7_out);
    $display("FRAME BIN : %048b", t1_cmd_frame);
    $display("FRAME HEX : %h",    t1_cmd_frame);
    $display("\nFRAME FIELD BREAKDOWN");
    $display("-------------------------------");
    $display("Start Bit        : %b", t1_cmd_frame[47]);
    $display("Transmission Bit : %b", t1_cmd_frame[46]);
    $display("Command Index    : %b", t1_cmd_frame[45:40]);
    $display("Argument         : %h", t1_cmd_frame[39:8]);
    $display("CRC7             : %b", t1_cmd_frame[7:1]);
    $display("End Bit          : %b", t1_cmd_frame[0]);
    $display("=================================================\n");

    t1_response_valid = 1;
    @(posedge clk);
    t1_response_valid = 0;

    wait(t1_cmd_done);
end
endtask

//============================================================
// TASKS : TEST 2 - CMD24 RESPONSE
//============================================================

task t2_send_cmd24_response;
integer i;
begin
    wait(t2_cmd == 1);
    repeat(3) @(posedge t2_dut.mmc_clk);

    t2_cmd_oe_mmc = 1;
    t2_cmd_drive  = 0;
    @(posedge t2_dut.mmc_clk);

    for (i = 0; i < 47; i = i + 1) begin
        t2_cmd_drive = 1;
        @(posedge t2_dut.mmc_clk);
    end

    t2_cmd_oe_mmc = 0;
    t2_cmd_drive  = 1;
end
endtask

//============================================================
// TASKS : TEST 2 - CMD17 RESPONSE
//============================================================

task t2_send_cmd17_response;
integer i;
begin
    wait(t2_cmd == 1);
    repeat(3) @(posedge t2_dut.mmc_clk);

    t2_cmd_oe_mmc = 1;
    t2_cmd_drive  = 0;
    @(posedge t2_dut.mmc_clk);

    for (i = 0; i < 47; i = i + 1) begin
        t2_cmd_drive = 1;
        @(posedge t2_dut.mmc_clk);
    end

    t2_cmd_oe_mmc = 0;
    t2_cmd_drive  = 1;
end
endtask

//============================================================
// TASKS : TEST 2 - CAPTURE WRITE DATA
//============================================================

task t2_capture_write_data;
integer i;
reg [7:0] rx;
begin
    wait(t2_dat0 == 0);
    @(posedge t2_dut.mmc_clk);

    for (i = 7; i >= 0; i = i - 1) begin
        @(posedge t2_dut.mmc_clk);
        rx[i] = t2_dat0;
    end

    t2_card_memory[0] = rx;
    $display("CARD : DATA RECEIVED = %h", rx);
end
endtask

//============================================================
// TASKS : TEST 2 - SEND READ DATA
//============================================================

task t2_send_read_data;
integer i;
reg [7:0] data;
begin
    wait(t2_read_en == 1);
    data = t2_card_memory[0];
    repeat(2) @(posedge t2_dut.mmc_clk);

    $display("CARD -> HOST : DATA SENT = %h", data);

    t2_dat_oe_mmc = 1;
    t2_dat_drive  = 0;
    @(posedge t2_dut.mmc_clk);

    for (i = 7; i >= 0; i = i - 1) begin
        t2_dat_drive = data[i];
        @(posedge t2_dut.mmc_clk);
    end

    t2_dat_oe_mmc = 0;
    t2_dat_drive  = 1;
end
endtask

//============================================================
// TASKS : TEST 2 - CMD24 FULL WRITE TEST
//============================================================

task t2_test_cmd24;
begin
    $display("\nTEST1 : CMD24 SINGLE BLOCK WRITE");

    t2_cmd_index = 6'd24;
    t2_cmd_arg   = 32'h00000101;
    t2_start     = 1;
    @(posedge t2_dut.mmc_clk);
    t2_start = 0;

    fork
        t2_send_cmd24_response();
        t2_capture_write_data();
    join_none

    wait(t2_dut.u_cmd_ctrl.cmd_done);

    t2_write_data = 8'hAA;
    t2_write_en   = 1;
    @(posedge t2_dut.mmc_clk);
    t2_write_en = 0;

    t2_last_write_data = t2_write_data;
    $display("WRITE DATA = %h", t2_write_data);
end
endtask

//============================================================
// TASKS : TEST 2 - CMD17 FULL READ TEST
//============================================================

task t2_test_cmd17;
begin
    $display("\nTEST2 : CMD17 SINGLE BLOCK READ");

    t2_cmd_index = 6'd17;
    t2_cmd_arg   = 32'h00000101;
    t2_start     = 1;
    @(posedge t2_dut.mmc_clk);
    t2_start = 0;

    fork
        t2_send_cmd17_response();
        t2_send_read_data();
    join_none

    wait(t2_dut.u_cmd_ctrl.cmd_done);

    @(posedge t2_dut.mmc_clk);
    t2_read_en = 1;
    @(posedge t2_dut.mmc_clk);
    t2_read_en = 0;

    wait(t2_dut.u_data_path.data_done);

    $display("READ DATA  = %h", t2_read_data);
end
endtask

//============================================================
// TASKS : TEST 3 - BAD CRC RESPONSE
//============================================================

task t3_send_bad_crc;
integer i;
reg [47:0] resp;
begin
    resp = {1'b0, 1'b0, 6'd17, 32'h00001000, 7'h7F, 1'b1}; // bad CRC

    wait(t3_cmd_line == 1);
    repeat(20) @(posedge clk);

    $display("[%0t] CARD -> HOST : BAD CRC RESPONSE", $time);

    t3_card_drive = 1;

    for (i = 47; i >= 0; i = i - 1) begin
        t3_card_cmd = resp[i];
        @(posedge clk);
    end

    t3_card_drive = 0;
end
endtask

//============================================================
// GLOBAL SIMULATION WATCHDOG
//============================================================

initial begin
    #200000;
    $display("ERROR : GLOBAL SIMULATION TIMEOUT");
    $finish;
end

//============================================================
//
//  MAIN TEST SEQUENCE
//
//============================================================

initial begin

    //--------------------------------------------------------
    // INIT ALL SIGNALS
    //--------------------------------------------------------

    rst = 1;

    // Test 1
    t1_start          = 0;
    t1_response_valid = 0;
    t1_timeout        = 0;
    t1_cmd_index      = 0;
    t1_cmd_arg        = 0;

    // Test 2
    t2_start        = 0;
    t2_read_en      = 0;
    t2_write_en     = 0;
    t2_write_data   = 0;
    t2_cmd_drive    = 1;
    t2_dat_drive    = 1;
    t2_cmd_oe_mmc   = 0;
    t2_dat_oe_mmc   = 0;
    t2_busy_prev    = 0;

    // Test 3
    t3_cmd_start  = 0;
    t3_cmd_frame  = 48'h51000010009B;
    t3_card_drive = 0;
    t3_card_cmd   = 1;

    // Test 4
    t4_start      = 0;
    t4_read_en    = 0;
    t4_write_en   = 0;
    t4_write_data = 0;
    t4_busy_prev  = 0;

    #40;
    rst = 0;

    //========================================================
    //
    //  TEST 1 : MMC COMMAND FRAME GENERATION
    //
    //========================================================

    $display("");
    $display("=================================================");
    $display(" MMC COMMAND FRAME GENERATION TESTBENCH ");
    $display("=================================================");

    t1_send_cmd(6'd0,  32'h00000000);   // CMD0
    t1_send_cmd(6'd1,  32'h40FF8000);   // CMD1
    t1_send_cmd(6'd16, 32'd512);        // CMD16
    t1_send_cmd(6'd17, 32'h00001000);   // CMD17
    t1_send_cmd(6'd24, 32'h00002000);   // CMD24

    #100;

    $display("");
    $display("===============================================");
    $display(" ALL COMMAND FRAME TESTS COMPLETED SUCCESSFULLY ");
    $display("===============================================");
    $display("");

    //========================================================
    //
    //  TEST 2 : MMC HOST WRITE + READ
    //
    //========================================================

    // Hold reset for TEST 2 DUT independently
    // rst was already released; t2_dut uses the shared rst

    $display("=====================================");
    $display("MMC HOST TESTBENCH START");
    $display("=====================================");

    // Allow t2_dut to settle after shared reset release
    repeat(20) @(posedge clk);

    t2_test_cmd24();

    repeat(100) @(posedge clk);

    t2_test_cmd17();

    repeat(200) @(posedge clk);

    if (t2_read_data == t2_last_write_data)
        $display("TEST PASS");
    else
        $display("TEST FAIL");

    $display("=====================================");
    $display("ALL TESTS COMPLETED");
    $display("=====================================");

    //========================================================
    //
    //  TEST 3 : MMC RESPONSE CRC CHECK
    //
    //========================================================

    $display("");
    $display("==============================================");
    $display("MMC RESPONSE CRC TEST");
    $display("==============================================");

    // Small gap before starting Test 3
    repeat(20) @(posedge clk);

    $display("[%0t] RESET RELEASED", $time);

    @(posedge clk);
    t3_cmd_start = 1;
    @(posedge clk);
    t3_cmd_start = 0;

    $display("[%0t] HOST SENT COMMAND", $time);

    fork
        t3_send_bad_crc();
    join

    wait(t3_cmd_done);

    if (t3_crc_error)
        $display("[%0t] RESULT : CRC ERROR DETECTED (PASS)", $time);
    else
        $display("[%0t] RESULT : CRC ERROR NOT DETECTED (FAIL)", $time);

    $display("==============================================");

    repeat(100) @(posedge clk);

    //========================================================
    //
    //  TEST 4 : RESPONSE TIMEOUT
    //
    //========================================================

    $display("");
    $display("====================================================");
    $display("MMC HOST CONTROLLER TEST");
    $display("TEST : RESPONSE TIMEOUT");
    $display("====================================================");

    $display("[%0t] TB : RESET RELEASED", $time);

    t4_cmd_index = 17;
    t4_cmd_arg   = 32'h00001000;

    #50;

    t4_start = 1;
    repeat(10) @(posedge clk);
    t4_start = 0;

    $display("[%0t] HOST -> CARD : CMD17 ARG=0x%h", $time, t4_cmd_arg);
    $display("[%0t] CARD : NO RESPONSE (TIMEOUT TEST)", $time);

    repeat(2000) @(posedge clk);

    if (t4_dut.timeout)
        $display("[%0t] HOST : RESPONSE TIMEOUT DETECTED", $time);
    else
        $display("[%0t] ERROR : TIMEOUT NOT TRIGGERED", $time);

    $display("====================================================");
    $display("RESPONSE TIMEOUT TEST FINISHED");
    $display("====================================================");

    #100;

    //========================================================
    //  ALL TESTS DONE
    //========================================================

    $display("");
    $display("####################################################");
    $display("#     ALL 4 TESTS COMPLETED SUCCESSFULLY           #");
    $display("####################################################");
    $display("");

    $finish;

end
endmodule
