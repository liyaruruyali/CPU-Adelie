module core_top
  (
    input RST_N,
    input CLK,
    // Memory input and output

    input [31:0] I_MEM_IN,
    output [31:0] I_MEM_ADDR,
    // メモリからのデータをMEM_INで受け取り、欲しいアドレスをMEM_ADDRで出力
    // する
    input [31:0] MEM_IN,
    output [31:0] MEM_DATA,
    output [31:0] MEM_ADDR,
    output MEM_WE,

    // 浮動小数点
    output [31:0] A_TDATA,
    input A_TREADY,
    output A_TVALID,
    output [31:0] B_TDATA,
    input B_TREADY,
    output B_TVALID,
    output [7:0] OP_TDATA,
    input OP_TREADY,
    output OP_TVALID,

    input [31:0] R_TDATA,
    output R_TREADY,
    input R_TVALID,

    // In/Out
    output [3:0] S_AXI_AWADDR,
    output S_AXI_AWVALID,
    input S_AXI_AWREADY,

    output [31:0] S_AXI_WDATA,
    output [3:0] S_AXI_WSTB,
    output S_AXI_WVALID,
    input S_AXI_WREADY,

    input [1:0] S_AXI_BRESP,
    input S_AXI_BVALID,
    output S_AXI_BREADY,

    output [3:0] S_AXI_ARADDR,
    output S_AXI_ARVALID,
    input S_AXI_ARREADY,

    input [31:0] S_AXI_RDATA,
    input [1:0] S_AXI_RRESP,
    input S_AXI_RVALID,
    output S_AXI_RREADY

  );

  // PC
  wire [31:0] pc;
  wire [4:0] rd_num, rs1_num, rs2_num;
  wire [31:0] rs1, rs2, imm;

  wire [31:0] alu_result;
  
  wire i_lui, i_auipc, i_jal, i_jalr, i_beq, i_bne,
       i_blt, i_bge, i_bltu, i_bgeu, i_lb, i_lh, i_lw, i_lbu, i_lhu, i_sb, i_sh,
       i_sw, i_addi, i_slti, i_sltiu, i_xori, i_ori, i_andi, i_slli, i_srli, i_srai,
       i_add, i_sub, i_sll, i_slt, i_sltu, i_xor, i_srl, i_sra, i_or, i_and;
  wire i_flw, i_fsw, i_fadds, i_fsubs, i_fmuls, i_fdivs, i_feqs, i_flts, i_fles;
  wire i_in, i_out;
  wire n_inst;
  reg [31:0] a_tdata, b_tdata;
  reg a_tvalid, b_tvalid, op_tready;
  assign A_TDATA = a_tdata;
  assign B_TDATA = b_tdata;
  assign A_TVALID = a_tvalid;
  assign B_TVALID = b_tvalid;
  assign OP_TREADY = op_tready;

  // 乗除算はまだ

  assign r0 = 32'b0;

  // CPU state
  reg [6:0] cpu_state;
  localparam IDLE = 7'b0000001;
  localparam FETCH = 7'b0000010;
  localparam DECODE = 7'b0000100;
  localparam EXECUTE = 7'b0001000;
  localparam MEMORY = 7'b0100000;
  localparam WRITEBACK = 7'b1000000;

  always @(posedge CLK) begin
    if(!RST_N) begin
      cpu_state <= IDLE;
    end else begin
      case(cpu_state)
        IDLE:
        begin
          cpu_state <= FETCH;
        end
        FETCH:
        begin
          cpu_state <= DECODE;
        end
        DECODE:
        begin
          cpu_state <= EXECUTE;
        end
        EXECUTE:
        begin
          cpu_state <= MEMORY;
        end
        MEMORY:
        begin
          cpu_state <= WRITEBACK;
        end
        WRITEBACK:
        begin
          cpu_state <= FETCH;
        end
      endcase
    end
  end

  // それぞれの段階ごとのアサインをする
  // 1. 命令フェッチ Instruction Fetch
  
  assign I_MEM_ADDR = (pc >> 2);

  // 2. 命令デコード
  
  core_decode u_core_decode
  (
    .RST_N (RST_N),
    .CLK (CLK),

    .INST (I_MEM_IN),

    .RD_NUM (rd_num),
    .RS1_NUM (rs1_num),
    .RS2_NUM (rs2_num),

    .IMM (imm),

    .I_ADDI (i_addi),
    .I_SLTI (i_slti),
    .I_SLTIU (i_sltiu),
    .I_XORI (i_xori),
    .I_ORI (i_ori),
    .I_ANDI (i_andi),
    .I_SLLI (i_slli),
    .I_SRLI (i_srli),
    .I_SRAI (i_srai),
    .I_ADD (i_add),
    .I_SUB (i_sub),
    .I_SLL (i_sll),
    .I_SLT (i_slt),
    .I_SLTU (i_sltu),
    .I_XOR (i_xor),
    .I_SRL (i_srl),
    .I_SRA (i_sra),
    .I_OR (i_or),
    .I_AND (i_and),

    .I_BEQ (i_beq),
    .I_BNE (i_bne),
    .I_BLT (i_blt),
    .I_BGE (i_bge),
    .I_BLTU (i_bltu),
    .I_BGEU (i_bgeu),

    .I_LB (i_lb),
    .I_LH (i_lh),
    .I_LW (i_lw),
    .I_LBU (i_lbu),
    .I_LHU (i_lhu),
    .I_SB (i_sb),
    .I_SH (i_sh),
    .I_SW (i_sw),

    .I_JALR (i_jalr),
    .I_JAL (i_jal),
    .I_AUIPC (i_auipc),
    .I_LUI (i_lui),

    .I_FLW (i_flw),
    .I_FSW (i_fsw),
    .I_FADDS (i_fadds),
    .I_FSUBS (i_fsubs),
    .I_FMULS (i_fmuls),
    .I_FDIVS (i_fdivs),
    .I_FEQS (i_feqs),
    .I_FLTS (i_flts),
    .I_FLES (i_fles),

    .I_IN (i_in),
    .I_OUT (i_out),

    .N_INST (n_inst)

  );
  
  // 3. 実行
  
  core_alu u_core_alu
  (
    .RST_N (RST_N),
    .CLK (CLK),

    .I_ADDI (i_addi),
    .I_SLTI (i_slti),
    .I_SLTIU (i_sltiu),
    .I_XORI (i_xori),
    .I_ORI (i_ori),
    .I_ANDI (i_andi),
    .I_SLLI (i_slli),
    .I_SRLI (i_srli),
    .I_SRAI (i_srai),
    .I_ADD (i_add),
    .I_SUB (i_sub),
    .I_SLL (i_sll),
    .I_SLT (i_slt),
    .I_SLTU (i_sltu),
    .I_XOR (i_xor),
    .I_SRL (i_srl),
    .I_SRA (i_sra),
    .I_OR (i_or),
    .I_AND (i_and),

    .I_BEQ (i_beq),
    .I_BNE (i_bne),
    .I_BLT (i_blt),
    .I_BGE (i_bge),
    .I_BLTU (i_bltu),
    .I_BGEU (i_bgeu),

    .I_LB (i_lb),
    .I_LH (i_lh),
    .I_LW (i_lw),
    .I_LBU (i_lbu),
    .I_LHU (i_lhu),
    .I_SB (i_sb),
    .I_SH (i_sh),
    .I_SW (i_sw),

    .I_FLW (i_flw),
    .I_FSW (i_fsw),

    .RS1 (rs1),
    .RS2 (rs2),
    .IMM (imm),
    
    .RESULT (alu_result)

  );

  // 浮動小数点実行
  always @(posedge CLK) begin
    if(!RST_N) begin
      a_tdata <= 1'b0;
      a_tvalid <= 1'b0;
      b_tdata <= 1'b0;
      b_tvalid <= 1'b0;
      op_tready <= 1'b0;
    end else begin
      a_tdata <= (i_fadds | i_fsubs | i_fmuls | i_fdivs | i_feqs | i_flts | i_fles) ? rs1 : 0;
      a_tvalid <= (i_fadds | i_fsubs | i_fmuls | i_fdivs | i_feqs | i_flts | i_fles);
      b_tdata <= (i_fadds | i_fsubs | i_fmuls | i_fdivs | i_feqs | i_flts | i_fles) ? rs2 : 0;
      b_tvalid <= (i_fadds | i_fsubs | i_fmuls | i_fdivs | i_feqs | i_flts | i_fles);
      op_tready <= (i_fadds | i_fsubs | i_fmuls | i_fdivs | i_feqs | i_flts | i_fles);
    end
  end

  // in/out実行
  // inならrdに書き込むだけ
  // ineをほげする
  // outならr1からoutする
  always @(posedge CLK) begin
    if (!RST_N) begin
    end else begin
    end
  end

  // PC
  reg [31:0] pc_add_imm, pc_add_4, pc_jalr, pc_before;
  always @(posedge CLK) begin
    pc_add_imm <= pc_before + imm; // AUIPC, BRANCH, JAL
    pc_jalr <= rs1 + imm;
    pc_add_4 <= pc_before + 4;
    pc_before <= pc;
  end
  
  // メモリアクセスの前に実行と切り分ける

  wire [4:0] wr_addr;
  wire  wr_we;
  wire [31:0] wr_data;

  wire wr_pc_we;
  wire [31:0] wr_pc;

  // 4. メモリアクセス

  assign MEM_ADDR = alu_result;
  assign MEM_DATA = (i_sb) ? {4{rs2[7:0]}}:
                   (i_sh) ? {2{rs2[15:0]}}:
                   (i_sw) ? {rs2}:
                   32'd0;
  assign MEM_WE = (i_sb | i_sh | i_sw) && (cpu_state == MEMORY);
 
  // 5. 書き戻し
  

  // レジスタ

  assign wr_pc_we = (cpu_state == MEMORY);
  assign wr_pc = (((i_beq | i_bne | i_blt | i_bge | i_bltu | i_bgeu) & (alu_result == 32'd1)) | i_jal) ? pc_add_imm:
                 (i_jalr) ? pc_jalr:
                 pc_add_4;
  assign wr_we = (cpu_state == WRITEBACK);
  assign wr_data = (i_lui) ? imm:
                   (i_lw | i_lh | i_lb | i_lbu | i_lhu) ? MEM_IN:
                   (i_auipc) ? pc_add_imm:
                   (i_jal | i_jalr) ? pc_add_4:
                     alu_result;
  assign wr_addr = rd_num;

  core_reg u_core_reg
  (
    .RST_N (RST_N),
    .CLK (CLK),

    .WADDR (wr_addr),
    .WE (wr_we),
    .WDATA (wr_data),
    .INE (ine),
    .INDATA (S_AXI_RDATA),

    .RS1ADDR (rs1_num),
    .RS1 (rs1),
    .RS2ADDR (rs2_num),
    .RS2 (rs2),

    .PC_WE (wr_pc_we),
    .PC_WDATA (wr_pc),
    .PC (pc)
  );

endmodule
