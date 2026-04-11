// can_rx.v
module can_rx (
    input  wire        clk,
    input  wire        reset_n,

    input  wire        can_rx,
    input  wire        sample_point,
    input  wire        sof_detect,

    // CRC interface
    input  wire [14:0] crc_out,
    output reg         crc_init,
    output reg         crc_enable,
    output reg         crc_bit_in,

    // Frame fields
    output reg [10:0]  id_out,
    output reg [3:0]   dlc_out,
    output reg [63:0]  data_out,

    // Status
    output reg         rx_done,
    output reg         ack_req,

    output reg         rx_crc_error,
    output reg         rx_stuff_error,
    output reg         rx_form_error
);

    localparam DOM = 1'b0;
    localparam REC = 1'b1;

    localparam [3:0] RX_IDLE      = 4'd0;
    localparam [3:0] RX_SOF       = 4'd1;
    localparam [3:0] RX_ID        = 4'd2;
    localparam [3:0] RX_RTR       = 4'd3;
    localparam [3:0] RX_IDE       = 4'd4;
    localparam [3:0] RX_R0        = 4'd5;
    localparam [3:0] RX_DLC       = 4'd6;
    localparam [3:0] RX_DATA      = 4'd7;
    localparam [3:0] RX_CRC       = 4'd8;
    localparam [3:0] RX_CRC_WAIT  = 4'd9;
    localparam [3:0] RX_CRC_DELIM = 4'd10;
    localparam [3:0] RX_ACK_SLOT  = 4'd11;
    localparam [3:0] RX_ACK_DELIM = 4'd12;
    localparam [3:0] RX_EOF       = 4'd13;
    localparam [3:0] RX_DONE      = 4'd14;

    reg [3:0] state;

    integer bit_cnt;
    integer byte_cnt;
    integer eof_cnt;

    // De-stuffing
    reg       last_bit;
    reg [2:0] run_len;
    reg       expect_stuff;
    reg       crc_check_pending;

    wire this_is_stuffed = expect_stuff;
    wire stuffing_active =
        (state == RX_SOF)  ||
        (state == RX_ID)   ||
        (state == RX_RTR)  ||
        (state == RX_IDE)  ||
        (state == RX_R0)   ||
        (state == RX_DLC)  ||
        (state == RX_DATA) ||
        (state == RX_CRC);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            last_bit       <= REC;
            run_len        <= 3'd1;
            expect_stuff   <= 1'b0;
            rx_stuff_error <= 1'b0;
        end else if (sample_point && stuffing_active) begin
            if (expect_stuff) begin
                if (can_rx == last_bit)
                    rx_stuff_error <= 1'b1;
                expect_stuff <= 1'b0;
                run_len      <= 3'd1;
                last_bit     <= can_rx;
            end else begin
                if (can_rx == last_bit) begin
                    run_len <= run_len + 3'd1;
                    if (run_len == 3'd4) begin
                        expect_stuff <= 1'b1;
                    end
                end else begin
                    last_bit <= can_rx;
                    run_len  <= 3'd1;
                end
            end
        end
    end

    // RX FSM
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= RX_IDLE;

            id_out   <= 11'd0;
            dlc_out  <= 4'd0;
            data_out <= 64'd0;

            bit_cnt  <= 0;
            byte_cnt <= 0;
            eof_cnt  <= 0;

            crc_init          <= 1'b0;
            crc_enable        <= 1'b0;
            crc_bit_in        <= 1'b0;
            crc_check_pending <= 1'b0;

            rx_done       <= 1'b0;
            ack_req       <= 1'b0;
            rx_crc_error  <= 1'b0;
            rx_form_error <= 1'b0;
        end else begin
            crc_init   <= 1'b0;
            crc_enable <= 1'b0;
            ack_req    <= 1'b0;
            // Make rx_done a single-cycle pulse
            rx_done    <= 1'b0;

            // SOF detect
            if (state == RX_IDLE && sof_detect) begin
                crc_init <= 1'b1;

                bit_cnt  <= 0;
                byte_cnt <= 0;
                eof_cnt  <= 0;

                rx_crc_error   <= 1'b0;
                rx_stuff_error <= 1'b0;
                rx_form_error  <= 1'b0;

                id_out   <= 11'd0;
                dlc_out  <= 4'd0;
                data_out <= 64'd0;

                state <= RX_SOF;
            end

            // CRC check delay
            else if (state == RX_CRC_WAIT) begin
                if (crc_check_pending) begin
                    crc_check_pending <= 1'b0;
                end else begin
                    if (crc_out != 15'd0)
                        rx_crc_error <= 1'b1;
                    state <= RX_CRC_DELIM;
                end
            end

            // Advance on sample_point
            else if (sample_point) begin
                case (state)
                    RX_SOF: begin
                        if (can_rx != DOM)
                            rx_form_error <= 1'b1;
                        state <= RX_ID;
                    end

                    RX_ID: if (!this_is_stuffed) begin
                        id_out[10-bit_cnt] <= can_rx;
                        crc_enable <= 1'b1;
                        crc_bit_in <= can_rx;

                        if (bit_cnt == 10) begin
                            bit_cnt <= 0;
                            state   <= RX_RTR;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end

                    RX_RTR: if (!this_is_stuffed) begin
                        if (can_rx != DOM) rx_form_error <= 1'b1;
                        crc_enable <= 1'b1;
                        crc_bit_in <= can_rx;
                        state <= RX_IDE;
                    end

                    RX_IDE: if (!this_is_stuffed) begin
                        if (can_rx != DOM) rx_form_error <= 1'b1;
                        crc_enable <= 1'b1;
                        crc_bit_in <= can_rx;
                        state <= RX_R0;
                    end

                    RX_R0: if (!this_is_stuffed) begin
                        if (can_rx != DOM) rx_form_error <= 1'b1;
                        crc_enable <= 1'b1;
                        crc_bit_in <= can_rx;
                        bit_cnt <= 0;
                        state   <= RX_DLC;
                    end

                    RX_DLC: if (!this_is_stuffed) begin
                        dlc_out    <= {dlc_out[2:0], can_rx};
                        crc_enable <= 1'b1;
                        crc_bit_in <= can_rx;

                        if (bit_cnt == 3) begin
                            bit_cnt  <= 0;
                            byte_cnt <= 0;
                            if ({dlc_out[2:0], can_rx} == 4'd0)
                                state <= RX_CRC;
                            else
                                state <= RX_DATA;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end

                    RX_DATA: if (!this_is_stuffed) begin
                        data_out[63 - (byte_cnt*8) - bit_cnt] <= can_rx;
                        crc_enable <= 1'b1;
                        crc_bit_in <= can_rx;

                        if (bit_cnt == 7) begin
                            bit_cnt  <= 0;
                            byte_cnt <= byte_cnt + 1;
                            if (byte_cnt + 1 == dlc_out)
                                state <= RX_CRC;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end

                    RX_CRC: if (!this_is_stuffed) begin
                        crc_enable <= 1'b1;
                        crc_bit_in <= can_rx;
                        if (bit_cnt == 14) begin
                            bit_cnt           <= 0;
                            expect_stuff      <= 1'b0;
                            run_len           <= 3'd1;
                            last_bit          <= REC;
                            crc_check_pending <= 1'b1;
                            state             <= RX_CRC_WAIT;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end

                    RX_CRC_DELIM: begin
                        if (can_rx != REC) rx_form_error <= 1'b1;
                        expect_stuff <= 1'b0;
                        run_len      <= 3'd1;
                        last_bit     <= REC;
                        state        <= RX_ACK_SLOT;
                    end

                    RX_ACK_SLOT: begin
                        if (!rx_crc_error && !rx_stuff_error && !rx_form_error)
                            ack_req <= 1'b1;
                        state <= RX_ACK_DELIM;
                    end

                    RX_ACK_DELIM: begin
                        if (can_rx != REC) rx_form_error <= 1'b1;
                        state <= RX_EOF;
                    end

                    RX_EOF: begin
                        if (can_rx != REC) rx_form_error <= 1'b1;
                        if (eof_cnt == 6) begin
                            rx_done <= 1'b1;   // single-cycle pulse
                            eof_cnt <= 0;
                            state   <= RX_DONE;
                        end else begin
                            eof_cnt <= eof_cnt + 1;
                        end
                    end

                    RX_DONE: begin
                        // rx_done was pulsed last cycle; return to IDLE
                        state <= RX_IDLE;
                    end

                    default: begin
                        state <= RX_IDLE;
                    end
                endcase
            end
        end
    end

endmodule
