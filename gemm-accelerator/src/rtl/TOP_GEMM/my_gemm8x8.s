.text
.global main

# 8x8 GEMM: C = A x B
# Memory map:
#   A      = 0x000
#   B      = 0x100
#   C      = 0x200
#   STATUS = 0x300
#
# Register map:
#   x0        = constant zero
#   x1        = temporary bit-test value / loop compare constant
#   x2        = bit mask for shift-and-add multiplication
#   x3        = bit-loop limit, 256, or STATUS address at the end
#   x4        = A pointer. Also identifies current 4-row block.
#   x5        = B pointer
#   x6        = temporary bit-test value inside bit loop, C pointer near store
#   x7        = temporary bit-test value
#   x8-x11    = shifted A values for 4 rows
#   x12-x15   = B values for 4 columns
#   x16-x31   = 4x4 C accumulators
#
# Accumulator layout:
#   x16 x17 x18 x19 = row0 col0-col3 of current tile
#   x20 x21 x22 x23 = row1 col0-col3 of current tile
#   x24 x25 x26 x27 = row2 col0-col3 of current tile
#   x28 x29 x30 x31 = row3 col0-col3 of current tile
#
# The code computes one 4-row block at a time.
#   t0 computes columns 0-3.
#   t1 computes columns 4-7.
# Multiplication is implemented with RV32I shift-and-add:
#   test each bit of B with AND, conditionally add shifted A.

main:
    addi x4, x0, 0
row_block:
    # Clear 16 accumulators for the first 4x4 tile.
    addi x16, x0, 0
    addi x17, x0, 0
    addi x18, x0, 0
    addi x19, x0, 0
    addi x20, x0, 0
    addi x21, x0, 0
    addi x22, x0, 0
    addi x23, x0, 0
    addi x24, x0, 0
    addi x25, x0, 0
    addi x26, x0, 0
    addi x27, x0, 0
    addi x28, x0, 0
    addi x29, x0, 0
    addi x30, x0, 0
    addi x31, x0, 0
    addi x5, x0, 256
    addi x3, x0, 256
    addi x2, x0, 1
t0_k:
    # Load A[row+0..3][k] and B[k][col+0..3].
    lw x8, 0(x4)
    lw x9, 32(x4)
    lw x10, 64(x4)
    lw x11, 96(x4)
    lw x12, 0(x5)
    lw x13, 4(x5)
    lw x14, 8(x5)
    lw x15, 12(x5)
t0_bit:
    # Precompute bit tests for four B columns.
    # x2 is the current bit mask.
    and x7, x12, x2
    and x1, x13, x2
    and x6, x14, x2
    # If B[k][col0] has this bit, add shifted A to col0 accumulators.
    beq x7, x0, t0_c0_skip
    add x16, x16, x8
    add x20, x20, x9
    add x24, x24, x10
    add x28, x28, x11
t0_c0_skip:
    # If B[k][col1] has this bit, add shifted A to col1 accumulators.
    and x7, x15, x2
    beq x1, x0, t0_c1_skip
    add x17, x17, x8
    add x21, x21, x9
    add x25, x25, x10
    add x29, x29, x11
t0_c1_skip:
    # If B[k][col2] has this bit, add shifted A to col2 accumulators.
    beq x6, x0, t0_c2_skip
    add x18, x18, x8
    add x22, x22, x9
    add x26, x26, x10
    add x30, x30, x11
t0_c2_skip:
    # If B[k][col3] has this bit, add shifted A to col3 accumulators.
    add x2, x2, x2
    beq x7, x0, t0_c3_skip
    add x19, x19, x8
    add x23, x23, x9
    add x27, x27, x10
    add x31, x31, x11
t0_c3_skip:
    # Shift A and the bit mask left by one.
    add x8, x8, x8
    add x9, x9, x9
    add x10, x10, x10
    add x11, x11, x11
    beq x2, x3, t0_bit_done
    beq x0, x0, t0_bit
t0_bit_done:
    # Move to next k. B pointer reaches 512 after 8 k iterations.
    addi x1, x0, 512
    addi x5, x5, 32
    addi x4, x4, 4
    addi x2, x0, 1
    beq x5, x1, t0_k_done
    beq x0, x0, t0_k
