//-----------------------------------------------------------------
//                         RISC-V Core
//                            V1.0.1
//                     Ultra-Embedded.com
//                     Copyright 2014-2019
//
//                   admin@ultra-embedded.com
//
//                       License: BSD
//-----------------------------------------------------------------
//
// Copyright (c) 2014-2019, Ultra-Embedded.com
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions 
// are met:
//   - Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer 
//     in the documentation and/or other materials provided with the 
//     distribution.
//   - Neither the name of the author nor the names of its contributors 
//     may be used to endorse or promote products derived from this 
//     software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE 
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF 
// SUCH DAMAGE.
//-----------------------------------------------------------------
`ifdef __ICARUS__
`include "riscv_defs.v"
`else
`include "rtl/core/riscv_defs.v"
`endif

module riscv_decoder
(
     input                        valid_i
    ,input                        fetch_fault_i
    ,input                        enable_muldiv_i
    ,input  [31:0]                opcode_i

    ,output                       invalid_o
    ,output                       exec_o
    ,output                       lsu_o
    ,output                       branch_o
    ,output                       mul_o
    ,output                       div_o
    ,output                       csr_o
    ,output                       rd_valid_o
);

// Invalid instruction
wire legal_13 /* synthesis syn_keep=1 */ = ((opcode_i & 32'h00007000) == 32'h00007000) | ((opcode_i & 32'h00007000) == 32'h00000000) | ((opcode_i & 32'h00007000) == 32'h00002000) | ((opcode_i & 32'h00007000) == 32'h00003000) | ((opcode_i & 32'h00007000) == 32'h00006000) | ((opcode_i & 32'h00007000) == 32'h00004000) | ((opcode_i & 32'hfc007000) == 32'h00001000) | ((opcode_i & 32'hfc007000) == 32'h00005000) | ((opcode_i & 32'hfc007000) == 32'h40005000);
wire legal_37 /* synthesis syn_keep=1 */ = 1'b1;
wire legal_17 /* synthesis syn_keep=1 */ = 1'b1;
wire legal_33 /* synthesis syn_keep=1 */ = ((opcode_i & 32'hfe007000) == 32'h00000000) | ((opcode_i & 32'hfe007000) == 32'h40000000) | ((opcode_i & 32'hfe007000) == 32'h00002000) | ((opcode_i & 32'hfe007000) == 32'h00003000) | ((opcode_i & 32'hfe007000) == 32'h00004000) | ((opcode_i & 32'hfe007000) == 32'h00006000) | ((opcode_i & 32'hfe007000) == 32'h00007000) | ((opcode_i & 32'hfe007000) == 32'h00001000) | ((opcode_i & 32'hfe007000) == 32'h00005000) | ((opcode_i & 32'hfe007000) == 32'h40005000) | (enable_muldiv_i && ((opcode_i & 32'hfe007000) == 32'h02000000)) | (enable_muldiv_i && ((opcode_i & 32'hfe007000) == 32'h02001000)) | (enable_muldiv_i && ((opcode_i & 32'hfe007000) == 32'h02002000)) | (enable_muldiv_i && ((opcode_i & 32'hfe007000) == 32'h02003000)) | (enable_muldiv_i && ((opcode_i & 32'hfe007000) == 32'h02004000)) | (enable_muldiv_i && ((opcode_i & 32'hfe007000) == 32'h02005000)) | (enable_muldiv_i && ((opcode_i & 32'hfe007000) == 32'h02006000)) | (enable_muldiv_i && ((opcode_i & 32'hfe007000) == 32'h02007000));
wire legal_6f /* synthesis syn_keep=1 */ = 1'b1;
wire legal_67 /* synthesis syn_keep=1 */ = ((opcode_i & 32'h00007000) == 32'h00000000);
wire legal_63 /* synthesis syn_keep=1 */ = ((opcode_i & 32'h00007000) == 32'h00000000) | ((opcode_i & 32'h00007000) == 32'h00001000) | ((opcode_i & 32'h00007000) == 32'h00004000) | ((opcode_i & 32'h00007000) == 32'h00005000) | ((opcode_i & 32'h00007000) == 32'h00006000) | ((opcode_i & 32'h00007000) == 32'h00007000);
wire legal_03 /* synthesis syn_keep=1 */ = ((opcode_i & 32'h00007000) == 32'h00000000) | ((opcode_i & 32'h00007000) == 32'h00001000) | ((opcode_i & 32'h00007000) == 32'h00002000) | ((opcode_i & 32'h00007000) == 32'h00004000) | ((opcode_i & 32'h00007000) == 32'h00005000) | ((opcode_i & 32'h00007000) == 32'h00006000);
wire legal_23 /* synthesis syn_keep=1 */ = ((opcode_i & 32'h00007000) == 32'h00000000) | ((opcode_i & 32'h00007000) == 32'h00001000) | ((opcode_i & 32'h00007000) == 32'h00002000);
wire legal_73 /* synthesis syn_keep=1 */ = ((opcode_i & 32'hffffff80) == 32'h00000000) | ((opcode_i & 32'hffffff80) == 32'h00100000) | ((opcode_i & 32'hcfffff80) == 32'h00200000) | ((opcode_i & 32'h00007000) == 32'h00001000) | ((opcode_i & 32'h00007000) == 32'h00002000) | ((opcode_i & 32'h00007000) == 32'h00003000) | ((opcode_i & 32'h00007000) == 32'h00005000) | ((opcode_i & 32'h00007000) == 32'h00006000) | ((opcode_i & 32'h00007000) == 32'h00007000) | ((opcode_i & 32'hffff8f80) == 32'h10500000) | ((opcode_i & 32'hfe007f80) == 32'h12000000);
wire legal_0f /* synthesis syn_keep=1 */ = ((opcode_i & 32'h00007000) == 32'h00000000) | ((opcode_i & 32'h00007000) == 32'h00001000);
wire legal_w = ((opcode_i[6:0] == 7'h13) && legal_13) | ((opcode_i[6:0] == 7'h37) && legal_37) | ((opcode_i[6:0] == 7'h17) && legal_17) | ((opcode_i[6:0] == 7'h33) && legal_33) | ((opcode_i[6:0] == 7'h6f) && legal_6f) | ((opcode_i[6:0] == 7'h67) && legal_67) | ((opcode_i[6:0] == 7'h63) && legal_63) | ((opcode_i[6:0] == 7'h03) && legal_03) | ((opcode_i[6:0] == 7'h23) && legal_23) | ((opcode_i[6:0] == 7'h73) && legal_73) | ((opcode_i[6:0] == 7'h0f) && legal_0f);
wire invalid_w = valid_i && !legal_w;

assign invalid_o = invalid_w;

assign rd_valid_o = ((opcode_i & `INST_JALR_MASK) == `INST_JALR)     ||
                    ((opcode_i & `INST_JAL_MASK) == `INST_JAL)       ||
                    ((opcode_i & `INST_LUI_MASK) == `INST_LUI)       ||
                    ((opcode_i & `INST_AUIPC_MASK) == `INST_AUIPC)   ||
                    ((opcode_i & `INST_ADDI_MASK) == `INST_ADDI)     ||
                    ((opcode_i & `INST_SLLI_MASK) == `INST_SLLI)     ||
                    ((opcode_i & `INST_SLTI_MASK) == `INST_SLTI)     ||
                    ((opcode_i & `INST_SLTIU_MASK) == `INST_SLTIU)   ||
                    ((opcode_i & `INST_XORI_MASK) == `INST_XORI)     ||
                    ((opcode_i & `INST_SRLI_MASK) == `INST_SRLI)     ||
                    ((opcode_i & `INST_SRAI_MASK) == `INST_SRAI)     ||
                    ((opcode_i & `INST_ORI_MASK) == `INST_ORI)       ||
                    ((opcode_i & `INST_ANDI_MASK) == `INST_ANDI)     ||
                    ((opcode_i & `INST_ADD_MASK) == `INST_ADD)       ||
                    ((opcode_i & `INST_SUB_MASK) == `INST_SUB)       ||
                    ((opcode_i & `INST_SLL_MASK) == `INST_SLL)       ||
                    ((opcode_i & `INST_SLT_MASK) == `INST_SLT)       ||
                    ((opcode_i & `INST_SLTU_MASK) == `INST_SLTU)     ||
                    ((opcode_i & `INST_XOR_MASK) == `INST_XOR)       ||
                    ((opcode_i & `INST_SRL_MASK) == `INST_SRL)       ||
                    ((opcode_i & `INST_SRA_MASK) == `INST_SRA)       ||
                    ((opcode_i & `INST_OR_MASK) == `INST_OR)         ||
                    ((opcode_i & `INST_AND_MASK) == `INST_AND)       ||
                    ((opcode_i & `INST_LB_MASK) == `INST_LB)         ||
                    ((opcode_i & `INST_LH_MASK) == `INST_LH)         ||
                    ((opcode_i & `INST_LW_MASK) == `INST_LW)         ||
                    ((opcode_i & `INST_LBU_MASK) == `INST_LBU)       ||
                    ((opcode_i & `INST_LHU_MASK) == `INST_LHU)       ||
                    ((opcode_i & `INST_LWU_MASK) == `INST_LWU)       ||
                    ((opcode_i & `INST_MUL_MASK) == `INST_MUL)       ||
                    ((opcode_i & `INST_MULH_MASK) == `INST_MULH)     ||
                    ((opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU) ||
                    ((opcode_i & `INST_MULHU_MASK) == `INST_MULHU)   ||
                    ((opcode_i & `INST_DIV_MASK) == `INST_DIV)       ||
                    ((opcode_i & `INST_DIVU_MASK) == `INST_DIVU)     ||
                    ((opcode_i & `INST_REM_MASK) == `INST_REM)       ||
                    ((opcode_i & `INST_REMU_MASK) == `INST_REMU)     ||
                    ((opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW)   ||
                    ((opcode_i & `INST_CSRRS_MASK) == `INST_CSRRS)   ||
                    ((opcode_i & `INST_CSRRC_MASK) == `INST_CSRRC)   ||
                    ((opcode_i & `INST_CSRRWI_MASK) == `INST_CSRRWI) ||
                    ((opcode_i & `INST_CSRRSI_MASK) == `INST_CSRRSI) ||
                    ((opcode_i & `INST_CSRRCI_MASK) == `INST_CSRRCI);

assign exec_o =     ((opcode_i & `INST_ANDI_MASK) == `INST_ANDI)  ||
                    ((opcode_i & `INST_ADDI_MASK) == `INST_ADDI)  ||
                    ((opcode_i & `INST_SLTI_MASK) == `INST_SLTI)  ||
                    ((opcode_i & `INST_SLTIU_MASK) == `INST_SLTIU)||
                    ((opcode_i & `INST_ORI_MASK) == `INST_ORI)    ||
                    ((opcode_i & `INST_XORI_MASK) == `INST_XORI)  ||
                    ((opcode_i & `INST_SLLI_MASK) == `INST_SLLI)  ||
                    ((opcode_i & `INST_SRLI_MASK) == `INST_SRLI)  ||
                    ((opcode_i & `INST_SRAI_MASK) == `INST_SRAI)  ||
                    ((opcode_i & `INST_LUI_MASK) == `INST_LUI)    ||
                    ((opcode_i & `INST_AUIPC_MASK) == `INST_AUIPC)||
                    ((opcode_i & `INST_ADD_MASK) == `INST_ADD)    ||
                    ((opcode_i & `INST_SUB_MASK) == `INST_SUB)    ||
                    ((opcode_i & `INST_SLT_MASK) == `INST_SLT)    ||
                    ((opcode_i & `INST_SLTU_MASK) == `INST_SLTU)  ||
                    ((opcode_i & `INST_XOR_MASK) == `INST_XOR)    ||
                    ((opcode_i & `INST_OR_MASK) == `INST_OR)      ||
                    ((opcode_i & `INST_AND_MASK) == `INST_AND)    ||
                    ((opcode_i & `INST_SLL_MASK) == `INST_SLL)    ||
                    ((opcode_i & `INST_SRL_MASK) == `INST_SRL)    ||
                    ((opcode_i & `INST_SRA_MASK) == `INST_SRA);

assign lsu_o =      ((opcode_i & `INST_LB_MASK) == `INST_LB)   ||
                    ((opcode_i & `INST_LH_MASK) == `INST_LH)   ||
                    ((opcode_i & `INST_LW_MASK) == `INST_LW)   ||
                    ((opcode_i & `INST_LBU_MASK) == `INST_LBU) ||
                    ((opcode_i & `INST_LHU_MASK) == `INST_LHU) ||
                    ((opcode_i & `INST_LWU_MASK) == `INST_LWU) ||
                    ((opcode_i & `INST_SB_MASK) == `INST_SB)   ||
                    ((opcode_i & `INST_SH_MASK) == `INST_SH)   ||
                    ((opcode_i & `INST_SW_MASK) == `INST_SW);

assign branch_o =   ((opcode_i & `INST_JAL_MASK) == `INST_JAL)   ||
                    ((opcode_i & `INST_JALR_MASK) == `INST_JALR) ||
                    ((opcode_i & `INST_BEQ_MASK) == `INST_BEQ)   ||
                    ((opcode_i & `INST_BNE_MASK) == `INST_BNE)   ||
                    ((opcode_i & `INST_BLT_MASK) == `INST_BLT)   ||
                    ((opcode_i & `INST_BGE_MASK) == `INST_BGE)   ||
                    ((opcode_i & `INST_BLTU_MASK) == `INST_BLTU) ||
                    ((opcode_i & `INST_BGEU_MASK) == `INST_BGEU);

assign mul_o =      enable_muldiv_i &&
                    (((opcode_i & `INST_MUL_MASK) == `INST_MUL)    ||
                    ((opcode_i & `INST_MULH_MASK) == `INST_MULH)   ||
                    ((opcode_i & `INST_MULHSU_MASK) == `INST_MULHSU) ||
                    ((opcode_i & `INST_MULHU_MASK) == `INST_MULHU));

assign div_o =      enable_muldiv_i &&
                    (((opcode_i & `INST_DIV_MASK) == `INST_DIV) ||
                    ((opcode_i & `INST_DIVU_MASK) == `INST_DIVU) ||
                    ((opcode_i & `INST_REM_MASK) == `INST_REM) ||
                    ((opcode_i & `INST_REMU_MASK) == `INST_REMU));

assign csr_o =      ((opcode_i & `INST_ECALL_MASK) == `INST_ECALL)            ||
                    ((opcode_i & `INST_EBREAK_MASK) == `INST_EBREAK)          ||
                    ((opcode_i & `INST_ERET_MASK) == `INST_ERET)              ||
                    ((opcode_i & `INST_CSRRW_MASK) == `INST_CSRRW)            ||
                    ((opcode_i & `INST_CSRRS_MASK) == `INST_CSRRS)            ||
                    ((opcode_i & `INST_CSRRC_MASK) == `INST_CSRRC)            ||
                    ((opcode_i & `INST_CSRRWI_MASK) == `INST_CSRRWI)          ||
                    ((opcode_i & `INST_CSRRSI_MASK) == `INST_CSRRSI)          ||
                    ((opcode_i & `INST_CSRRCI_MASK) == `INST_CSRRCI)          ||
                    ((opcode_i & `INST_WFI_MASK) == `INST_WFI)                ||
                    ((opcode_i & `INST_FENCE_MASK) == `INST_FENCE)            ||
                    ((opcode_i & `INST_IFENCE_MASK) == `INST_IFENCE)          ||
                    ((opcode_i & `INST_SFENCE_MASK) == `INST_SFENCE)          ||
                    invalid_w || fetch_fault_i;

endmodule
