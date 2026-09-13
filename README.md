# RISCV-FPGA

**과목/분야**: 디지털회로모델링및실험 (2인 팀)
**기간**: [추가 정보 필요]
**사용 도구**: Verilog HDL, RISC-V ISA 설계, Synopsys Design Compiler, VCS/Verdi, Intel Quartus (FPGA), HuskyLens AI Vision Sensor, Raspberry Pi (Python / Flask)

## 개요
RISC-V 5-stage pipeline 프로세서를 직접 설계하고 개선한 프로젝트 2개를 모았습니다.

| 프로젝트 | 핵심 내용 | 주요 결과 |
|---|---|---|
| [gemm-accelerator](gemm-accelerator/) | 8×8 GEMM(행렬곱) 워크로드에 맞춘 RISC-V 프로세서 microarchitecture + assembly 공동 최적화, PPA 분석 | Energy 129 nJ → 37.6 nJ, execution time 38 μs → 9.10 μs (보고서 PPA 표 기준) |
| [vision-fitness-runner](vision-fitness-runner/) | FPGA 위 RISC-V soft processor + HuskyLens + Raspberry Pi 웹 게임 연동 | 얼굴 좌표 기반 좌우 이동·점프 입력 end-to-end 시스템 구현, Quartus 0 errors |

## 폴더 구조
```
RISCV-FPGA/
├── gemm-accelerator/
│   ├── docs/images/ # 시뮬레이션 결과 이미지
│   └── src/
│       ├── rtl/     # RISC-V core RTL, TOP_GEMM wrapper, testbench, assembly, assembler
│       └── syn/     # Design Compiler area/power report, SDC
└── vision-fitness-runner/  # README (설계·결과 정리)
```