t0_k_done:
    # Reconstruct C pointer from A pointer, rewind A, and set B to col4.
    addi x6, x4, 480
    addi x4, x4, -32
    addi x5, x0, 272
    # Store columns 0-3 of the current 4-row block.
    sw x16, 0(x6)
    sw x17, 4(x6)
    sw x18, 8(x6)
    sw x19, 12(x6)
    sw x20, 32(x6)
    sw x21, 36(x6)
    sw x22, 40(x6)
    sw x23, 44(x6)
    sw x24, 64(x6)
    sw x25, 68(x6)
    sw x26, 72(x6)
    sw x27, 76(x6)
    sw x28, 96(x6)
    sw x29, 100(x6)
    sw x30, 104(x6)
    sw x31, 108(x6)
    # Clear accumulators for columns 4-7.
    addi x16, x0, 0
    addi x17, x0, 0
    addi x18, x0, 0
    addi x19, x0, 0
    addi x20, x0, 0
    addi x21, x0, 0
    addi x22, x0, 0
    addi x23, x0, 0
    addi x24, x0, 0
    addi x25, x0, 0
    addi x26, x0, 0
    addi x27, x0, 0
    addi x28, x0, 0
    addi x29, x0, 0
    addi x30, x0, 0
    addi x31, x0, 0
    addi x3, x0, 256
    addi x2, x0, 1
t1_k:
    # Load A[row+0..3][k] and B[k][col+4..7].
    lw x8, 0(x4)
    lw x9, 32(x4)
    lw x10, 64(x4)
    lw x11, 96(x4)
    lw x12, 0(x5)
    lw x13, 4(x5)
    lw x14, 8(x5)
    lw x15, 12(x5)
t1_bit:
    # Same shift-and-add bit loop for columns 4-7.
    and x7, x12, x2
    and x1, x13, x2
    and x6, x14, x2
    beq x7, x0, t1_c0_skip
    add x16, x16, x8
    add x20, x20, x9
    add x24, x24, x10
    add x28, x28, x11
t1_c0_skip:
    # Precomputed x7 is reused here for the fourth column bit test.
    and x7, x15, x2
    beq x1, x0, t1_c1_skip
    add x17, x17, x8
    add x21, x21, x9
    add x25, x25, x10
    add x29, x29, x11
t1_c1_skip:
    beq x6, x0, t1_c2_skip
    add x18, x18, x8
    add x22, x22, x9
    add x26, x26, x10
    add x30, x30, x11
t1_c2_skip:
    add x2, x2, x2
    beq x7, x0, t1_c3_skip
    add x19, x19, x8
    add x23, x23, x9
    add x27, x27, x10
    add x31, x31, x11
t1_c3_skip:
    add x8, x8, x8
    add x9, x9, x9
    add x10, x10, x10
    add x11, x11, x11
    beq x2, x3, t1_bit_done
    beq x0, x0, t1_bit
t1_bit_done:
    addi x1, x0, 528
    addi x5, x5, 32
    addi x4, x4, 4
    addi x2, x0, 1
    beq x5, x1, t1_k_done
    beq x0, x0, t1_k
t1_k_done:
    # Store columns 4-7 of the current 4-row block.
    addi x6, x4, 480
    addi x4, x4, 96
    addi x1, x0, 256
    sw x16, 16(x6)
    sw x17, 20(x6)
    sw x18, 24(x6)
    sw x19, 28(x6)
    sw x20, 48(x6)
    sw x21, 52(x6)
    sw x22, 56(x6)
    sw x23, 60(x6)
    sw x24, 80(x6)
    sw x25, 84(x6)
    sw x26, 88(x6)
    sw x27, 92(x6)
    sw x28, 112(x6)
    sw x29, 116(x6)
    sw x30, 120(x6)
    sw x31, 124(x6)
    # After two 4-row blocks, x4 becomes 256 and all C rows are done.
    beq x4, x1, done_i
    beq x0, x0, row_block
done_i:
    # Signal completion: STATUS = 1.
    addi x2, x0, 1
    addi x3, x0, 768
    sw x2, 0(x3)
done:
    # Stay here after completion.
    beq x0, x0, done
