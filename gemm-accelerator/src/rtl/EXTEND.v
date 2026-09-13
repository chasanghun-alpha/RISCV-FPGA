// EXTEND.v
// 지원 immediate 타입: I / S / B / J
// U-type (LUI, AUIPC) 미지원이므로 제거

module EXTEND (
    input  [31:7] INSTR,
    input  [ 1:0] IMMSRC,
    output reg [31:0] IMMEXT
);
    always @(*) begin
        case (IMMSRC)
            2'b00: IMMEXT = {{20{INSTR[31]}}, INSTR[31:20]};
                   // I-type: LW, ADDI, ANDI, ORI, SLTI
            2'b01: IMMEXT = {{20{INSTR[31]}}, INSTR[31:25], INSTR[11:7]};
                   // S-type: SW
            2'b10: IMMEXT = {{20{INSTR[31]}}, INSTR[7], INSTR[30:25], INSTR[11:8], 1'b0};
                   // B-type: BEQ
            2'b11: IMMEXT = {{12{INSTR[31]}}, INSTR[19:12], INSTR[20], INSTR[30:21], 1'b0};
                   // J-type: JAL
            default: IMMEXT = 32'bx;
        endcase
    end

endmodule
