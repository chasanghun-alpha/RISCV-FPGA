// ALUDEC.v
// ALU 제어 신호 생성
//
// ALUOP 인코딩 (MAINDEC 출력):
//   2'b00 : ADD 고정  (LW, SW, JAL)
//   2'b01 : SUB 고정  (BEQ zero 검출)
//   2'b10 : R-type    (funct3으로 결정)
//   2'b11 : I-type    (funct3으로 결정)
//
// 사용되는 funct3:
//   R-type  funct3=000 : ADD (funct7b5=0) / SUB (funct7b5=1)
//   I-type  funct3=000 : ADDI
//   I-type  funct3=111 : ANDI   ← shift-and-add 비트 마스킹
//
// 제거된 funct3:
//   010 (SLT/SLTI)  : swap 로직 제거로 미사용
//   110 (OR/ORI)    : 미사용
//   001,100,101     : shift 계열, 미지원

module ALUDEC (
    input        OPB5,      // instr[5]: R-type=1, I-type=0
    input  [2:0] FUNCT3,
    input        FUNCT7B5,  // instr[30]: SUB 판별용
    input  [1:0] ALUOP,
    output reg [1:0] ALUCONTROL
);
    // R-type SUB: funct7[5]=1, opcode[5]=1, ALUOP=10
    wire RTYPESUB = FUNCT7B5 & OPB5 & (ALUOP == 2'b10);

    always @(*) begin
        case (ALUOP)
            2'b00: ALUCONTROL = 2'b00;  // ADD (LW/SW/JAL)
            2'b01: ALUCONTROL = 2'b01;  // SUB (BEQ)
            default: begin
                case (FUNCT3)
                    2'b00: ALUCONTROL = RTYPESUB ? 2'b01 : 2'b00; // ADD / SUB
                    3'b111: ALUCONTROL = 2'b10;  // AND / ANDI
                    default: ALUCONTROL = 2'b00;
                endcase
            end
        endcase
    end

endmodule
