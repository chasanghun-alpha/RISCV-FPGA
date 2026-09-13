// REGFILE.v
// 32개 32-bit 레지스터
// x0는 항상 0 (읽기: 하드와이어 0, 쓰기: 무시)
// 비동기 읽기, 동기 쓰기
//
// [추가] WE3_MASKED 출력:
//   WE3 && (A3 != x0) 를 내부에서 계산하여 출력
//   → DATAPATH에서 ID/EX 래칭 시 이 신호를 사용하면
//     FORWARD Unit 조건에서 (RD != x0) 비교 제거 가능
//   → 게이트 단수 감소, 코드 단순화

module REGFILE (
    input         CLK,
    input         WE3,
    input  [ 4:0] A1, A2, A3,
    input  [31:0] WD3,
    output [31:0] RD1, RD2,
    output        WE3_MASKED   // WE3 & (A3 != x0)
);
    reg [31:0] RF [0:31];

    // x0 = 0 보장 (하드와이어)
    // [수정] write-first: WB에서 같은 레지스터를 쓰는 중이면 WD3 우선 사용
    // WB posedge와 ID posedge가 같은 클럭 → non-blocking으로 이전값 읽힘 방지
    assign RD1 = (A1 == 5'd0) ? 32'd0 :
                 (WE3_MASKED && (A3 == A1)) ? WD3 : RF[A1];
    assign RD2 = (A2 == 5'd0) ? 32'd0 :
                 (WE3_MASKED && (A3 == A2)) ? WD3 : RF[A2];

    // x0 마스킹 포함 REGWRITE
    // 이 신호를 파이프라인 레지스터에 래칭하면
    // FORWARD에서 별도로 (RD != x0) 를 검사할 필요 없음
    assign WE3_MASKED = WE3 & (A3 != 5'd0);

    always @(posedge CLK) begin
        if (WE3_MASKED)
            RF[A3] <= WD3;
    end

endmodule