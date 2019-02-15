// ==============================================================
// RTL generated by Vivado(TM) HLS - High-Level Synthesis from C, C++ and SystemC
// Version: 2018.2
// Copyright (C) 1986-2018 Xilinx, Inc. All Rights Reserved.
// 
// ===========================================================

`timescale 1 ns / 1 ps 

module convert_inputs (
        ap_clk,
        ap_rst,
        ap_start,
        start_full_n,
        ap_done,
        ap_continue,
        ap_idle,
        ap_ready,
        start_out,
        start_write,
        in_V_V_TDATA,
        in_V_V_TVALID,
        in_V_V_TREADY,
        pack_buffer_V_V_din,
        pack_buffer_V_V_full_n,
        pack_buffer_V_V_write
);

parameter    ap_ST_fsm_state1 = 1'd1;

input   ap_clk;
input   ap_rst;
input   ap_start;
input   start_full_n;
output   ap_done;
input   ap_continue;
output   ap_idle;
output   ap_ready;
output   start_out;
output   start_write;
input  [327:0] in_V_V_TDATA;
input   in_V_V_TVALID;
output   in_V_V_TREADY;
output  [515:0] pack_buffer_V_V_din;
input   pack_buffer_V_V_full_n;
output   pack_buffer_V_V_write;

reg ap_done;
reg ap_idle;
reg start_write;
reg in_V_V_TREADY;
reg pack_buffer_V_V_write;

reg    real_start;
reg    start_once_reg;
reg    ap_done_reg;
(* fsm_encoding = "none" *) reg   [0:0] ap_CS_fsm;
wire    ap_CS_fsm_state1;
reg    internal_ap_ready;
reg    in_V_V_TDATA_blk_n;
wire   [0:0] tmp_nbreadreq_fu_172_p3;
wire   [0:0] tmp_6_nbwritereq_fu_180_p3;
reg    pack_buffer_V_V_blk_n;
reg    ap_predicate_op9_read_state1;
reg    ap_block_state1;
wire   [63:0] tmp_32_fu_475_p1;
wire   [0:0] output0_first_V_fu_241_p3;
wire   [0:0] output0_last_V_fu_249_p3;
wire   [0:0] output0_addr_latch_V_fu_233_p3;
wire   [0:0] output0_response_V_fu_257_p3;
wire   [0:0] tmp3_fu_489_p2;
wire   [0:0] tmp2_fu_483_p2;
wire   [0:0] output1_first_V_fu_273_p3;
wire   [0:0] output1_last_V_fu_281_p3;
wire   [0:0] tmp4_fu_501_p2;
wire   [0:0] output1_addr_latch_V_fu_265_p3;
wire   [3:0] p_Result_42_i_fu_435_p4;
wire   [3:0] p_Result_43_i_fu_445_p4;
wire   [0:0] output2_first_V_fu_347_p3;
wire   [0:0] output2_last_V_fu_355_p3;
wire   [0:0] output2_addr_latch_V_fu_339_p3;
wire   [0:0] output2_response_V_fu_363_p3;
wire   [0:0] tmp7_fu_527_p2;
wire   [0:0] tmp6_fu_521_p2;
wire   [3:0] p_Result_40_i_fu_415_p4;
wire   [3:0] p_Result_41_i_fu_425_p4;
wire   [0:0] output3_first_V_fu_379_p3;
wire   [0:0] output3_last_V_fu_387_p3;
wire   [0:0] tmp8_fu_547_p2;
wire   [0:0] output3_addr_latch_V_fu_371_p3;
wire   [0:0] p_4_i_fu_495_p2;
wire   [0:0] p_5_i_fu_507_p2;
wire   [0:0] sel_tmp6_demorgan_fu_559_p2;
wire   [0:0] p_i_fu_533_p2;
wire   [0:0] sel_tmp6_fu_565_p2;
wire   [0:0] sel_tmp7_fu_571_p2;
wire   [0:0] output3_loop_V_fu_215_p3;
wire   [29:0] output3_timestamp_V_fu_205_p4;
wire   [0:0] sel_tmp_fu_591_p2;
wire   [0:0] p_i_not_fu_603_p2;
wire   [0:0] not_sel_tmp_fu_609_p2;
wire   [0:0] tmp9_fu_615_p2;
wire   [0:0] sel_tmp1_fu_597_p2;
wire   [29:0] sel_tmp2_fu_627_p3;
wire   [0:0] p_6_i_fu_553_p2;
wire   [0:0] or_cond_fu_643_p2;
wire   [0:0] tmp_7_fu_655_p2;
wire   [0:0] or_cond1_fu_649_p2;
wire   [0:0] or_cond2_fu_669_p2;
wire   [29:0] newSel_fu_661_p3;
wire   [0:0] p_5_i_not_fu_683_p2;
wire   [0:0] not_sel_tmp1_fu_689_p2;
wire   [0:0] tmp12_fu_701_p2;
wire   [0:0] tmp11_fu_707_p2;
wire   [0:0] tmp10_fu_695_p2;
wire   [29:0] newSel2_fu_725_p3;
wire   [39:0] output0_a_addr_V_fu_319_p4;
wire   [31:0] tmp_s_fu_741_p4;
wire   [7:0] output0_a_len_V_fu_299_p4;
wire   [6:0] tmp_1_fu_751_p4;
wire   [0:0] p_Repl2_1_fu_719_p2;
wire   [29:0] p_Repl2_s_fu_733_p3;
wire   [39:0] output1_a_addr_V_fu_309_p4;
wire   [31:0] tmp_2_fu_783_p4;
wire   [7:0] output1_a_len_V_fu_289_p4;
wire   [2:0] tmp_3_fu_793_p4;
wire   [2:0] output0_ext_event_V_fu_223_p4;
wire   [0:0] p_Repl2_3_fu_621_p2;
wire   [29:0] p_Repl2_9_fu_635_p3;
wire   [39:0] output2_a_addr_V_fu_465_p4;
wire   [15:0] output2_a_id_V_fu_517_p1;
wire   [15:0] output2_id_V_fu_513_p1;
wire   [7:0] output2_a_len_V_fu_405_p4;
wire   [6:0] tmp_4_fu_829_p4;
wire   [0:0] p_Repl2_19_fu_577_p2;
wire   [29:0] p_Repl2_2_fu_583_p3;
wire   [39:0] output3_a_addr_V_fu_455_p4;
wire   [15:0] output3_a_id_V_fu_543_p1;
wire   [15:0] output3_id_V_fu_539_p1;
wire   [7:0] output3_a_len_V_fu_395_p4;
wire   [2:0] tmp_5_fu_863_p4;
wire   [2:0] output2_ext_event_V_fu_329_p4;
wire   [0:0] p_Repl2_5_fu_713_p2;
wire   [29:0] p_Repl2_4_fu_675_p3;
wire   [0:0] tmp_16_fu_201_p1;
wire   [0:0] not_Result_i_fu_901_p2;
wire   [127:0] p_Result_4_fu_873_p13;
wire   [127:0] p_Result_3_fu_839_p11;
wire   [127:0] p_Result_2_fu_803_p12;
wire   [127:0] p_Result_s_fu_479_p1;
wire   [127:0] p_Result_1_fu_761_p10;
wire   [0:0] p_Repl2_43_fu_907_p2;
wire   [0:0] p_Repl2_36_fu_913_p2;
wire   [0:0] p_Repl2_42_fu_919_p2;
wire   [0:0] p_Repl2_41_fu_925_p2;
wire   [127:0] p_Repl2_39_fu_931_p3;
wire   [127:0] p_Repl2_38_fu_939_p3;
wire   [127:0] p_Repl2_37_fu_947_p3;
wire   [127:0] pack_data0_V_fu_955_p3;
reg   [0:0] ap_NS_fsm;

// power-on initialization
initial begin
#0 start_once_reg = 1'b0;
#0 ap_done_reg = 1'b0;
#0 ap_CS_fsm = 1'd1;
end

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        ap_CS_fsm <= ap_ST_fsm_state1;
    end else begin
        ap_CS_fsm <= ap_NS_fsm;
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        ap_done_reg <= 1'b0;
    end else begin
        if ((ap_continue == 1'b1)) begin
            ap_done_reg <= 1'b0;
        end else if ((~((real_start == 1'b0) | (ap_done_reg == 1'b1) | ((pack_buffer_V_V_full_n == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1)) | ((in_V_V_TVALID == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1))) & (1'b1 == ap_CS_fsm_state1))) begin
            ap_done_reg <= 1'b1;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        start_once_reg <= 1'b0;
    end else begin
        if (((internal_ap_ready == 1'b0) & (real_start == 1'b1))) begin
            start_once_reg <= 1'b1;
        end else if ((internal_ap_ready == 1'b1)) begin
            start_once_reg <= 1'b0;
        end
    end
end

always @ (*) begin
    if ((~((real_start == 1'b0) | (ap_done_reg == 1'b1) | ((pack_buffer_V_V_full_n == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1)) | ((in_V_V_TVALID == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1))) & (1'b1 == ap_CS_fsm_state1))) begin
        ap_done = 1'b1;
    end else begin
        ap_done = ap_done_reg;
    end
end

always @ (*) begin
    if (((real_start == 1'b0) & (1'b1 == ap_CS_fsm_state1))) begin
        ap_idle = 1'b1;
    end else begin
        ap_idle = 1'b0;
    end
end

always @ (*) begin
    if (((tmp_6_nbwritereq_fu_180_p3 == 1'd1) & (tmp_nbreadreq_fu_172_p3 == 1'd1) & (1'b1 == ap_CS_fsm_state1))) begin
        in_V_V_TDATA_blk_n = in_V_V_TVALID;
    end else begin
        in_V_V_TDATA_blk_n = 1'b1;
    end
end

always @ (*) begin
    if ((~((real_start == 1'b0) | (ap_done_reg == 1'b1) | ((pack_buffer_V_V_full_n == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1)) | ((in_V_V_TVALID == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1))) & (1'b1 == ap_CS_fsm_state1) & (ap_predicate_op9_read_state1 == 1'b1))) begin
        in_V_V_TREADY = 1'b1;
    end else begin
        in_V_V_TREADY = 1'b0;
    end
end

always @ (*) begin
    if ((~((real_start == 1'b0) | (ap_done_reg == 1'b1) | ((pack_buffer_V_V_full_n == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1)) | ((in_V_V_TVALID == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1))) & (1'b1 == ap_CS_fsm_state1))) begin
        internal_ap_ready = 1'b1;
    end else begin
        internal_ap_ready = 1'b0;
    end
end

always @ (*) begin
    if (((tmp_6_nbwritereq_fu_180_p3 == 1'd1) & (tmp_nbreadreq_fu_172_p3 == 1'd1) & (1'b1 == ap_CS_fsm_state1))) begin
        pack_buffer_V_V_blk_n = pack_buffer_V_V_full_n;
    end else begin
        pack_buffer_V_V_blk_n = 1'b1;
    end
end

always @ (*) begin
    if ((~((real_start == 1'b0) | (ap_done_reg == 1'b1) | ((pack_buffer_V_V_full_n == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1)) | ((in_V_V_TVALID == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1))) & (1'b1 == ap_CS_fsm_state1) & (ap_predicate_op9_read_state1 == 1'b1))) begin
        pack_buffer_V_V_write = 1'b1;
    end else begin
        pack_buffer_V_V_write = 1'b0;
    end
end

always @ (*) begin
    if (((start_full_n == 1'b0) & (start_once_reg == 1'b0))) begin
        real_start = 1'b0;
    end else begin
        real_start = ap_start;
    end
end

always @ (*) begin
    if (((start_once_reg == 1'b0) & (real_start == 1'b1))) begin
        start_write = 1'b1;
    end else begin
        start_write = 1'b0;
    end
end

always @ (*) begin
    case (ap_CS_fsm)
        ap_ST_fsm_state1 : begin
            ap_NS_fsm = ap_ST_fsm_state1;
        end
        default : begin
            ap_NS_fsm = 'bx;
        end
    endcase
end

assign ap_CS_fsm_state1 = ap_CS_fsm[32'd0];

always @ (*) begin
    ap_block_state1 = ((real_start == 1'b0) | (ap_done_reg == 1'b1) | ((pack_buffer_V_V_full_n == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1)) | ((in_V_V_TVALID == 1'b0) & (ap_predicate_op9_read_state1 == 1'b1)));
end

always @ (*) begin
    ap_predicate_op9_read_state1 = ((tmp_6_nbwritereq_fu_180_p3 == 1'd1) & (tmp_nbreadreq_fu_172_p3 == 1'd1));
end

assign ap_ready = internal_ap_ready;

assign newSel2_fu_725_p3 = ((p_4_i_fu_495_p2[0:0] === 1'b1) ? output3_timestamp_V_fu_205_p4 : 30'd0);

assign newSel_fu_661_p3 = ((tmp_7_fu_655_p2[0:0] === 1'b1) ? 30'd0 : output3_timestamp_V_fu_205_p4);

assign not_Result_i_fu_901_p2 = (tmp_16_fu_201_p1 ^ 1'd1);

assign not_sel_tmp1_fu_689_p2 = (p_5_i_not_fu_683_p2 | p_4_i_fu_495_p2);

assign not_sel_tmp_fu_609_p2 = (sel_tmp6_demorgan_fu_559_p2 | p_i_not_fu_603_p2);

assign or_cond1_fu_649_p2 = (p_6_i_fu_553_p2 | p_4_i_fu_495_p2);

assign or_cond2_fu_669_p2 = (or_cond_fu_643_p2 | or_cond1_fu_649_p2);

assign or_cond_fu_643_p2 = (sel_tmp7_fu_571_p2 | sel_tmp1_fu_597_p2);

assign output0_a_addr_V_fu_319_p4 = {{in_V_V_TDATA[201:162]}};

assign output0_a_len_V_fu_299_p4 = {{in_V_V_TDATA[57:50]}};

assign output0_addr_latch_V_fu_233_p3 = in_V_V_TDATA[32'd35];

assign output0_ext_event_V_fu_223_p4 = {{in_V_V_TDATA[34:32]}};

assign output0_first_V_fu_241_p3 = in_V_V_TDATA[32'd36];

assign output0_last_V_fu_249_p3 = in_V_V_TDATA[32'd37];

assign output0_response_V_fu_257_p3 = in_V_V_TDATA[32'd38];

assign output1_a_addr_V_fu_309_p4 = {{in_V_V_TDATA[161:122]}};

assign output1_a_len_V_fu_289_p4 = {{in_V_V_TDATA[49:42]}};

assign output1_addr_latch_V_fu_265_p3 = in_V_V_TDATA[32'd39];

assign output1_first_V_fu_273_p3 = in_V_V_TDATA[32'd40];

assign output1_last_V_fu_281_p3 = in_V_V_TDATA[32'd41];

assign output2_a_addr_V_fu_465_p4 = {{in_V_V_TDATA[323:284]}};

assign output2_a_id_V_fu_517_p1 = p_Result_43_i_fu_445_p4;

assign output2_a_len_V_fu_405_p4 = {{in_V_V_TDATA[227:220]}};

assign output2_addr_latch_V_fu_339_p3 = in_V_V_TDATA[32'd205];

assign output2_ext_event_V_fu_329_p4 = {{in_V_V_TDATA[204:202]}};

assign output2_first_V_fu_347_p3 = in_V_V_TDATA[32'd206];

assign output2_id_V_fu_513_p1 = p_Result_42_i_fu_435_p4;

assign output2_last_V_fu_355_p3 = in_V_V_TDATA[32'd207];

assign output2_response_V_fu_363_p3 = in_V_V_TDATA[32'd208];

assign output3_a_addr_V_fu_455_p4 = {{in_V_V_TDATA[283:244]}};

assign output3_a_id_V_fu_543_p1 = p_Result_41_i_fu_425_p4;

assign output3_a_len_V_fu_395_p4 = {{in_V_V_TDATA[219:212]}};

assign output3_addr_latch_V_fu_371_p3 = in_V_V_TDATA[32'd209];

assign output3_first_V_fu_379_p3 = in_V_V_TDATA[32'd210];

assign output3_id_V_fu_539_p1 = p_Result_40_i_fu_415_p4;

assign output3_last_V_fu_387_p3 = in_V_V_TDATA[32'd211];

assign output3_loop_V_fu_215_p3 = in_V_V_TDATA[32'd31];

assign output3_timestamp_V_fu_205_p4 = {{in_V_V_TDATA[30:1]}};

assign p_4_i_fu_495_p2 = (tmp3_fu_489_p2 | tmp2_fu_483_p2);

assign p_5_i_fu_507_p2 = (tmp4_fu_501_p2 | output1_addr_latch_V_fu_265_p3);

assign p_5_i_not_fu_683_p2 = (p_5_i_fu_507_p2 ^ 1'd1);

assign p_6_i_fu_553_p2 = (tmp8_fu_547_p2 | output3_addr_latch_V_fu_371_p3);

assign p_Repl2_19_fu_577_p2 = (sel_tmp7_fu_571_p2 & output3_loop_V_fu_215_p3);

assign p_Repl2_1_fu_719_p2 = (p_4_i_fu_495_p2 & output3_loop_V_fu_215_p3);

assign p_Repl2_2_fu_583_p3 = ((sel_tmp7_fu_571_p2[0:0] === 1'b1) ? output3_timestamp_V_fu_205_p4 : 30'd0);

assign p_Repl2_36_fu_913_p2 = (p_i_fu_533_p2 & not_Result_i_fu_901_p2);

assign p_Repl2_37_fu_947_p3 = ((tmp_16_fu_201_p1[0:0] === 1'b1) ? 128'd0 : p_Result_2_fu_803_p12);

assign p_Repl2_38_fu_939_p3 = ((tmp_16_fu_201_p1[0:0] === 1'b1) ? 128'd0 : p_Result_3_fu_839_p11);

assign p_Repl2_39_fu_931_p3 = ((tmp_16_fu_201_p1[0:0] === 1'b1) ? 128'd0 : p_Result_4_fu_873_p13);

assign p_Repl2_3_fu_621_p2 = (tmp9_fu_615_p2 & sel_tmp1_fu_597_p2);

assign p_Repl2_41_fu_925_p2 = (tmp_16_fu_201_p1 | p_4_i_fu_495_p2);

assign p_Repl2_42_fu_919_p2 = (p_5_i_fu_507_p2 & not_Result_i_fu_901_p2);

assign p_Repl2_43_fu_907_p2 = (p_6_i_fu_553_p2 & not_Result_i_fu_901_p2);

assign p_Repl2_4_fu_675_p3 = ((or_cond2_fu_669_p2[0:0] === 1'b1) ? newSel_fu_661_p3 : 30'd0);

assign p_Repl2_5_fu_713_p2 = (tmp11_fu_707_p2 & tmp10_fu_695_p2);

assign p_Repl2_9_fu_635_p3 = ((sel_tmp7_fu_571_p2[0:0] === 1'b1) ? 30'd0 : sel_tmp2_fu_627_p3);

assign p_Repl2_s_fu_733_p3 = ((or_cond_fu_643_p2[0:0] === 1'b1) ? 30'd0 : newSel2_fu_725_p3);

assign p_Result_1_fu_761_p10 = {{{{{{{{{{{{{{{{7'd0}, {output0_a_addr_V_fu_319_p4}}}, {tmp_s_fu_741_p4}}}, {output0_a_len_V_fu_299_p4}}}, {tmp_1_fu_751_p4}}}, {2'd2}}}, {p_Repl2_1_fu_719_p2}}}, {p_Repl2_s_fu_733_p3}}}, {1'd0}};

assign p_Result_2_fu_803_p12 = {{{{{{{{{{{{{{{{{{{{7'd0}, {output1_a_addr_V_fu_309_p4}}}, {tmp_2_fu_783_p4}}}, {output1_a_len_V_fu_289_p4}}}, {1'd0}}}, {tmp_3_fu_793_p4}}}, {output0_ext_event_V_fu_223_p4}}}, {2'd0}}}, {p_Repl2_3_fu_621_p2}}}, {p_Repl2_9_fu_635_p3}}}, {1'd0}};

assign p_Result_3_fu_839_p11 = {{{{{{{{{{{{{{{{{{7'd0}, {output2_a_addr_V_fu_465_p4}}}, {output2_a_id_V_fu_517_p1}}}, {output2_id_V_fu_513_p1}}}, {output2_a_len_V_fu_405_p4}}}, {tmp_4_fu_829_p4}}}, {2'd3}}}, {p_Repl2_19_fu_577_p2}}}, {p_Repl2_2_fu_583_p3}}}, {1'd0}};

assign p_Result_40_i_fu_415_p4 = {{in_V_V_TDATA[231:228]}};

assign p_Result_41_i_fu_425_p4 = {{in_V_V_TDATA[235:232]}};

assign p_Result_42_i_fu_435_p4 = {{in_V_V_TDATA[239:236]}};

assign p_Result_43_i_fu_445_p4 = {{in_V_V_TDATA[243:240]}};

assign p_Result_4_fu_873_p13 = {{{{{{{{{{{{{{{{{{{{{{7'd0}, {output3_a_addr_V_fu_455_p4}}}, {output3_a_id_V_fu_543_p1}}}, {output3_id_V_fu_539_p1}}}, {output3_a_len_V_fu_395_p4}}}, {1'd0}}}, {tmp_5_fu_863_p4}}}, {output2_ext_event_V_fu_329_p4}}}, {2'd1}}}, {p_Repl2_5_fu_713_p2}}}, {p_Repl2_4_fu_675_p3}}}, {1'd0}};

assign p_Result_s_fu_479_p1 = tmp_32_fu_475_p1;

assign p_i_fu_533_p2 = (tmp7_fu_527_p2 | tmp6_fu_521_p2);

assign p_i_not_fu_603_p2 = (p_i_fu_533_p2 ^ 1'd1);

assign pack_buffer_V_V_din = {{{{{{{{p_Repl2_43_fu_907_p2}, {p_Repl2_36_fu_913_p2}}, {p_Repl2_42_fu_919_p2}}, {p_Repl2_41_fu_925_p2}}, {p_Repl2_39_fu_931_p3}}, {p_Repl2_38_fu_939_p3}}, {p_Repl2_37_fu_947_p3}}, {pack_data0_V_fu_955_p3}};

assign pack_data0_V_fu_955_p3 = ((tmp_16_fu_201_p1[0:0] === 1'b1) ? p_Result_s_fu_479_p1 : p_Result_1_fu_761_p10);

assign sel_tmp1_fu_597_p2 = (sel_tmp_fu_591_p2 & p_5_i_fu_507_p2);

assign sel_tmp2_fu_627_p3 = ((sel_tmp1_fu_597_p2[0:0] === 1'b1) ? output3_timestamp_V_fu_205_p4 : 30'd0);

assign sel_tmp6_demorgan_fu_559_p2 = (p_5_i_fu_507_p2 | p_4_i_fu_495_p2);

assign sel_tmp6_fu_565_p2 = (sel_tmp6_demorgan_fu_559_p2 ^ 1'd1);

assign sel_tmp7_fu_571_p2 = (sel_tmp6_fu_565_p2 & p_i_fu_533_p2);

assign sel_tmp_fu_591_p2 = (p_4_i_fu_495_p2 ^ 1'd1);

assign start_out = real_start;

assign tmp10_fu_695_p2 = (p_6_i_fu_553_p2 & output3_loop_V_fu_215_p3);

assign tmp11_fu_707_p2 = (tmp12_fu_701_p2 & sel_tmp_fu_591_p2);

assign tmp12_fu_701_p2 = (not_sel_tmp_fu_609_p2 & not_sel_tmp1_fu_689_p2);

assign tmp2_fu_483_p2 = (output0_last_V_fu_249_p3 | output0_first_V_fu_241_p3);

assign tmp3_fu_489_p2 = (output0_response_V_fu_257_p3 | output0_addr_latch_V_fu_233_p3);

assign tmp4_fu_501_p2 = (output1_last_V_fu_281_p3 | output1_first_V_fu_273_p3);

assign tmp6_fu_521_p2 = (output2_last_V_fu_355_p3 | output2_first_V_fu_347_p3);

assign tmp7_fu_527_p2 = (output2_response_V_fu_363_p3 | output2_addr_latch_V_fu_339_p3);

assign tmp8_fu_547_p2 = (output3_last_V_fu_387_p3 | output3_first_V_fu_379_p3);

assign tmp9_fu_615_p2 = (output3_loop_V_fu_215_p3 & not_sel_tmp_fu_609_p2);

assign tmp_16_fu_201_p1 = in_V_V_TDATA[0:0];

assign tmp_1_fu_751_p4 = {{in_V_V_TDATA[38:32]}};

assign tmp_2_fu_783_p4 = {{in_V_V_TDATA[89:58]}};

assign tmp_32_fu_475_p1 = in_V_V_TDATA[63:0];

assign tmp_3_fu_793_p4 = {{in_V_V_TDATA[41:39]}};

assign tmp_4_fu_829_p4 = {{in_V_V_TDATA[208:202]}};

assign tmp_5_fu_863_p4 = {{in_V_V_TDATA[211:209]}};

assign tmp_6_nbwritereq_fu_180_p3 = pack_buffer_V_V_full_n;

assign tmp_7_fu_655_p2 = (p_4_i_fu_495_p2 | or_cond_fu_643_p2);

assign tmp_nbreadreq_fu_172_p3 = in_V_V_TVALID;

assign tmp_s_fu_741_p4 = {{in_V_V_TDATA[121:90]}};

endmodule //convert_inputs
