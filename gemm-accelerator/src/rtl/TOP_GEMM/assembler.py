# -*- coding: utf-8 -*-
import sys
import os

# -----------------------------------------------------------------------------
# RISC-V Assembler (RV32I + RV32M)
# Usage: python assembler.py <input.s> <output.hex>
# -----------------------------------------------------------------------------

REGISTERS = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
    's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}

INSTRUCTIONS = {
    # --- R-Type ---
    'add':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x00},
    'sub':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x20},
    'sll':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x1, 'funct7': 0x00},
    'slt':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x2, 'funct7': 0x00},
    'sltu': {'type': 'R', 'opcode': 0x33, 'funct3': 0x3, 'funct7': 0x00},
    'xor':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x4, 'funct7': 0x00},
    'srl':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x00},
    'sra':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x20},
    'or':   {'type': 'R', 'opcode': 0x33, 'funct3': 0x6, 'funct7': 0x00},
    'and':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x7, 'funct7': 0x00},
    
    # RV32M
    'mul':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x0, 'funct7': 0x01},
    'mulh':   {'type': 'R', 'opcode': 0x33, 'funct3': 0x1, 'funct7': 0x01},
    'mulhsu': {'type': 'R', 'opcode': 0x33, 'funct3': 0x2, 'funct7': 0x01},
    'mulhu':  {'type': 'R', 'opcode': 0x33, 'funct3': 0x3, 'funct7': 0x01},
    'div':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x4, 'funct7': 0x01},
    'divu':   {'type': 'R', 'opcode': 0x33, 'funct3': 0x5, 'funct7': 0x01},
    'rem':    {'type': 'R', 'opcode': 0x33, 'funct3': 0x6, 'funct7': 0x01},
    'remu':   {'type': 'R', 'opcode': 0x33, 'funct3': 0x7, 'funct7': 0x01},

    # --- I-Type ---
    'lb':   {'type': 'I', 'opcode': 0x03, 'funct3': 0x0},
    'lh':   {'type': 'I', 'opcode': 0x03, 'funct3': 0x1},
    'lw':   {'type': 'I', 'opcode': 0x03, 'funct3': 0x2},
    'lbu':  {'type': 'I', 'opcode': 0x03, 'funct3': 0x4},
    'lhu':  {'type': 'I', 'opcode': 0x03, 'funct3': 0x5},
    'addi': {'type': 'I', 'opcode': 0x13, 'funct3': 0x0},
    'slti': {'type': 'I', 'opcode': 0x13, 'funct3': 0x2},
    'sltiu':{'type': 'I', 'opcode': 0x13, 'funct3': 0x3},
    'xori': {'type': 'I', 'opcode': 0x13, 'funct3': 0x4},
    'ori':  {'type': 'I', 'opcode': 0x13, 'funct3': 0x6},
    'andi': {'type': 'I', 'opcode': 0x13, 'funct3': 0x7},
    'jalr': {'type': 'I', 'opcode': 0x67, 'funct3': 0x0},
    
    # I-Type Shifts
    'slli': {'type': 'I_SHIFT', 'opcode': 0x13, 'funct3': 0x1, 'funct7': 0x00},
    'srli': {'type': 'I_SHIFT', 'opcode': 0x13, 'funct3': 0x5, 'funct7': 0x00},
    'srai': {'type': 'I_SHIFT', 'opcode': 0x13, 'funct3': 0x5, 'funct7': 0x20},

    # --- S-Type ---
    'sb':   {'type': 'S', 'opcode': 0x23, 'funct3': 0x0},
    'sh':   {'type': 'S', 'opcode': 0x23, 'funct3': 0x1},
    'sw':   {'type': 'S', 'opcode': 0x23, 'funct3': 0x2},

    # --- B-Type ---
    'beq':  {'type': 'B', 'opcode': 0x63, 'funct3': 0x0},
    'bne':  {'type': 'B', 'opcode': 0x63, 'funct3': 0x1},
    'blt':  {'type': 'B', 'opcode': 0x63, 'funct3': 0x4},
    'bge':  {'type': 'B', 'opcode': 0x63, 'funct3': 0x5},
    'bltu': {'type': 'B', 'opcode': 0x63, 'funct3': 0x6},
    'bgeu': {'type': 'B', 'opcode': 0x63, 'funct3': 0x7},

    # --- U-Type ---
    'lui':   {'type': 'U', 'opcode': 0x37},
    'auipc': {'type': 'U', 'opcode': 0x17},

    # --- J-Type ---
    'jal':   {'type': 'J', 'opcode': 0x6f},
}

def get_reg(reg_name):
    reg_name = reg_name.strip().replace(',', '')
    if reg_name in REGISTERS: return REGISTERS[reg_name]
    if reg_name.startswith('x'):
        try:
            val = int(reg_name[1:])
            if 0 <= val <= 31: return val
        except: pass
    print(f"Error: Invalid register '{reg_name}'")
    sys.exit(1)

