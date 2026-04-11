//APB Single Master Single Slave
module apb_slave_simple#(
  parameter integer ADDR_W =8,
  parameter integer DATA_W =32,
  parameter integer INDEX_W =4,
  parameter integer DEPTH =16,
  parameter integer WAIT_CYCLES =0)(
  
  input PCLK,PRESETn,PWRITE,PSEL,PENABLE,
  input [(ADDR_W-1):0]PADDR,
  input [(DATA_W-1):0]PWDATA,
  output reg PREADY,
  output PSLVERR,
  output reg [(DATA_W-1):0]PRDATA
);
  wire [(INDEX_W-1):0] index= PADDR[(INDEX_W-1):0];
  reg [(DATA_W-1):0]mem[0: (DEPTH-1)];
  integer count;
  integer i;
  
  always @ (posedge PCLK or negedge PRESETn) begin
    if(~PRESETn) begin
      count<=0; PRDATA<=0; PREADY<=0;
      for(i=0;i<DEPTH;i=i+1) begin
        mem[i]<=0; 
      end
    end
    
    else begin 
      if(!PSEL) begin        //IDLE phase
        PREADY<=0;
        count<=0;
      end
      
      if(PSEL && !PENABLE) begin        //setup phase
        PREADY<=0;
        count<=0;
      end
      
      if(PSEL && PENABLE) begin        //Access Phase
        if(count<WAIT_CYCLES) begin        //Hold
          PREADY<=0;
          count<=count+1;
          end
        else begin
          PREADY<=1;
          count<=0;
          if (PWRITE) begin
            if (index < DEPTH)
              mem[index]<=PWDATA;
          end
          else begin
            if (index < DEPTH)
              PRDATA<=mem[index];
          end
        end
      end
    end
  end
  assign PSLVERR=1'b0;
endmodule
