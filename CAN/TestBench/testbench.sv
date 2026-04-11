//Testbench

module tb_can_top;

  reg clk = 0;
  always #5 clk = ~clk;  // 100 MHz
  reg reset_n = 0;

  reg         cpu_wr_en   = 0;
  reg         cpu_rd_en   = 0;
  reg  [7:0]  cpu_addr    = 0;
  reg  [31:0] cpu_data_in = 0;
  wire [31:0] cpu_data_out;

  wire can_rx_i;
  wire can_tx_o;

  // Internal loopback for single node
  assign can_rx_i = can_tx_o;

  wire        tx_done_o;
  wire        rx_done_o;
  wire [10:0] rx_id_o;
  wire [3:0]  rx_dlc_o;
  wire [63:0] rx_data_o;
  wire        rx_crc_error_o;
  wire        rx_stuff_error_o;
  wire        rx_form_error_o;

  wire [14:0] tx_crc_dbg_o;
  wire [14:0] rx_crc_dbg_o;
  wire        tx_busy_o;
  wire        bit_tick_o;

  can_top dut (
    .clk(clk),
    .reset_n(reset_n),

    .cpu_wr_en(cpu_wr_en),
    .cpu_rd_en(cpu_rd_en),
    .cpu_addr(cpu_addr),
    .cpu_data_in(cpu_data_in),
    .cpu_data_out(cpu_data_out),

    .can_rx_i(can_rx_i),
    .can_tx_o(can_tx_o),

    .tx_done_o(tx_done_o),
    .rx_done_o(rx_done_o),
    .rx_id_o(rx_id_o),
    .rx_dlc_o(rx_dlc_o),
    .rx_data_o(rx_data_o),
    .rx_crc_error_o(rx_crc_error_o),
    .rx_stuff_error_o(rx_stuff_error_o),
    .rx_form_error_o(rx_form_error_o),

    .tx_crc_dbg_o(tx_crc_dbg_o),
    .rx_crc_dbg_o(rx_crc_dbg_o),
    .tx_busy_o(tx_busy_o),
    .bit_tick_o(bit_tick_o)
  );

  task cpu_write;
    input [7:0]  addr;
    input [31:0] data;
  begin
    @(posedge clk);
    cpu_wr_en   <= 1'b1;
    cpu_addr    <= addr;
    cpu_data_in <= data;
    @(posedge clk);
    cpu_wr_en   <= 1'b0;
  end
  endtask

  task cpu_read;
    input  [7:0]  addr;
    output [31:0] data;
  begin
    @(posedge clk);
    cpu_rd_en <= 1'b1;
    cpu_addr  <= addr;
    @(posedge clk);
    data      = cpu_data_out;
    cpu_rd_en <= 1'b0;
  end
  endtask

  localparam [7:0] REG_TX_ID     = 8'h00;
  localparam [7:0] REG_TX_DLC    = 8'h04;
  localparam [7:0] REG_TX_D0     = 8'h08;
  localparam [7:0] REG_TX_D1     = 8'h0C;
  localparam [7:0] REG_TX_D2     = 8'h10;
  localparam [7:0] REG_TX_D3     = 8'h14;
  localparam [7:0] REG_TX_CMD    = 8'h28; // bit0: TX_START
  localparam [7:0] REG_STATUS    = 8'h2C; 
  localparam [7:0] REG_RX_ID     = 8'h30;
  localparam [7:0] REG_RX_DLC    = 8'h34;
  localparam [7:0] REG_RX_D0     = 8'h38;
  localparam [7:0] REG_RX_D1     = 8'h3C;
  localparam [7:0] REG_RX_D2     = 8'h40;
  localparam [7:0] REG_RX_D3     = 8'h44;

  localparam [31:0] W1C_ALL      = 32'hFFFF_FFFF;
  localparam [31:0] W1C_RX_DONE  = 32'h0000_0004;  
  localparam integer TIMEOUT_CYC = 200000;

  // Bit positions
  localparam integer BIT_TX_NO_ACK = 2;
  localparam integer BIT_BUS_IDLE  = 8;

  integer tx_to, rx_to, bi_to;
  reg [31:0] id_rd, dlc_rd, rxd0, rxd1, rxd2, rxd3, status_rd, status_after;

  initial begin
    $display("==== CAN LOOPBACK TEST (DLC=4, DATA=12 34 56 78) ====");

    reset_n = 0;
    repeat (10) @(posedge clk);
    reset_n = 1;
    $display("[%0t] Reset released", $time);

    // Program TX: ID=0x123, DLC=4, DATA0..3 = 78 56 34 12
    cpu_write(REG_TX_ID,  32'h0000_0123);
    cpu_write(REG_TX_DLC, 32'h0000_0004);
    cpu_write(REG_TX_D0,  32'h0000_0078);
    cpu_write(REG_TX_D1,  32'h0000_0056);
    cpu_write(REG_TX_D2,  32'h0000_0034);
    cpu_write(REG_TX_D3,  32'h0000_0012);

    // Clear all stickies; start TX
    cpu_write(REG_STATUS, W1C_ALL);
    cpu_write(REG_TX_CMD, 32'h0000_0001); // TX_START

    // Wait TX done
    tx_to = 0;
    while (tx_done_o !== 1'b1 && tx_to < 50000) begin
      @(posedge clk);
      tx_to = tx_to + 1;
    end
    if (tx_to >= 50000) begin
      $display("ERROR: TX timeout");
      $finish;
    end
    $display("[%0t] TX DONE", $time);

    // Wait RX done
    rx_to = 0;
    while (rx_done_o !== 1'b1 && rx_to < 80000) begin
      @(posedge clk);
      rx_to = rx_to + 1;
    end
    if (rx_to >= 80000) begin
      $display("ERROR: RX timeout");
      $finish;
    end
    $display("[%0t] RX DONE", $time);
    @(posedge clk);

    
    cpu_read(REG_RX_ID,  id_rd);
    cpu_read(REG_RX_DLC, dlc_rd);
    cpu_read(REG_RX_D0,  rxd0);
    cpu_read(REG_RX_D1,  rxd1);
    cpu_read(REG_RX_D2,  rxd2);
    cpu_read(REG_RX_D3,  rxd3);

    cpu_write(REG_STATUS, W1C_RX_DONE);
    
    
    cpu_read(REG_STATUS, status_rd);
    $display("[%0t] STATUS snapshot right after RX reads: 0x%08h  (BUS_IDLE=%0d TX_NO_ACK=%0d)",
             $time, status_rd, status_rd[BIT_BUS_IDLE], status_rd[BIT_TX_NO_ACK]);

    bi_to = 0;
    while (status_rd[BIT_BUS_IDLE] !== 1'b1 && bi_to < TIMEOUT_CYC) begin
      cpu_read(REG_STATUS, status_rd);
      bi_to = bi_to + 1;
    end
    if (bi_to >= TIMEOUT_CYC) begin
      $display("ERROR: BUS_IDLE did not become 1 within timeout");
    end else begin
      $display("[%0t] BUS_IDLE observed high at 0x2C: 0x%08h", $time, status_rd);
    end

    $display("CPU READBACK (via cpu_data_out):");
    $display("  RX_ID      = 0x%03h", id_rd[10:0]);
    $display("  RX_DLC     = %0d",     dlc_rd[3:0]);
    $display("  RX_DATA[0] = 0x%02h",  rxd0[7:0]);
    $display("  RX_DATA[1] = 0x%02h",  rxd1[7:0]);
    $display("  RX_DATA[2] = 0x%02h",  rxd2[7:0]);
    $display("  RX_DATA[3] = 0x%02h",  rxd3[7:0]);

    // Self-Checks
    if (dlc_rd[3:0] !== 4'd4) begin
      $display("ERROR: DLC mismatch (got %0d, expected 4)", dlc_rd[3:0]);
      $finish;
    end
    if (rxd0[7:0] !== 8'h78 || rxd1[7:0] !== 8'h56 ||
        rxd2[7:0] !== 8'h34 || rxd3[7:0] !== 8'h12) begin
      $display("ERROR: RX data mismatch (expected 78 56 34 12 in RX_DATA[0..3])");
      $finish;
    end

    // Error
    if (status_rd[BIT_TX_NO_ACK])
         $display("WARNING: TX_NO_ACK set (no ACK seen)");
    else $display("ACK: Dominant ACK observed (TX_NO_ACK=0)");

    if (rx_crc_error_o)   $display("ERROR: CRC error detected");
    if (rx_stuff_error_o) $display("ERROR: Stuff error detected");
    if (rx_form_error_o)  $display("ERROR: Form error detected");

    $display("==== TEST COMPLETE ====");
    #200;
    $finish;
  end

  // Wave dump
  wire        w00_clk         = clk;
  wire        w01_reset_n     = reset_n;
  wire        w02_cpu_wr_en   = cpu_wr_en;
  wire        w03_cpu_rd_en   = cpu_rd_en;
  wire [7:0]  w04_cpu_addr    = cpu_addr;
  wire [31:0] w05_cpu_data_in = cpu_data_in;
  wire [31:0] w06_cpu_data_out= cpu_data_out;
  wire        w07_can_tx_o    = can_tx_o;
  wire        w08_can_rx_i    = can_rx_i;
  wire [10:0] w09_tx_id       = dut.tx_id;
  wire [3:0]  w10_tx_dlc      = dut.tx_dlc;
  wire [63:0] w11_tx_data     = dut.tx_data;
  wire        w12_tx_busy     = tx_busy_o;
  wire        w13_tx_done     = tx_done_o;
  wire        w14_rx_done     = rx_done_o;
  wire        w15_rx_crc_err  = rx_crc_error_o;
  wire        w16_rx_stuff_err= rx_stuff_error_o;
  wire        w17_rx_form_err = rx_form_error_o;
  wire [10:0] w18_rx_id       = rx_id_o;
  wire [3:0]  w19_rx_dlc      = rx_dlc_o;
  wire [63:0] w20_rx_data     = rx_data_o;
  wire        w21_bit_tick    = bit_tick_o;
  wire [14:0] w22_tx_crc      = tx_crc_dbg_o;
  wire [14:0] w23_rx_crc      = rx_crc_dbg_o;

  initial begin
    $timeformat(-9, 0, " ns", 10);
    $dumpfile("can_wave.vcd");
    $dumpvars(0,tb_can_top,
      tb_can_top.w00_clk,
      tb_can_top.w01_reset_n,
      tb_can_top.w02_cpu_wr_en,
      tb_can_top.w03_cpu_rd_en,
      tb_can_top.w04_cpu_addr,
      tb_can_top.w05_cpu_data_in,
      tb_can_top.w06_cpu_data_out,
      tb_can_top.w07_can_tx_o,
      tb_can_top.w08_can_rx_i,
      tb_can_top.w09_tx_id,
      tb_can_top.w10_tx_dlc,
      tb_can_top.w11_tx_data,
      tb_can_top.w12_tx_busy,
      tb_can_top.w13_tx_done,
      tb_can_top.w14_rx_done,
      tb_can_top.w15_rx_crc_err,
      tb_can_top.w16_rx_stuff_err,
      tb_can_top.w17_rx_form_err,
      tb_can_top.w18_rx_id,
      tb_can_top.w19_rx_dlc,
      tb_can_top.w20_rx_data,
      tb_can_top.w21_bit_tick,
      tb_can_top.w22_tx_crc,
      tb_can_top.w23_rx_crc
    );
  end

  reg wr_q, rd_q, tx_done_q, rx_done_q;
  initial begin wr_q=0; rd_q=0; tx_done_q=0; rx_done_q=0; end
  always @(posedge clk) begin
    wr_q      <= cpu_wr_en;
    rd_q      <= cpu_rd_en;
    tx_done_q <= tx_done_o;
    rx_done_q <= rx_done_o;
  end

  initial begin
    $display("");
    $display("===============================================================================================");
    $display("    Time  block(ns)    | Event              | Details");
    $display("===============================================================================================");
  end

  always @(posedge clk) begin
    if (!wr_q && cpu_wr_en) begin
      $display("%8t  %-8s | %-18s | addr=0x%02h        din=0x%08h",
               $time, "CPU", "WRITE", cpu_addr, cpu_data_in);
    end
    if (!rd_q && cpu_rd_en) begin
      $display("%8t  %-8s | %-18s | addr=0x%02h        dout=0x%08h",
               $time, "CPU", "READ", cpu_addr, cpu_data_out);
    end
  end

  reg saw_tx_start;
  initial saw_tx_start = 1'b0;

  always @(posedge clk) begin
    if (!wr_q && cpu_wr_en && cpu_addr == REG_TX_CMD && cpu_data_in[0]) begin
      saw_tx_start <= 1'b1;
      $display("%8t  %-8s | %-18s | id=0x%03h       dlc=%0d            data0=0x%02h",
               $time, "TX", "START", w09_tx_id, w10_tx_dlc, w11_tx_data[63:56]);
    end
    if (!tx_done_q && tx_done_o)
      saw_tx_start <= 1'b0;
  end

  always @(posedge clk) begin
    if (!tx_done_q && tx_done_o) begin
      $display("%8t  %-8s | %-18s | id=0x%03h       dlc=%0d            crc=0x%04h",
               $time, "TX", "DONE", w09_tx_id, w10_tx_dlc, {1'b0, tx_crc_dbg_o});
    end
  end

  always @(posedge clk) begin
    if (!rx_done_q && rx_done_o) begin
      $display("%8t  %-8s | %-18s | id=0x%03h       dlc=%0d            data0=0x%02h   crc=0x%04h",
               $time, "RX", "DONE", rx_id_o, rx_dlc_o, rx_data_o[63:56], {1'b0, rx_crc_dbg_o});
      if (rx_crc_error_o || rx_stuff_error_o || rx_form_error_o) begin
        $display("%8t  %-8s | %-18s | crc_err=%0d        stuff_err=%0d     form_err=%0d",
                 $time, "RX", "ERRORS", rx_crc_error_o, rx_stuff_error_o, rx_form_error_o);
      end
    end
  end

endmodule
