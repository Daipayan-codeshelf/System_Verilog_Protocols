// Testbench
module tb_apb_slave_simple;
  parameter integer ADDR_W =8;
  parameter integer DATA_W =32;
  parameter integer INDEX_W =4;
  parameter integer DEPTH =16;
  parameter integer WAIT_CYCLES =2;
  
  reg PCLK,PRESETn,PWRITE,PSEL,PENABLE;
  reg [(ADDR_W-1):0]PADDR;
  reg [(DATA_W-1):0]PWDATA;
  wire PREADY,PSLVERR;
  wire [(DATA_W-1):0]PRDATA;

  apb_slave_simple#(ADDR_W,DATA_W,INDEX_W,DEPTH,WAIT_CYCLES) dut(.PCLK(PCLK),.PRESETn(PRESETn),.PWRITE(PWRITE),.PSEL(PSEL),.PENABLE(PENABLE),.PADDR(PADDR),.PWDATA(PWDATA),.PREADY(PREADY),.PSLVERR(PSLVERR),.PRDATA(PRDATA));
  
  initial begin
    PCLK=1'b0;
    forever #5 PCLK=~PCLK;
  end
  
  task apb_write;
    input [ADDR_W-1:0] addr;
    input [DATA_W-1:0] data;
    begin
      PADDR  = addr;
      PWDATA = data;
      PWRITE = 1;
      PSEL   = 1;
      PENABLE = 0;

      @(posedge PCLK);
      PENABLE = 1;
      
      @(posedge PCLK);
      while (!PREADY) @(posedge PCLK);


  end
  endtask

  task apb_read;
    input [ADDR_W-1:0] addr; 
    output [DATA_W-1:0] data_out;
    begin
      PADDR  = addr;
      PWRITE = 0;
      PSEL   = 1;
      PENABLE = 0;
      
      @(posedge PCLK);
      PENABLE = 1;
      
      @(posedge PCLK);
      while (!PREADY) @(posedge PCLK);
      data_out = PRDATA;
      PENABLE = 0;

  end
  endtask

  reg [(DATA_W-1):0]data_out;
  initial begin
    PRESETn = 0;
    PSEL = 0;
    PENABLE = 0;
    PWRITE = 0;
    PADDR = 0;
    PWDATA = 0;

    repeat (2) @(posedge PCLK);
    PRESETn = 1;

    //1. 3 Consecutive write and then read for different adresses
    apb_write(8'h10, 32'h0000_0060);    
    apb_write(8'h11, 32'h0000_0070);    
    apb_write(8'h12, 32'h0000_0080);    
    apb_read(8'h10);
    apb_read(8'h11);
    apb_read(8'h12);

    repeat (5) @(posedge PCLK);
    $finish;
  end

  initial begin
    $display("Time | Reset PSEL PWRITE PENABLE  PADDR   PWDATA   | PREADY   PRDATA");
    $monitor("%0t |    %b     %b      %b       %b      %h    %h   |   %b     %h", $time, PRESETn, PSEL, PWRITE, PENABLE, PADDR, PWDATA, PREADY, PRDATA);
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0,tb_apb_slave_simple);

  end

endmodule
