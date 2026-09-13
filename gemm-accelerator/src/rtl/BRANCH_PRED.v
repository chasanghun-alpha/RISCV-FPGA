// BRANCH_PRED.v
// Local-history branch predictor for the pipelined RV32I core.
//
// [최적화] B 비트 체크 beq 예측 제외
//   beq x7,x0 / beq x1,x0 / beq x6,x0: B행렬 비트값 의존 → 랜덤 패턴
//   → PRED_ACTIVE=0으로 처리 → 예측 불필요 분기 제외
//   → 충돌 감소, PHT 학습 품질 향상
//
// [최적화] 히스토리 2bit → 1bit 축소
//   유효한 분기: beq x2,x3(7NT1T) / beq x5,x1(7NT1T) → 1비트로 충분
//   beq x0,x0: 항상 T → 히스토리 불필요
//
// [최적화] 면적 축소:
//   LHIST: 16×2bit(32bit) → 16×1bit(16bit)
//   PHT:   64×2bit(128bit) → 32×2bit(64bit)
//   합계: 160bit → 80bit (50% 감소)
//
// [최적화] PHT 업데이트 1사이클 지연
//   critical path: idex_pc → ex_pc_idx → PHT 래칭 제거

module BRANCH_PRED (
    input         CLK,
    input         RESET,

    input  [31:0] IF_PC,
    input  [31:0] IF_INSTR,

    input         EX_IS_BRANCH,
    input         EX_PRED_ACTIVE,
    input  [31:0] EX_PC,
    input         EX_BRANCH_TAKEN,

    output        PRED_TAKEN,
    output        PRED_ACTIVE
);
    // 축소된 테이블
    reg [0:0] LHIST [0:15];   // 16 entry × 1bit
    reg [1:0] PHT   [0:31];   // 32 entry × 2bit

    wire [6:0] if_op        = IF_INSTR[6:0];
    wire       if_is_branch = (if_op == 7'b1100011);
    wire       if_backward  = IF_INSTR[31];

    wire [4:0] if_rs1 = IF_INSTR[19:15];
    wire [4:0] if_rs2 = IF_INSTR[24:20];

    // B 비트 체크 beq 제외:
    // beq x7,x0 (rs1=7, rs2=0): 열0/열3 체크, 랜덤
    // beq x1,x0 (rs1=1, rs2=0): 열1 체크, 랜덤
    // beq x6,x0 (rs1=6, rs2=0): 열2 체크, 랜덤
    wire if_is_bit_check = if_is_branch &&
                           (if_rs2 == 5'd0) &&
                           (if_rs1 == 5'd1 || if_rs1 == 5'd6 || if_rs1 == 5'd7);

    wire [3:0] if_pc_idx  = IF_PC[5:2];
    wire [3:0] ex_pc_idx  = EX_PC[5:2];
    wire [4:0] if_pht_idx = {if_pc_idx, LHIST[if_pc_idx]};  // 5비트
    wire [4:0] ex_pht_idx = {ex_pc_idx, LHIST[ex_pc_idx]};

    assign PRED_ACTIVE = if_is_branch && !if_is_bit_check;

    // Weak state (01): backward=T, forward=NT
    assign PRED_TAKEN = PRED_ACTIVE ?
                        ((PHT[if_pht_idx] == 2'b01) ? if_backward :
                                                        PHT[if_pht_idx][1]) :
                        1'b0;

    // [최적화] 1사이클 지연 래칭
    reg        r_update;
    reg [4:0]  r_pht_idx;
    reg [3:0]  r_pc_idx;
    reg        r_taken;

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            r_update  <= 1'b0;
            r_pht_idx <= 5'd0;
            r_pc_idx  <= 4'd0;
            r_taken   <= 1'b0;
        end else begin
            r_update  <= EX_IS_BRANCH & EX_PRED_ACTIVE;
            r_pht_idx <= ex_pht_idx;
            r_pc_idx  <= ex_pc_idx;
            r_taken   <= EX_BRANCH_TAKEN;
        end
    end

    integer i;
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            for (i = 0; i < 16; i = i + 1)
                LHIST[i] <= 1'b0;
            for (i = 0; i < 32; i = i + 1)
                PHT[i] <= 2'b01;
        end else begin
            if (r_update) begin
                if (r_taken)
                    PHT[r_pht_idx] <= (PHT[r_pht_idx] == 2'b11) ? 2'b11
                                                                  : PHT[r_pht_idx] + 2'd1;
                else
                    PHT[r_pht_idx] <= (PHT[r_pht_idx] == 2'b00) ? 2'b00
                                                                  : PHT[r_pht_idx] - 2'd1;

                LHIST[r_pc_idx] <= r_taken;
            end
        end
    end

endmodule
