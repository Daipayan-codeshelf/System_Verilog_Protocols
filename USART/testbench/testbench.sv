module tb_full;

    /* ================= CLOCK ================= */
    reg clk;
    initial clk = 0;
    always #5 clk = ~clk;   

    /* ================= APB ================= */
    reg rstn;
    reg psel, penable, pwrite;
    reg [7:0]  paddr;
    reg [31:0] pwdata;
    wire [31:0] prdata;
    wire pready;

    /* ================= USART ================= */
    wire txd;
    wire rxd;
    wire sclk;

    /* Loopback */
    assign rxd = txd;

    /* ================= DUT ================= */
    usart_top dut(
        .pclk(clk),
        .presetn(rstn),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .rxd(rxd),
        .txd(txd),
        .sclk(sclk)
    );

    /* ================= APB WRITE ================= */
    task wr;
        input [7:0] a;
        input [31:0] d;
    begin
        @(negedge clk);
        psel=1; pwrite=1; penable=0; paddr=a; pwdata=d;

        @(negedge clk);
        penable=1;

        @(negedge clk);
        psel=0; penable=0; pwrite=0;
    end
    endtask


    /* ================= APB READ ================= */
    task rd;
        input  [7:0] a;
        output [31:0] d;
    begin
        @(negedge clk);
        psel=1; pwrite=0; penable=0; paddr=a;

        @(negedge clk);
        penable=1;

        @(posedge clk);
        #1 d = prdata;

        @(negedge clk);
        psel=0; penable=0;
    end
    endtask


    /* ================= SEND + RECEIVE ================= */

    integer pass_count;
    integer fail_count;

    task send_recv;
        input [7:0] tx_byte;
        input [7:0] expected;
        input [63:0] label;

        reg [31:0] rdata;
        reg [31:0] status;
        integer i;

    begin

        /* Write TXDATA register */
        wr(8'h08, {24'd0, tx_byte});
        $display("[%0t] TX WRITE : %h", $time, tx_byte);

        /* Wait for RX valid */
        for (i=0;i<2000000;i=i+1) begin
            @(posedge clk); #1;
            if (dut.rx_valid_reg===1'b1) begin
                $display("[%0t] RX VALID : %h",
                         $time,dut.rx_data_reg);
                i=2000000;
            end
        end

        repeat(5) @(posedge clk);

        /* Read RXDATA register */
        rd(8'h0C, rdata);
        $display("[%0t] RXDATA READ : %h", $time, rdata);

        /* Read STATUS register */
        rd(8'h10, status);
        $display("[%0t] STATUS READ : %h", $time, status);

        /* Data verification */
        if (rdata[7:0]===expected) begin
            $display("[%0t] PASS : %s", $time, label);
            pass_count = pass_count + 1;
        end
        else begin
            $display("[%0t] FAIL : %s expected=%h got=%h",
                     $time,label,expected,rdata[7:0]);
            fail_count = fail_count + 1;
        end

        repeat(10) @(posedge clk);

    end
    endtask


    /* ================= MAIN TEST ================= */

    initial begin

        pass_count=0;
        fail_count=0;

        psel=0; penable=0; pwrite=0; paddr=0; pwdata=0; rstn=0;

        repeat(10) @(posedge clk);
        rstn=1;
        repeat(10) @(posedge clk);


        /* ==================================================
           ASYNCHRONOUS MODE TEST
           ================================================== */

        wr(8'h00,32'h06);   // CTRL async
      	wr(8'h04,32'd54);   // BAUD_DIV
        
        send_recv(8'hA5,8'hA5,"async_A5");
        send_recv(8'h00,8'h00,"async_00");
        send_recv(8'hFF,8'hFF,"async_FF");
        send_recv(8'h55,8'h55,"async_55");


//         /* ==================================================
//            SYNCHRONOUS MODE TEST
//            ================================================== */

        wr(8'h00,32'h07);   // CTRL sync
      	wr(8'h04,32'd54);   // BAUD_DIV

        send_recv(8'hA5,8'hA5,"sync_A5");
        send_recv(8'h00,8'h00,"sync_00");
        send_recv(8'hFF,8'hFF,"sync_FF");
        send_recv(8'h55,8'h55,"sync_55");


        /* ================= SUMMARY ================= */

        $display("");
        $display("========================================");
        $display("RESULTS : PASS=%0d FAIL=%0d",
                 pass_count,fail_count);
        $display("========================================");

        repeat(20) @(posedge clk);
        $finish;

    end


    /* ================= TIMEOUT ================= */

    initial begin
        #500000000;
        $display("SIMULATION TIMEOUT");
        $finish;
    end


    /* ================= WAVEFORM ================= */

    initial begin
        $dumpfile("tb_full.vcd");
        $dumpvars(0,tb_full);
    end

endmodule
