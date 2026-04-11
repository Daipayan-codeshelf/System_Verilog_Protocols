// can_tx.v
module can_tx(
    input  wire           clk,
    input  wire           reset_n,

    input  wire           tx_start,
    input  wire [10:0]    id,
    input  wire [3:0]     dlc,
    input  wire [63:0]    data_in,

    input  wire           bit_tick,
    input  wire           sample_point,

    input  wire           can_rx,
    output reg            can_tx,

    output reg            tx_done,
    output reg            arb_lost,
    output reg            tx_no_ack,
    output reg            tx_error,
    output wire           tx_busy,

    output wire           crc_init,
    output wire           crc_enable,
    output wire           crc_bit_in,
    input  wire [14:0]    crc_out,

    output wire           ack_slot_o
);

    localparam S_IDLE       = 2'd0;
    localparam S_SEND_FRAME = 2'd1;
    localparam S_WAIT_ACK   = 2'd2;
    localparam S_DONE       = 2'd3;

    localparam P_SOF  = 4'd0;
    localparam P_ID   = 4'd1;
    localparam P_RTR  = 4'd2;
    localparam P_IDE  = 4'd3;
    localparam P_R0   = 4'd4;
    localparam P_DLC  = 4'd5;
    localparam P_DATA = 4'd6;
    localparam P_CRC  = 4'd7;

    reg [1:0] state;
    reg [3:0] phase;

    assign tx_busy = (state != S_IDLE);

    reg [10:0] id_reg;
    reg [3:0]  dlc_reg;
    reg [63:0] data_sr;
    reg [6:0]  data_bits_rem;

    reg [3:0]  idx_id;
    reg [2:0]  idx_dlc;
    reg [3:0]  idx_crc;
    reg [3:0]  cnt_eof;
    reg [1:0]  cnt_interm;

    reg [2:0]  run_len;
    reg        last_bit;
    reg        insert_stuff;
    reg        cur_bit_is_stuff;

    reg        crc_init_r;
    reg [1:0]  ack_step;

    wire id_bit   = id_reg[10 - idx_id];
    wire dlc_bit  = dlc_reg[3  - idx_dlc];
    wire data_bit = data_sr[64 - (({3'd0, dlc_reg} << 3) - data_bits_rem) - 1];
    wire crc_seq_bit = crc_out[14 - idx_crc];

    reg raw_bit;
    always @* begin
        case (phase)
            P_SOF  : raw_bit = 1'b0;
            P_ID   : raw_bit = id_bit;
            P_RTR  : raw_bit = 1'b0;
            P_IDE  : raw_bit = 1'b0;
            P_R0   : raw_bit = 1'b0;
            P_DLC  : raw_bit = dlc_bit;
            P_DATA : raw_bit = data_bit;
            P_CRC  : raw_bit = crc_seq_bit;
            default: raw_bit = 1'b1;
        endcase
    end

    assign crc_init   = crc_init_r;
    assign crc_enable = bit_tick &&
                        (state == S_SEND_FRAME) &&
                        (phase != P_SOF && phase != P_CRC) &&
                        !insert_stuff;
    assign crc_bit_in = raw_bit;

    assign ack_slot_o = (state == S_WAIT_ACK) && (ack_step == 2'd1);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state            <= S_IDLE;
            phase            <= P_SOF;
            can_tx           <= 1'b1;

            tx_done          <= 1'b0;
            arb_lost         <= 1'b0;
            tx_no_ack        <= 1'b0;
            tx_error         <= 1'b0;

            id_reg           <= 11'd0;
            dlc_reg          <= 4'd0;
            data_sr          <= 64'd0;
            data_bits_rem    <= 7'd0;

            idx_id           <= 4'd0;
            idx_dlc          <= 3'd0;
            idx_crc          <= 4'd0;
            cnt_eof          <= 4'd0;
            cnt_interm       <= 2'd0;

            run_len          <= 3'd1;
            last_bit         <= 1'b1;
            insert_stuff     <= 1'b0;
            cur_bit_is_stuff <= 1'b0;

            crc_init_r       <= 1'b0;
            ack_step         <= 2'd0;
        end else begin
            tx_done    <= 1'b0;
            crc_init_r <= 1'b0;

            case (state)
                S_IDLE: begin
                    cnt_interm <= 2'd0;
                    if (tx_start) begin
                        tx_no_ack <= 1'b1;
                        arb_lost  <= 1'b0;
                        id_reg           <= id;
                        dlc_reg          <= dlc;
                        data_sr          <= data_in;
                        data_bits_rem    <= ({3'd0, dlc} << 3);
                        tx_error         <= (dlc > 4'd8);

                        phase            <= P_SOF;
                        idx_id           <= 4'd0;
                        idx_dlc          <= 3'd0;
                        idx_crc          <= 4'd0;

                        run_len          <= 3'd1;
                        last_bit         <= 1'b0;
                        insert_stuff     <= 1'b0;
                        cur_bit_is_stuff <= 1'b0;

                        crc_init_r       <= 1'b1;
                        state            <= S_SEND_FRAME;
                    end
                end

                S_SEND_FRAME: begin
                    if (bit_tick) begin
                        if (insert_stuff) begin
                            can_tx           <= !last_bit;
                            last_bit         <= !last_bit;
                            run_len          <= 3'd1;
                            insert_stuff     <= 1'b0;
                            cur_bit_is_stuff <= 1'b1;
                        end else begin
                            can_tx           <= raw_bit;
                            cur_bit_is_stuff <= 1'b0;

                            if (raw_bit == last_bit) begin
                                if (run_len == 3'd4) begin
                                    insert_stuff <= 1'b1;
                                end
                                run_len <= run_len + 3'd1;
                            end else begin
                                run_len  <= 3'd1;
                                last_bit <= raw_bit;
                            end

                            case (phase)
                                P_SOF: begin
                                    phase <= P_ID;
                                end
                                P_ID: begin
                                    if (idx_id == 4'd10) begin
                                        idx_id <= 4'd0;
                                        phase  <= P_RTR;
                                    end else begin
                                        idx_id <= idx_id + 4'd1;
                                    end
                                end
                                P_RTR: phase <= P_IDE;
                                P_IDE: phase <= P_R0;
                                P_R0 : phase <= P_DLC;
                                P_DLC: begin
                                    if (idx_dlc == 3'd3) begin
                                        idx_dlc <= 3'd0;
                                        if (data_bits_rem == 7'd0) begin
                                            idx_crc <= 4'd0;
                                            phase   <= P_CRC;
                                        end else begin
                                            phase   <= P_DATA;
                                        end
                                    end else begin
                                        idx_dlc <= idx_dlc + 3'd1;
                                    end
                                end
                                P_DATA: begin
                                    if (data_bits_rem == 7'd1) begin
                                        data_bits_rem <= 7'd0;
                                        idx_crc       <= 4'd0;
                                        phase         <= P_CRC;
                                    end else begin
                                        data_bits_rem <= data_bits_rem - 7'd1;
                                    end
                                end
                                P_CRC: begin
                                    if (idx_crc == 4'd14) begin
                                        state    <= S_WAIT_ACK;
                                        ack_step <= 2'd0;
                                    end else begin
                                        idx_crc  <= idx_crc + 4'd1;
                                    end
                                end
                                default: phase <= P_SOF;
                            endcase
                        end
                    end

                    if (phase == P_ID && sample_point && !cur_bit_is_stuff) begin
                        if (can_tx == 1'b1 && can_rx == 1'b0) begin
                            arb_lost <= 1'b1;
                            state    <= S_IDLE;
                            can_tx   <= 1'b1;
                        end
                    end
                end

                S_WAIT_ACK: begin
                    if (bit_tick) begin
                      can_tx <= 1'b1;
                      if (ack_step == 2'd2) begin
                        state   <= S_DONE;
                        cnt_eof <= 4'd0;
                      end else begin
                        ack_step <= ack_step + 2'd1;
                      end
                    end
                    if (ack_step == 2'd0 && sample_point)
                      tx_no_ack <= (can_rx == 1'b1);
                end

                S_DONE: begin
                    if (bit_tick) begin
                        can_tx <= 1'b1;
                      if (cnt_eof == 4'd0) begin
                            tx_done <= 1'b1;
                       end
                        if (cnt_eof < 4'd7) begin
                            cnt_eof <= cnt_eof + 4'd1;
                        end else if (cnt_interm < 2'd3) begin
                            cnt_interm <= cnt_interm + 2'd1;
                        end else begin
                            state   <= S_IDLE;
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
