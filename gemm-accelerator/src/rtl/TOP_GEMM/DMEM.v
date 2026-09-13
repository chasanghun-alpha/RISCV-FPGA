// DMEM.v
// 데이터 메모리
//
// 상위 24bit 접지 처리 방식:
//   DMEM은 32bit raw 데이터를 그대로 출력 (RD = RAM[addr])
//   A/B 행렬 영역(0x000~0x1FF)의 상위 24bit 접지는
//   DATAPATH의 MEM 스테이지에서 주소 기반으로 마스킹 처리
//   → DMEM과 DATAPATH 양쪽에서 이중 마스킹하던 구조 정리
//
// 쓰기:
//   DBG_EN && DBG_WE 우선, 그 다음 CPU WE

module DMEM #(parameter DEPTH = 792) (
    input         CLK,

    // CPU 포트
    input         WE,
    input  [31:0] A,
    input  [31:0] WD,
    output [31:0] RD,

    // 디버그 포트
    input         DBG_EN,
    input         DBG_WE,
    input  [31:0] DBG_A,
    input  [31:0] DBG_WD,
    output [31:0] DBG_RD
);
    reg [31:0] RAM [0:DEPTH-1];

    // CPU 읽기: word-aligned, raw 출력
    // 상위 24bit 접지는 DATAPATH MEM 스테이지에서 처리
    assign RD     = RAM[A[31:2]];

    // 디버그 읽기
    assign DBG_RD = RAM[DBG_A[31:2]];

    // 쓰기: 동기, DBG 우선
    always @(posedge CLK) begin
        if (DBG_EN && DBG_WE)
            RAM[DBG_A[31:2]] <= DBG_WD;
        else if (WE)
            RAM[A[31:2]] <= WD;
    end

endmodule
