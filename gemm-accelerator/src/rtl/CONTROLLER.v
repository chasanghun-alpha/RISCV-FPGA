// CONTROLLER.v
// 파이프라인용 컨트롤러
// DATAPATH 내부에서 인스턴스화됨 → ifid_instr 기준으로 디코딩
// PCSRC는 EX 스테이지 DATAPATH 내부에서 처리하므로 여기서는 생성 안 함

module CONTROLLER (
    input  [6:0] OP,
    input  [2:0] FUNCT3,
    input        FUNCT7B5,
    output [1:0] RESULTSRC,
    output       MEMWRITE,
    output       BRANCH,
    output       ALUSRC,
    output       REGWRITE,
    output       JUMP,
    output [1:0] IMMSRC,
    output [1:0] ALUCONTROL
);
    wire [1:0] ALUOP;

    MAINDEC MD (
        .OP        (OP),
        .RESULTSRC (RESULTSRC),
        .MEMWRITE  (MEMWRITE),
        .BRANCH    (BRANCH),
        .ALUSRC    (ALUSRC),
        .REGWRITE  (REGWRITE),
        .JUMP      (JUMP),
        .IMMSRC    (IMMSRC),
        .ALUOP     (ALUOP)
    );

    ALUDEC AD (
        .OPB5       (OP[5]),
        .FUNCT3     (FUNCT3),
        .FUNCT7B5   (FUNCT7B5),
        .ALUOP      (ALUOP),
        .ALUCONTROL (ALUCONTROL)
    );

endmodule
