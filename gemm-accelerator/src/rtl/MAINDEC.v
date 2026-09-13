// MAINDEC.v
// 지원 opcode:
//   LW    0000011 : 메모리 읽기
//   SW    0100011 : 메모리 쓰기
//   R     0110011 : ADD, SUB (AND/OR/SLT는 미사용)
//   BEQ   1100011 : 분기
//   I-ALU 0010011 : ADDI, ANDI (ORI/SLTI 미사용)
//   JAL   1101111 : 무조건 점프
//
// 제거: JALR, LUI, AUIPC 및 모든 미지원 opcode
//
// CONTROLS = {REGWRITE, IMMSRC[1:0], ALUSRC, MEMWRITE,
//             RESULTSRC[1:0], BRANCH, ALUOP[1:0], JUMP}
//
// RESULTSRC:
//   2'b00 : ALU result
//   2'b01 : Memory read data (LW)
//   2'b10 : PC+4 (JAL 복귀주소)
//
// IMMSRC:
//   2'b00 : I-type
//   2'b01 : S-type
//   2'b10 : B-type
//   2'b11 : J-type
//
// ALUOP:
//   2'b00 : ADD 고정 (LW/SW/JAL)
//   2'b01 : SUB 고정 (BEQ)
//   2'b10 : R-type (funct3 참조)
//   2'b11 : I-type (funct3 참조)

module MAINDEC (
    input  [6:0] OP,
    output [1:0] RESULTSRC,
    output       MEMWRITE,
    output       BRANCH,
    output       ALUSRC,
    output       REGWRITE,
    output       JUMP,
    output [1:0] IMMSRC,
    output [1:0] ALUOP
);
    reg [10:0] CONTROLS;

    // {REGWRITE, IMMSRC[1:0], ALUSRC, MEMWRITE, RESULTSRC[1:0], BRANCH, ALUOP[1:0], JUMP}
    assign {REGWRITE, IMMSRC, ALUSRC, MEMWRITE,
            RESULTSRC, BRANCH, ALUOP, JUMP} = CONTROLS;

    always @(*) begin
        case (OP)
            7'b0000011: CONTROLS = 11'b1_00_1_0_01_0_00_0; // LW
            7'b0100011: CONTROLS = 11'b0_01_1_1_00_0_00_0; // SW
            7'b0110011: CONTROLS = 11'b1_00_0_0_00_0_10_0; // R-type
            7'b1100011: CONTROLS = 11'b0_10_0_0_00_1_01_0; // BEQ
            7'b0010011: CONTROLS = 11'b1_00_1_0_00_0_11_0; // I-ALU (ADDI, ANDI)
            7'b1101111: CONTROLS = 11'b1_11_0_0_10_0_00_1; // JAL
            default:    CONTROLS = 11'b0_00_0_0_00_0_00_0;
        endcase
    end

endmodule