def get_imm(imm_str):
    imm_str = imm_str.strip()
    try: return int(imm_str, 0)
    except:
        print(f"Error: Invalid immediate '{imm_str}'")
        sys.exit(1)

def to_bin(val, bits):
    val = val & ((1 << bits) - 1)
    return f"{val:0{bits}b}"

def assemble_file(input_file, output_file):
    if not os.path.exists(input_file):
        print(f"Error: Input file '{input_file}' not found.")
        sys.exit(1)

    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Pass 1: Labels
    labels = {}
    pc = 0
    clean_lines = []
    
    for line in lines:
        line = line.split('#')[0].strip()
        if not line: continue
        
        # [수정됨] .text, .globl 등 어셈블러 지시어는 무시
        if line.startswith('.'):
            continue

        if line.endswith(':'):
            labels[line[:-1]] = pc
        else:
            clean_lines.append((pc, line))
            pc += 4

    # Pass 2: Encoding
    hex_output = []
    for pc, line in clean_lines:
        parts = line.replace(',', ' ').split()
        op = parts[0]
        
        if op not in INSTRUCTIONS:
            print(f"Error: Unknown instruction '{op}' at PC {pc:08x}")
            sys.exit(1)
            
        info = INSTRUCTIONS[op]
        fmt = info['type']
        opcode = info['opcode']
        bin_str = ""

        try:
            if fmt == 'R':
                rd, rs1, rs2 = get_reg(parts[1]), get_reg(parts[2]), get_reg(parts[3])
                bin_str = f"{to_bin(info['funct7'], 7)}{to_bin(rs2, 5)}{to_bin(rs1, 5)}{to_bin(info['funct3'], 3)}{to_bin(rd, 5)}{to_bin(opcode, 7)}"
                
            elif fmt == 'I':
                rd = get_reg(parts[1])
                if op in ['lb', 'lh', 'lw', 'lbu', 'lhu', 'jalr'] and '(' in parts[2]:
                    imm_s, rs1_s = parts[2].split('(')
                    imm, rs1 = get_imm(imm_s), get_reg(rs1_s.replace(')', ''))
                else:
                    rs1, imm = get_reg(parts[2]), get_imm(parts[3])
                bin_str = f"{to_bin(imm, 12)}{to_bin(rs1, 5)}{to_bin(info['funct3'], 3)}{to_bin(rd, 5)}{to_bin(opcode, 7)}"
            
            elif fmt == 'I_SHIFT':
                rd, rs1, imm = get_reg(parts[1]), get_reg(parts[2]), get_imm(parts[3])
                bin_str = f"{to_bin(info['funct7'], 7)}{to_bin(imm, 5)}{to_bin(rs1, 5)}{to_bin(info['funct3'], 3)}{to_bin(rd, 5)}{to_bin(opcode, 7)}"

            elif fmt == 'S':
                rs2 = get_reg(parts[1])
                imm_s, rs1_s = parts[2].split('(')
                imm, rs1 = get_imm(imm_s), get_reg(rs1_s.replace(')', ''))
                bin_str = f"{to_bin(imm >> 5, 7)}{to_bin(rs2, 5)}{to_bin(rs1, 5)}{to_bin(info['funct3'], 3)}{to_bin(imm, 5)}{to_bin(opcode, 7)}"

            elif fmt == 'B':
                rs1, rs2, label = get_reg(parts[1]), get_reg(parts[2]), parts[3]
                offset = labels[label] - pc
                bin_str = f"{(offset>>12)&1}{to_bin((offset>>5)&0x3F, 6)}{to_bin(rs2, 5)}{to_bin(rs1, 5)}{to_bin(info['funct3'], 3)}{to_bin((offset>>1)&0xF, 4)}{(offset>>11)&1}{to_bin(opcode, 7)}"

            elif fmt == 'U':
                rd, imm = get_reg(parts[1]), get_imm(parts[2])
                bin_str = f"{to_bin(imm, 20)}{to_bin(rd, 5)}{to_bin(opcode, 7)}"

            elif fmt == 'J':
                if len(parts) == 2: rd, label = 1, parts[1] # jal label
                else: rd, label = get_reg(parts[1]), parts[2]
                offset = labels[label] - pc
                bin_str = f"{(offset>>20)&1}{to_bin((offset>>1)&0x3FF, 10)}{(offset>>11)&1}{to_bin((offset>>12)&0xFF, 8)}{to_bin(rd, 5)}{to_bin(opcode, 7)}"

            hex_output.append(f"{int(bin_str, 2):08x}")

        except Exception as e:
            print(f"Error encoding '{line}': {e}")
            sys.exit(1)

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(hex_output))
    print(f"Successfully assembled {len(hex_output)} instructions.")
    print(f"Input: {input_file} -> Output: {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python assembler.py <input.s> <output.hex>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    
    assemble_file(input_path, output_path)