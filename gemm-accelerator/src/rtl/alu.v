// alu.v
// 사용 연산:
//   ADD (2'b00): add, addi, lw/sw 주소계산
//   SUB (2'b01): beq zero 검출
//   AND (2'b10): and
//
// alucontrol 2bit (상위 bit 제거)
// 합성툴이 자동으로 최적 adder 선택

module alu (
    input  [31:0] a,
    input  [31:0] b,
    input  [ 1:0] alucontrol,
    output reg [31:0] result,
    output            zero
);
    always @(*) begin
        case (alucontrol)
            2'b00:   result = a + b;  // ADD
            2'b01:   result = a - b;  // SUB
            2'b10:   result = a & b;  // AND
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule
