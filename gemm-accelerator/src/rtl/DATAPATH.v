// DATAPATH.v
// 5단계 파이프라인 데이터패스
//
// [변경] REGFILE WE3_MASKED 연결
//   REGFILE이 WE3_MASKED (= WE3 & (A3 != x0)) 를 출력
//   → ID/EX 래칭 시 id_regwrite 대신 rf_we3_masked 사용
//   → EX/MEM, MEM/WB 로 전파되는 REGWRITE에 x0 마스킹 포함
//   → FORWARD Unit에서 (RD != x0) 조건 불필요
//
// [변경] 파이프라인 레지스터 reset/flush 분리
//   RESET : 비동기 (always sensitivity list에 posedge RESET)
//   flush : 동기   (else if (ex_flush) 로 처리)
//   → ELAB-303 에러 해소
//   → flush는 클럭 엣지에서만 발생하므로 동기 처리가 올바름

module DATAPATH (
    input         CLK,
    input         RESET,

    input  [31:0] INSTR,     // IMEM 출력 (IF 스테이지)
    input  [31:0] READDATA,  // DMEM 읽기 데이터 (MEM 스테이지)

    output [31:0] PC,        // IMEM 주소
    output [31:0] ALURESULT, // DMEM 주소 (EX/MEM)
    output [31:0] WRITEDATA, // DMEM 쓰기 데이터
    output        MEMWRITE,  // DMEM 쓰기 허용
    output        ZERO       // ALU zero (디버그용)
);

    //==========================================================
    // IF 스테이지
    //==========================================================
    reg  [31:0] if_pc;

    wire [31:0] if_pc_plus4 = if_pc + 32'd4;
    wire [31:0] if_instr    = INSTR;

    // Branch prediction 신호
    wire        pred_taken;
    wire        pred_active;

    // B-type immediate 조기 계산 (예측 target용)
    wire [31:0] if_bimm = {{20{INSTR[31]}},
                            INSTR[7],
                            INSTR[30:25],
                            INSTR[11:8],
                            1'b0};
    wire [31:0] pred_target = if_pc + if_bimm;

    // flush 신호 (EX 스테이지에서 생성)
    wire        ex_flush;
    wire [31:0] ex_pc_correct;
    wire        hazard_stall;

    // PC 다음값: flush > 예측 taken > PC+4
    wire [31:0] if_pc_next = ex_flush   ? ex_pc_correct :
                             pred_taken ? pred_target   :
                                          if_pc_plus4;

    // 55라인 수정
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            if_pc <= 32'd0;
        end else if (ex_flush) begin
            if (if_pc_next === 32'dx) if_pc <= 32'd0;
            else                      if_pc <= if_pc_next;
        end else if (hazard_stall) begin
            if_pc <= if_pc;
        end else begin
            // 만약 if_pc_next가 x라면 0으로 강제 초기화하여 오염 방지
            if (if_pc_next === 32'dx) if_pc <= 32'd0; 
            else                      if_pc <= if_pc_next;
        end
    end

    assign PC = if_pc;

    //==========================================================
    // IF/ID 파이프라인 레지스터
    //==========================================================
    reg [31:0] ifid_pc;
    reg [31:0] ifid_instr;
    reg        ifid_pred_taken;
    reg        ifid_pred_active;

    // RESET: 비동기 / flush: 동기 (ELAB-303 해소)
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            // 비동기 리셋
            ifid_pc          <= 32'd0;
            ifid_instr       <= 32'd0;
            ifid_pred_taken  <= 1'b0;
            ifid_pred_active <= 1'b0;
        end else if (ex_flush) begin
            // 동기 flush: mis-prediction 또는 JAL
            ifid_pc          <= 32'd0;
            ifid_instr       <= 32'd0;  // NOP: addi x0, x0, 0
            ifid_pred_taken  <= 1'b0;
            ifid_pred_active <= 1'b0;
        end else if (hazard_stall) begin
            ifid_pc          <= ifid_pc;
            ifid_instr       <= ifid_instr;
            ifid_pred_taken  <= ifid_pred_taken;
            ifid_pred_active <= ifid_pred_active;
        end else begin
            ifid_pc          <= if_pc;
            ifid_instr       <= if_instr;
            ifid_pred_taken  <= pred_taken;
            ifid_pred_active <= pred_active;
        end
    end

    //==========================================================
    // ID 스테이지
    // CONTROLLER를 여기서 인스턴스화 → ifid_instr 기준 디코딩
    //==========================================================
    wire [4:0] id_rs1 = ifid_instr[19:15];
    wire [4:0] id_rs2 = ifid_instr[24:20];
    wire [4:0] id_rd  = ifid_instr[11:7];

    wire [1:0] id_alucontrol;
    wire       id_alusrc;
    wire [1:0] id_resultsrc;
    wire       id_memwrite;
    wire       id_regwrite;
    wire       id_branch;
    wire       id_jump;
    wire [1:0] id_immsrc;

    CONTROLLER ctrl (
        .OP         (ifid_instr[6:0]),
        .FUNCT3     (ifid_instr[14:12]),
        .FUNCT7B5   (ifid_instr[30]),
        .RESULTSRC  (id_resultsrc),
        .MEMWRITE   (id_memwrite),
        .BRANCH     (id_branch),
        .ALUSRC     (id_alusrc),
        .REGWRITE   (id_regwrite),
        .JUMP       (id_jump),
        .IMMSRC     (id_immsrc),
        .ALUCONTROL (id_alucontrol)
    );

    wire [31:0] id_rd1, id_rd2, id_immext;
    wire [6:0]  id_op = ifid_instr[6:0];
    wire        id_uses_rs1 =
        (id_op == 7'b0000011) ||
        (id_op == 7'b0100011) ||
        (id_op == 7'b0110011) ||
        (id_op == 7'b1100011) ||
        (id_op == 7'b0010011);
    wire        id_uses_rs2 =
        (id_op == 7'b0100011) ||
        (id_op == 7'b0110011) ||
        (id_op == 7'b1100011);

    // WB 스테이지 신호
    wire        wb_regwrite;
    wire [4:0]  wb_rd;
    wire [31:0] wb_result;

    // WE3_MASKED: REGFILE 내부에서 (WE3 & (A3 != x0)) 계산
    wire rf_we3_masked;

    REGFILE rf (
        .CLK        (CLK),
        .WE3        (wb_regwrite),
        .A1         (id_rs1),
        .A2         (id_rs2),
        .A3         (wb_rd),
        .WD3        (wb_result),
        .RD1        (id_rd1),
        .RD2        (id_rd2),
        .WE3_MASKED (rf_we3_masked)
    );

    EXTEND ext (
        .INSTR  (ifid_instr[31:7]),
        .IMMSRC (id_immsrc),
        .IMMEXT (id_immext)
    );

    //==========================================================
    // ID/EX 파이프라인 레지스터
    //==========================================================
    reg [31:0] idex_pc;
    reg [31:0] idex_rd1, idex_rd2, idex_immext;
    reg [4:0]  idex_rs1, idex_rs2, idex_rd;
    reg [1:0]  idex_alucontrol;
    reg        idex_alusrc;
    reg [1:0]  idex_resultsrc;
    reg        idex_memwrite;
    reg        idex_regwrite;
    reg        idex_branch;
    reg        idex_jump;
    reg        idex_pred_taken;
    reg        idex_pred_active;
    reg [2:0]  idex_funct3;

    wire [31:0] exmem_aluresult;
    wire [4:0]  exmem_rd;
    wire        exmem_regwrite;

    wire raw_hazard_ex =
        idex_regwrite &&
        ((id_uses_rs1 && (id_rs1 == idex_rd)) ||
         (id_uses_rs2 && (id_rs2 == idex_rd)));

    wire raw_hazard_mem =
        exmem_regwrite &&
        ((id_uses_rs1 && (id_rs1 == exmem_rd)) ||
         (id_uses_rs2 && (id_rs2 == exmem_rd)));

    assign hazard_stall = raw_hazard_ex | raw_hazard_mem;

    // RESET: 비동기 / flush: 동기 (ELAB-303 해소)
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            // 비동기 리셋
            idex_pc          <= 32'd0;
            idex_rd1         <= 32'd0;
            idex_rd2         <= 32'd0;
            idex_immext      <= 32'd0;
            idex_rs1         <= 5'd0;
            idex_rs2         <= 5'd0;
            idex_rd          <= 5'd0;
            idex_alucontrol  <= 2'd0;
            idex_alusrc      <= 1'b0;
            idex_resultsrc   <= 2'b00;
            idex_memwrite    <= 1'b0;
            idex_regwrite    <= 1'b0;
            idex_branch      <= 1'b0;
            idex_jump        <= 1'b0;
            idex_pred_taken  <= 1'b0;
            idex_pred_active <= 1'b0;
            idex_funct3      <= 3'd0;
        end else if (ex_flush) begin
            // 동기 flush: NOP 삽입 (제어신호 전부 0)
            idex_pc          <= 32'd0;
            idex_rd1         <= 32'd0;
            idex_rd2         <= 32'd0;
            idex_immext      <= 32'd0;
            idex_rs1         <= 5'd0;
            idex_rs2         <= 5'd0;
            idex_rd          <= 5'd0;
            idex_alucontrol  <= 2'd0;
            idex_alusrc      <= 1'b0;
            idex_resultsrc   <= 2'b00;
            idex_memwrite    <= 1'b0;
            idex_regwrite    <= 1'b0;
            idex_branch      <= 1'b0;
            idex_jump        <= 1'b0;
            idex_pred_taken  <= 1'b0;
            idex_pred_active <= 1'b0;
            idex_funct3      <= 3'd0;
        end else if (hazard_stall) begin
            idex_pc          <= 32'd0;
            idex_rd1         <= 32'd0;
            idex_rd2         <= 32'd0;
            idex_immext      <= 32'd0;
            idex_rs1         <= 5'd0;
            idex_rs2         <= 5'd0;
            idex_rd          <= 5'd0;
            idex_alucontrol  <= 2'd0;
            idex_alusrc      <= 1'b0;
            idex_resultsrc   <= 2'b00;
            idex_memwrite    <= 1'b0;
            idex_regwrite    <= 1'b0;
            idex_branch      <= 1'b0;
            idex_jump        <= 1'b0;
            idex_pred_taken  <= 1'b0;
            idex_pred_active <= 1'b0;
            idex_funct3      <= 3'd0;
        end else begin
            idex_pc          <= ifid_pc;
            idex_rd1         <= id_rd1;
            idex_rd2         <= id_rd2;
            idex_immext      <= id_immext;
            idex_rs1         <= id_rs1;
            idex_rs2         <= id_rs2;
            idex_rd          <= id_rd;
            idex_alucontrol  <= id_alucontrol;
            idex_alusrc      <= id_alusrc;
            idex_resultsrc   <= id_resultsrc;
            idex_memwrite    <= id_memwrite;
            idex_regwrite    <= id_regwrite & (id_rd != 5'd0); // 이 명령 자신의 regwrite + x0 마스킹
            idex_branch      <= id_branch;
            idex_branch      <= id_branch;
            idex_jump        <= id_jump;
            idex_pred_taken  <= ifid_pred_taken;
            idex_pred_active <= ifid_pred_active;
            idex_funct3      <= ifid_instr[14:12];
        end
    end

    //==========================================================
    // EX 스테이지
    //==========================================================

    wire [31:0] ex_srca  = idex_rd1;
    wire [31:0] ex_reg_b = idex_rd2;

    wire [31:0] ex_srcb = idex_alusrc ? idex_immext : ex_reg_b;

    wire [31:0] ex_aluresult;
    wire        ex_zero;

    alu alu_inst (
        .a          (ex_srca),
        .b          (ex_srcb),
        .alucontrol (idex_alucontrol),
        .result     (ex_aluresult),
        .zero       (ex_zero)
    );

    assign ZERO = ex_zero;

    wire [31:0] ex_pc_plus4  = idex_pc + 32'd4;
    wire [31:0] ex_pc_target = idex_pc + idex_immext;

    wire ex_eq  = (ex_srca == ex_reg_b);
    wire ex_lts = ($signed(ex_srca) < $signed(ex_reg_b));
    wire ex_ltu = (ex_srca < ex_reg_b);

    reg ex_branch_cond;
    always @(*) begin
        case (idex_funct3)
            3'b000: ex_branch_cond = ex_eq;    // BEQ
            3'b001: ex_branch_cond = ~ex_eq;   // BNE
            3'b100: ex_branch_cond = ex_lts;   // BLT
            3'b101: ex_branch_cond = ~ex_lts;  // BGE
            3'b110: ex_branch_cond = ex_ltu;   // BLTU
            3'b111: ex_branch_cond = ~ex_ltu;  // BGEU
            default: ex_branch_cond = 1'b0;
        endcase
    end

    wire ex_branch_taken = idex_branch & ex_branch_cond;
    wire ex_jump_taken   = idex_jump;
    wire ex_take         = ex_branch_taken | ex_jump_taken;

    wire ex_mispred = idex_pred_active ? (idex_pred_taken != ex_take)
                                       : ex_take;

    assign ex_flush      = ex_mispred | ex_jump_taken;
    assign ex_pc_correct = ex_take ? ex_pc_target : ex_pc_plus4;

    wire [31:0] ex_result_final = ex_jump_taken ? ex_pc_plus4 : ex_aluresult;
    wire [31:0] ex_writedata    = ex_reg_b;

    //==========================================================
    // EX/MEM 파이프라인 레지스터
    //==========================================================
    reg [31:0] exmem_aluresult_r;
    reg [31:0] exmem_writedata;
    reg [4:0]  exmem_rd_r;
    reg [1:0]  exmem_resultsrc;
    reg        exmem_memwrite_r;
    reg        exmem_regwrite_r;

    assign exmem_aluresult = exmem_aluresult_r;
    assign exmem_rd        = exmem_rd_r;
    assign exmem_regwrite  = exmem_regwrite_r;
    assign MEMWRITE        = exmem_memwrite_r;
    assign ALURESULT       = exmem_aluresult_r;
    assign WRITEDATA       = exmem_writedata;

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            exmem_aluresult_r <= 32'd0;
            exmem_writedata   <= 32'd0;
            exmem_rd_r        <= 5'd0;
            exmem_resultsrc   <= 2'b00;
            exmem_memwrite_r  <= 1'b0;
            exmem_regwrite_r  <= 1'b0;
        end else begin
            exmem_aluresult_r <= ex_result_final;
            exmem_writedata   <= ex_writedata;
            exmem_rd_r        <= idex_rd;
            exmem_resultsrc   <= idex_resultsrc;
            exmem_memwrite_r  <= idex_memwrite;
            exmem_regwrite_r  <= idex_regwrite;
        end
    end

    //==========================================================
    // MEM 스테이지
    // 상위 24bit 접지: A/B 행렬 영역(0x000~0x1FF)
    //==========================================================
    wire        mem_in_ab     = (exmem_aluresult_r < 32'h200);
    wire [31:0] mem_rd_masked = mem_in_ab ? {24'b0, READDATA[7:0]} : READDATA;

    //==========================================================
    // MEM/WB 파이프라인 레지스터
    //==========================================================
    reg [31:0] memwb_aluresult;
    reg [31:0] memwb_readdata;
    reg [4:0]  memwb_rd;
    reg [1:0]  memwb_resultsrc;
    reg        memwb_regwrite;

    assign wb_rd       = memwb_rd;
    assign wb_regwrite = memwb_regwrite;

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            memwb_aluresult <= 32'd0;
            memwb_readdata  <= 32'd0;
            memwb_rd        <= 5'd0;
            memwb_resultsrc <= 2'b00;
            memwb_regwrite  <= 1'b0;
        end else begin
            memwb_aluresult <= exmem_aluresult_r;
            memwb_readdata  <= mem_rd_masked;
            memwb_rd        <= exmem_rd_r;
            memwb_resultsrc <= exmem_resultsrc;
            memwb_regwrite  <= exmem_regwrite_r;
        end
    end

    //==========================================================
    // WB 스테이지
    //==========================================================
    reg [31:0] wb_result_r;

    always @(*) begin
        case (memwb_resultsrc)
            2'b00:   wb_result_r = memwb_aluresult;
            2'b01:   wb_result_r = memwb_readdata;
            2'b10:   wb_result_r = memwb_aluresult; // JAL PC+4
            default: wb_result_r = 32'd0;
        endcase
    end

    assign wb_result = wb_result_r;

    //==========================================================
    // Branch Predictor
    //==========================================================
    BRANCH_PRED bp (
        .CLK             (CLK),
        .RESET           (RESET),
        .IF_PC           (if_pc),
        .IF_INSTR        (if_instr),
        .EX_IS_BRANCH    (idex_branch),
        .EX_PRED_ACTIVE  (idex_pred_active),
        .EX_PC           (idex_pc),
        .EX_BRANCH_TAKEN (ex_branch_taken),
        .PRED_TAKEN      (pred_taken),
        .PRED_ACTIVE     (pred_active)
    );

endmodule
