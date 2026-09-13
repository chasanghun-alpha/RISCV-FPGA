// TOP_GEMM.v
// 최상위 래퍼: 파이프라인 RISCVSINGLE + IMEM + DMEM
// 원본 포트 인터페이스 유지

`timescale 1ns/1ps

module TOP_GEMM (
    input         CLK,
    input         RESET,

    // CPU 관찰용
    output [31:0] PC,
    output [31:0] DATAADR,
    output [31:0] WRITEDATA,
    output        MEMWRITE,

    // IMEM 디버그 포트
    input         IMEM_DBG_EN,
    input  [31:0] IMEM_DBG_A,
    output [31:0] IMEM_DBG_RD,

    // DMEM 디버그 포트
    input         DMEM_DBG_EN,
    input         DMEM_DBG_WE,
    input  [31:0] DMEM_DBG_A,
    input  [31:0] DMEM_DBG_WD,
    output [31:0] DMEM_DBG_RD
);
    wire [31:0] instr;
    wire [31:0] readdata;
    wire [31:0] pc_i;
    wire [31:0] dataadr_i;
    wire [31:0] writedata_i;
    wire        memwrite_i;

    assign PC        = pc_i;
    assign DATAADR   = dataadr_i;
    assign WRITEDATA = writedata_i;
    assign MEMWRITE  = memwrite_i;

    // 파이프라인 CPU
    RISCVMULTI CPU (
        .CLK       (CLK),
        .RESET     (RESET),
        .PC        (pc_i),
        .INSTR     (instr),
        .MEMWRITE  (memwrite_i),
        .ALURESULT (dataadr_i),
        .WRITEDATA (writedata_i),
        .READDATA  (readdata)
    );

    // Instruction Memory
    IMEM imem (
        .A      (pc_i),
        .RD     (instr),
        .DBG_EN (IMEM_DBG_EN),
        .DBG_A  (IMEM_DBG_A),
        .DBG_RD (IMEM_DBG_RD)
    );

    // Data Memory
    // DEPTH=792: A(64) + B(64) + C(64) + STATUS(1) + 여유
    DMEM #(.DEPTH(792)) dmem (
        .CLK    (CLK),
        .WE     (memwrite_i),
        .A      (dataadr_i),
        .WD     (writedata_i),
        .RD     (readdata),
        .DBG_EN (DMEM_DBG_EN),
        .DBG_WE (DMEM_DBG_WE),
        .DBG_A  (DMEM_DBG_A),
        .DBG_WD (DMEM_DBG_WD),
        .DBG_RD (DMEM_DBG_RD)
    );

endmodule
