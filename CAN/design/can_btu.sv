// can_btu.v
module can_btu #(
    parameter integer BIT_TICKS  = 20,
    parameter integer SAMPLE_TAP = (BIT_TICKS*4)/5
)(
    input  wire clk,
    input  wire reset_n,
    input  wire can_rx_async,

    output reg  bit_tick,
    output reg  sample_point,
    output reg  sof_detect,
    output reg  hard_resync,
    output reg  bus_idle,
    output reg  intermission_done
);

    function integer clog2;
        input integer value;
        integer i;
        begin
            i = value - 1;
            clog2 = 0;
            while (i > 0) begin
                clog2 = clog2 + 1;
                i = i >> 1;
            end
        end
    endfunction

    // 1) RX Synchronizer (2-FF)
    reg rx_d1, rx_d2;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rx_d1 <= 1'b1;
            rx_d2 <= 1'b1;
        end else begin
            rx_d1 <= can_rx_async;
            rx_d2 <= rx_d1;
        end
    end
    wire can_rx = rx_d2;

    // 2) Bit Time Counter
    reg [clog2(BIT_TICKS)-1:0] cnt;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            cnt <= {clog2(BIT_TICKS){1'b0}};
        else if (hard_resync)
            cnt <= {clog2(BIT_TICKS){1'b0}};
        else if (cnt == BIT_TICKS-1)
            cnt <= {clog2(BIT_TICKS){1'b0}};
        else
            cnt <= cnt + 1'b1;
    end

    // 3) Timing Signals
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bit_tick     <= 1'b0;
            sample_point <= 1'b0;
        end else begin
            bit_tick     <= (cnt == BIT_TICKS-1);
            sample_point <= (cnt == SAMPLE_TAP);
        end
    end

    // 4) SOF Detection (Recessive -> Dominant)
    reg can_rx_prev;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            can_rx_prev <= 1'b1;
        else
            can_rx_prev <= can_rx;
    end
    wire falling_edge = (can_rx_prev == 1'b1) && (can_rx == 1'b0);
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sof_detect  <= 1'b0;
            hard_resync <= 1'b0;
        end else begin
            sof_detect  <= falling_edge;
            hard_resync <= falling_edge;
        end
    end

    // 5) Bus Idle Detection (11 consecutive recessive bits)
    localparam integer IDLE_BITS = 11;
    reg [3:0] recessive_cnt;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            recessive_cnt <= 4'd0;
            bus_idle      <= 1'b1;
        end else if (hard_resync) begin
            recessive_cnt <= 4'd0;
            bus_idle      <= 1'b0;
        end else if (bit_tick) begin
            if (can_rx == 1'b1) begin
                if (recessive_cnt < IDLE_BITS[3:0])
                    recessive_cnt <= recessive_cnt + 1'b1;
            end else begin
                recessive_cnt <= 4'd0;
                bus_idle      <= 1'b0;
            end
            if (recessive_cnt == IDLE_BITS-1)
                bus_idle <= 1'b1;
        end
    end

    // 6) Intermission Detection (3 recessive bits)
    localparam integer INTERMISSION_BITS = 3;
    reg [1:0] intermission_cnt;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            intermission_cnt  <= 2'd0;
            intermission_done <= 1'b0;
        end else if (hard_resync) begin
            intermission_cnt  <= 2'd0;
            intermission_done <= 1'b0;
        end else if (bit_tick) begin
            if (can_rx == 1'b1) begin
                if (intermission_cnt < INTERMISSION_BITS[1:0])
                    intermission_cnt <= intermission_cnt + 1'b1;
            end else begin
                intermission_cnt <= 2'd0;
            end
            if (intermission_cnt == INTERMISSION_BITS-1)
                intermission_done <= 1'b1;
            else
                intermission_done <= 1'b0;
        end else begin
            intermission_done <= 1'b0;
        end
    end

endmodule
