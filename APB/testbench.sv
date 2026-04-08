// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

module tb_apb_1m4s;

parameter ADDR_W=8;
parameter DATA_W=32;

reg PCLK;
reg PRESETn;

reg M_PSEL;
reg M_PENABLE;
reg M_PWRITE;
reg [ADDR_W-1:0] M_PADDR;
reg [DATA_W-1:0] M_PWDATA;
wire [DATA_W-1:0] M_PRDATA;
wire M_PREADY;
wire M_PSLVERR;

wire S_PENABLE;
wire S_PWRITE;
wire [ADDR_W-1:0] S_PADDR;
wire [DATA_W-1:0] S_PWDATA;

wire S0_PSEL,S1_PSEL,S2_PSEL,S3_PSEL;
wire [DATA_W-1:0] S0_PRDATA,S1_PRDATA,S2_PRDATA,S3_PRDATA;
wire S0_PREADY,S1_PREADY,S2_PREADY,S3_PREADY;

wire S0_PSLVERR,S1_PSLVERR,S2_PSLVERR,S3_PSLVERR;

apb_bus_1m4s bus(
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .M_PSEL(M_PSEL),
    .M_PENABLE(M_PENABLE),
    .M_PWRITE(M_PWRITE),
    .M_PADDR(M_PADDR),
    .M_PWDATA(M_PWDATA),
    .M_PRDATA(M_PRDATA),
    .M_PREADY(M_PREADY),
    .M_PSLVERR(M_PSLVERR),
    .S_PENABLE(S_PENABLE),
    .S_PWRITE(S_PWRITE),
    .S_PADDR(S_PADDR),
    .S_PWDATA(S_PWDATA),
    .S0_PSEL(S0_PSEL),
    .S1_PSEL(S1_PSEL),
    .S2_PSEL(S2_PSEL),
    .S3_PSEL(S3_PSEL),
    .S0_PRDATA(S0_PRDATA),
    .S1_PRDATA(S1_PRDATA),
    .S2_PRDATA(S2_PRDATA),
    .S3_PRDATA(S3_PRDATA),
    .S0_PREADY(S0_PREADY),
    .S1_PREADY(S1_PREADY),
    .S2_PREADY(S2_PREADY),
    .S3_PREADY(S3_PREADY),
    .S0_PSLVERR(S0_PSLVERR),
    .S1_PSLVERR(S1_PSLVERR),
    .S2_PSLVERR(S2_PSLVERR),
    .S3_PSLVERR(S3_PSLVERR)
);

apb_slave_simple #(.WAIT_CYCLES(0)) s0 ( .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PSEL(S0_PSEL),
    .PENABLE(S_PENABLE),
    .PADDR(S_PADDR),
    .PWRITE(S_PWRITE),
    .PWDATA(S_PWDATA),
    .PRDATA(S0_PRDATA),
    .PREADY(S0_PREADY),
    .PSLVERR(S0_PSLVERR));
apb_slave_simple #(.WAIT_CYCLES(1)) s1 (  .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PSEL(S1_PSEL),
    .PENABLE(S_PENABLE),
    .PADDR(S_PADDR),
    .PWRITE(S_PWRITE),
    .PWDATA(S_PWDATA),
    .PRDATA(S1_PRDATA),
    .PREADY(S1_PREADY),
    .PSLVERR(S1_PSLVERR));
apb_slave_simple #(.WAIT_CYCLES(2)) s2 ( .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PSEL(S2_PSEL),
    .PENABLE(S_PENABLE),
    .PADDR(S_PADDR),
    .PWRITE(S_PWRITE),
    .PWDATA(S_PWDATA),
    .PRDATA(S2_PRDATA),
    .PREADY(S2_PREADY),
    .PSLVERR(S2_PSLVERR));
apb_slave_simple #(.WAIT_CYCLES(3)) s3 (  .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PSEL(S3_PSEL),
    .PENABLE(S_PENABLE),
    .PADDR(S_PADDR),
    .PWRITE(S_PWRITE),
    .PWDATA(S_PWDATA),
    .PRDATA(S3_PRDATA),
    .PREADY(S3_PREADY),
    .PSLVERR(S3_PSLVERR));

initial PCLK=0;
always #5 PCLK=~PCLK;

task apb_write;
input [7:0] addr;
input [31:0] data;
begin
@(posedge PCLK);
M_PSEL=1; M_PENABLE=0; M_PWRITE=1; M_PADDR=addr; M_PWDATA=data;
@(posedge PCLK);
M_PENABLE=1;
while(!M_PREADY) @(posedge PCLK);
@(posedge PCLK);
M_PSEL=0; M_PENABLE=0;
end
endtask

task apb_read;
input [7:0] addr;
output [31:0] data;
begin
@(posedge PCLK);
M_PSEL=1; M_PENABLE=0; M_PWRITE=0; M_PADDR=addr;
@(posedge PCLK);
M_PENABLE=1;
while(!M_PREADY) @(posedge PCLK);
data=M_PRDATA;
@(posedge PCLK);
M_PSEL=0; M_PENABLE=0;
end
endtask

reg [31:0] rdata;

initial begin
$dumpfile("apb_1m4s.vcd");
$dumpvars(0,tb_apb_1m4s);

PRESETn=0; M_PSEL=0; M_PENABLE=0;
repeat(5) @(posedge PCLK);
PRESETn=1;

apb_write(8'h04,32'hA5A50001);
apb_read(8'h04,rdata);
$display("S0 Readback: %h",rdata);

apb_write(8'h44,32'h5A5A0002);
apb_read(8'h44,rdata);
$display("S1 Readback: %h",rdata);

apb_write(8'h84,32'hDEADBEEF);
apb_read(8'h84,rdata);
$display("S2 Readback: %h",rdata);

apb_write(8'hC4,32'hCAFEBABE);
apb_read(8'hC4,rdata);
$display("S3 Readback: %h",rdata);

#200;
$finish;
end

endmodule
