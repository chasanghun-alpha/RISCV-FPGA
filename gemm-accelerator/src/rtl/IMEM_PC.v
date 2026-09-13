// IMEM.v
// Instruction Memory (원본과 동일, 변경 없음)

module IMEM (
    input  [31:0] A,
    output [31:0] RD,

    input         DBG_EN,
    input  [31:0] DBG_A,
    output [31:0] DBG_RD
);
    reg [31:0] RAM [0:171];

    initial begin
        $readmemh("my_gemm8x8.txt", RAM);
    end

    assign RD     = RAM[A[31:2]];
    assign DBG_RD = RAM[DBG_A[31:2]];

endmodule

