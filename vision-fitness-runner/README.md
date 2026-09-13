# RISC-V Processor와 Vision Sensor를 활용한 FPGA 기반 Fitness Runner Game

**과목/분야**: 디지털회로모델링및실험 (Project 2, 2인 팀)
**기간**: [추가 정보 필요]
**사용 도구**: Verilog HDL, Intel Quartus (DE2 FPGA), HuskyLens AI Vision Sensor, Raspberry Pi 5 (Python, pyserial, Flask, HTML Canvas), ChatGPT/Codex (설계 보조)

📄 원본 보고서: [docs/FPGA_Fitness_Runner_Report.pdf](docs/FPGA_Fitness_Runner_Report.pdf)

## 개요
사용자의 신체 움직임을 게임 입력으로 변환하는 임베디드 피트니스 시스템
1. HuskyLens가 얼굴 좌표 인식
2. FPGA 로직이 좌표 수신·파싱
3. FPGA 내부의 RISC-V soft processor가 MMIO로 좌표를 읽어 게임 프레임 생성
4. Raspberry Pi 웹 게임이 캐릭터의 좌우 이동과 점프로 반영

## 문제 정의
- HuskyLens ↔ FPGA UART 통신으로 사람 위치 데이터 수신
- FPGA 내 RISC-V 32-bit processor 통합과 MMIO 기반 센서 접근
- RISC-V software가 xCenter, yCenter 변화량으로 게임 입력 프레임을 생성해 UART로 전송
- Raspberry Pi Flask 서버에서 실시간 게임 UI로 시각화하는 end-to-end 통합

## 설계 및 구현
**시스템 흐름**
```
사용자 움직임 → HuskyLens (UART 9600 8N1) → FPGA huskylens_core (Receiver/Parser)
→ MMIO Register → RISC-V 32-bit Processor → UART TX Frame
→ Raspberry Pi Python Receiver → Flask Web Game UI
```

**RISC-V Processor**
- 5-stage pipeline, forwarding, load-use stall, misprediction flush
- 32-entry 2-bit saturating counter BHT(PC[6:2] index) dynamic branch predictor

**MMIO Memory Map**
| 주소 | R/W | 내용 |
|---|---|---|
| 0x4000_0000 | R | HuskyLens status ([10]Done [9]No_Person [8]Fail [7]Block [6]OK) |
| 0x4000_0004 / 0008 | R | X center / Y center [15:0] |
| 0x4000_000C | R | 마지막 수신 byte |
| 0x4000_0020 | R | UART TX busy |
| 0x4000_0024 | W | UART TX data |

**HuskyLens FSM**: IDLE → SEND_KNOCK → WAIT_OK → SEND_REQUEST → WAIT_RESPONSE → PARSE_RESPONSE → DECIDE → SAMPLE_GAP (→ FAIL)
(50 MHz 기준 CLKS_PER_BIT = 5208, TTL UART는 GPIO에 연결하고 DB9 RS-232는 사용하지 않음)

**동작 판별 / 게임 프레임**
```
X_scaled = xCenter / 2                     (0~159)
delta    = 현재 yCenter − 이전 yCenter
JUMP     : delta < −15 AND yCenter < baseline × 3/4   (속도 + 위치 조건으로 오탐 감소)
Frame    : [0xFF][X_scaled][delta+128][action(0=RUN, 1=JUMP)]
Stop     : [0xFE]['S']['T']['P']  (KEY[2])
```

**역할 분담 (HW/SW)**
- FPGA logic: UART 송수신, 프로토콜 파싱, MMIO 제공, 버튼·타임아웃 이벤트 처리
- RISC-V software: 폴링, 스케일링, delta·action 계산, 프레임 전송
- Raspberry Pi: 프레임 수신, 게임 캐릭터·장애물·칼로리·세트 진행률 표시, controller/spectator 모드 관리

**본인 담당 (보고서 역할 분담 기준)**
- FPGA/RISC-V Hardware: TOP.v 통합, Quartus 설정, pin assignment, SDC
- DATAPATH pipeline, forwarding, stall, flush 검토와 BHT predictor 적용
- huskylens_core.v UART 통신 구현·검증
- 게임 시스템·UI 업그레이드, 데모 영상 제작

## 결과
- Demo 3단계 검증:
  1. FPGA ↔ HuskyLens knock/OK/request/response 통신
  2. RISC-V MMIO 읽기와 4-byte 프레임 전송
  3. Raspberry Pi 웹 게임에서 좌우 이동과 점프 동작
- 웹 UI에 UART 상태, x, delta, action, frame count, jump event count, 칼로리, 세트 진행률 표시
- 센서가 없을 때도 UI를 검증할 수 있는 keyboard demo mode 제공
- **Quartus 합성 0 errors, 50 MHz 기준 timing slack 확보**
- 해결한 주요 문제:
  - USB-Blaster driver Code 39
  - Top-level entity mismatch
  - DATAPATH async reset / sync flush 분리
  - UART TX/RX 교차 연결
  - RS-232와 TTL 전압 레벨 차이
  - Face Detection 모드 채택과 마지막 좌표 latch
  - `jump_events` 누적 카운터로 짧은 점프 프레임 누락 해결

## 배운 점 / 의의
- 센서 입력부터 웹 출력까지 이어지는 end-to-end 시스템에서는 UART frame format, MMIO address map, GPIO pin, action encoding 같은 **팀원 간 인터페이스 정의**가 통합 성공의 핵심
- AI Agent를 코드 생성뿐 아니라 요구사항 프롬프트 설계와 디버깅 정리에 활용. 결과는 Quartus 컴파일, 실제 UART 출력, 웹 화면으로 직접 검증
- 개선 방향:
  - 마커 기반 multi-object tracking
  - RISC-V GCC toolchain 기반 C 개발
  - Checksum / sequence number
  - 양방향 UART
  - 운동 모드 확장

> 소스 코드(TOP.v, huskylens_core.v, MMIO.v, rpi_uart_receive.py 등): [추가 정보 필요]
