// RISCVMULTI.v
// 5단계 파이프라인 RISC-V CPU (GEMM 전용)
//
// 지원 명령어: LW, SW, ADD, SUB, ADDI, ANDI, BEQ, JAL
// 제외: JALR, LUI, AUIPC, OR/AND(R-type 미사용), SLT, shift 계열
//
// [변경] CONTROLLER가 DATAPATH 내부로 이동됨
//   → CONTROLLER 입력이 ifid_instr (IF/ID 레지스터 출력) 에 연결
//   → 이전 구조의 타이밍 오류 (INSTR 직결) 해소
//
// DATAPATH가 CONTROLLER, BRANCH_PRED, FORWARD, REGFILE,
// EXTEND, ALU를 모두 포함하여 파이프라인을 완전히 구현

module RISCVMULTI (
    input         CLK,
    input         RESET,

    // IMEM 인터페이스
    output [31:0] PC,
    input  [31:0] INSTR,

    // DMEM 인터페이스
    output        MEMWRITE,
    output [31:0] ALURESULT,
    output [31:0] WRITEDATA,
    input  [31:0] READDATA
);
    DATAPATH dp (
        .CLK       (CLK),
        .RESET     (RESET),
        .INSTR     (INSTR),
        .READDATA  (READDATA),
        .PC        (PC),
        .ALURESULT (ALURESULT),
        .WRITEDATA (WRITEDATA),
        .MEMWRITE  (MEMWRITE),
        .ZERO      ()
    );

endmodule
