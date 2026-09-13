// FORWARD.v
// EX-EX Forwarding Only (MEM-EX 제거)
//
// 현재 4×4 타일링 코드에서 MEM-EX(gap=2) forwarding이
// 루프 내부에서 실제로 발생하지 않으므로 제거
//
// fwd 인코딩 (1bit로 단순화):
//   1'b1: EX/MEM → EX (EX-EX forwarding)
//   1'b0: RF 직접 읽기
//
// [효과]
//   MEM_WB_RD 비교기 제거 → 면적 감소
//   critical path에서 OR 게이트 1단 제거 → timing 소폭 개선
//   MUX 3입력 → 2입력 단순화

module FORWARD (
    input  [4:0] ID_EX_RS1,
    input  [4:0] ID_EX_RS2,

    input  [4:0] EX_MEM_RD,
    input        EX_MEM_REGWRITE,

    output       FORWARD_A,
    output       FORWARD_B
);
    assign FORWARD_A = EX_MEM_REGWRITE && (EX_MEM_RD != 5'd0) && (EX_MEM_RD == ID_EX_RS1);
    assign FORWARD_B = EX_MEM_REGWRITE && (EX_MEM_RD != 5'd0) && (EX_MEM_RD == ID_EX_RS2);

endmodule
