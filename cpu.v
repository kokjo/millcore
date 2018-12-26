module cpu (
    // clock and reset
    clk, rst,
    // memory master interface
    mem_valid, mem_ready, mem_addr, mem_rdata, mem_wdata, mem_wstrb,
    // coprocessor interface
    cpi_valid, cpi_ready, cpi_wait, cpi_inst, cpi_r1, cpi_r2, cpi_data, cpi_drop
);
    parameter RESET_PC = 32'h00000000;
    parameter CPI_ENABLE = 1;

    input clk, rst;

    output reg mem_valid;
    input mem_ready;
    output reg [31:0] mem_addr;
    input [31:0] mem_rdata;
    output reg [31:0] mem_wdata;
    output reg [3:0] mem_wstrb;

    output reg cpi_valid;
    input cpi_ready;
    input cpi_wait;
    output [31:0] cpi_inst;
    output [31:0] cpi_r1;
    output [31:0] cpi_r2;
    input [31:0] cpi_data;
    input cpi_drop;
    reg [3:0] cpi_cnt;

    reg [2:0] state;
    reg [31:0] pc;
    reg [31:0] inst;

    wire [3:0] r1;
    wire [3:0] r2;
    wire [3:0] op;
    wire [3:0] subop;
    wire [15:0] imm16;
    wire [31:0] imm16_sx;
    wire [23:0] imm24;
    wire [31:0] imm24_sx;
    wire [27:0] imm28;
    wire [31:0] imm28_sx;

    assign {op, subop, r1, r2, imm16} = inst;
    assign imm16_sx = {{16{imm16[15]}}, imm16};

    assign imm24 = inst[23:0];
    assign imm24_sx = {{8{imm24[23]}}, imm28};

    assign imm28 = inst[27:0];
    assign imm28_sx = {{4{imm28[27]}}, imm28};

    reg belt_drop;
    reg [31:0] belt_wdata;
    reg [3:0] belt_r1;
    wire [31:0] belt_rdata1;
    reg [3:0] belt_r2;
    wire [31:0] belt_rdata2;

    belt belt0 (
        .clk(clk),
        .rst(rst),
        .drop(belt_drop),
        .wdata(belt_wdata),
        .r1(r1),
        .rdata1(belt_rdata1),
        .r2(r2),
        .rdata2(belt_rdata2)
    );

    reg sel_rdata2;
    wire [31:0] op2;
    assign op2 = sel_rdata2 ? belt_rdata2 : imm16_sx;

    assign cpi_inst = cpi_valid ? inst : 32'hxxxxxxxx;
    assign cpi_r1 = cpi_valid ? belt_rdata1 : 32'hxxxxxxxx;
    assign cpi_r2 = cpi_valid ? belt_rdata2 : 32'hxxxxxxxx;
    

    localparam  ST_FETCH=0,
                ST_DECODE=1,
                ST_ALU=2,
                ST_BRANCH=3,
                ST_MEM=4,
                ST_MEM_WRITE=5,
                ST_MEM_READ=6,
                ST_COPROC=7;

    localparam  OP_DROP=0,
                OP_DROPREL=1,
                OP_ALU=2,
                OP_ALUI=3,
                OP_BRANCH=4,
                OP_MEM=5;

    always @(posedge clk) if(rst) begin
            pc <= RESET_PC;
            state <= ST_FETCH;
            belt_drop <= 0;
            mem_valid <= 0;
            inst <= 0;
        end else case(state)
        ST_FETCH: begin
            belt_drop <= 0;
            if(!mem_ready) begin
                mem_valid <= 1;
                mem_wstrb <= 0;
                mem_addr <= pc;
            end else begin
                pc <= pc + 4;
                mem_valid <= 0;
                inst <= mem_rdata;
                state <= ST_DECODE;
            end
        end

        ST_DECODE: case(op)
            OP_DROP: begin
                belt_wdata <= imm28_sx;
                belt_drop <= 1;
                state <= ST_FETCH;
            end
            OP_DROPREL: begin
                belt_wdata <= pc + imm28_sx;
                belt_drop <= 1;
                state <= ST_FETCH;
            end
            OP_ALU: begin
                sel_rdata2 <= 1;
                state <= ST_ALU;
            end
            OP_ALUI: begin
                sel_rdata2 <= 0;
                state <= ST_ALU;
            end
            OP_BRANCH: state <= ST_BRANCH;
            OP_MEM: state <= ST_MEM;
            default: if(CPI_ENABLE) begin
                cpi_valid <= 1;
                cpi_cnt <= 15;
                state <= ST_COPROC;
            end else state <= ST_FETCH;
        endcase

        ST_BRANCH: begin
            case(subop)
                4'h0: if(|belt_rdata1) pc <= belt_rdata2;     // b.nz r1, r2
                4'h1: if(|belt_rdata1) pc <= pc+imm16_sx;     // b.nz r1, off
                3'h2: if(belt_rdata1 == 0) pc <= belt_rdata2; // b.z r1, r2
                3'h2: if(belt_rdata1 == 0) pc <= pc+imm16_sx; // b.z r1, r2
                4'h4: pc <= belt_rdata2;                      // jmp r2
                4'h5: pc <= pc + imm16_sx;                    // jmp off
            endcase
            state <= ST_FETCH;
        end

        ST_MEM: begin
            mem_valid <= 1;
            mem_addr <= belt_rdata1[31:2] + imm16_sx;
            if(subop[3]) begin
                case(subop[2:0])
                    0: begin // write dword
                        mem_wdata <= belt_rdata2;
                        mem_wstrb <= 4'b1111;
                        state <= ST_MEM_WRITE;
                    end
                    1: begin //write word
                        mem_wdata <= belt_rdata2 << (belt_rdata1[1]*16);
                        mem_wstrb <= 4'b0011 << (belt_rdata1[1]*2);
                        state <= ST_MEM_WRITE;
                    end
                    2: begin // write byte
                        mem_wdata <= belt_rdata2 << (belt_rdata1[1:0]*8);
                        mem_wstrb <= 4'b0001 << (belt_rdata1[1:0]);
                        state <= ST_MEM_WRITE;
                    end
                    3: begin // xchg dword
                        mem_wdata <= belt_rdata2;
                        mem_wstrb <= 0;
                        state <= ST_MEM_READ; // read previous value.
                    end
                endcase
            end else begin
                mem_wstrb <= 0;
                state <= ST_MEM_READ;
            end
        end

        ST_MEM_WRITE: if(mem_ready) begin
            mem_valid <= 0;
            state <= ST_FETCH;
        end

        ST_MEM_READ: if(mem_ready) begin
            case(subop[2:0])
                0: belt_wdata <= mem_rdata; // read dword
                1: belt_wdata <= mem_rdata >> (belt_rdata1[1]*16); // read word
                2: belt_wdata <= mem_rdata >> (belt_rdata1[1:0]*8); // read word
                3: belt_wdata <= mem_rdata; // read dword / xchg instruction from write.
            endcase
            mem_valid <= 0;
            belt_drop <= 1;
            state <= ST_FETCH;
        end

        ST_ALU: begin
            case(subop)
                4'h0: belt_wdata <= belt_rdata1 + op2;  // add r1, {imm, r2}
                4'h1: belt_wdata <= belt_rdata1 - op2;  // sub r1, {imm, r2}
                4'h2: belt_wdata <= belt_rdata1 | op2;  // or  r1, {imm, r2}
                4'h3: belt_wdata <= belt_rdata1 & op2;  // and r1, {imm, r2}
                4'h4: belt_wdata <= belt_rdata1 ^ op2;  // xor r1, {imm, r2}
                4'h5: belt_wdata <= belt_rdata1 == op2; // eq  r1, {imm, r2}
                4'h6: belt_wdata <= belt_rdata1 <= op2; // leq r1, {imm, r2}
                default: belt_wdata <= 32'hxxxxxxxx;
            endcase
            belt_drop <= 1;
            state <= ST_FETCH;
        end
        
        ST_COPROC: if(cpi_ready) begin
            // coprocessor ready, drop result, goto fetch.
            cpi_valid <= 0;
            belt_drop <= cpi_drop;
            belt_wdata <= cpi_data;
            state <= ST_FETCH;
        end else if(cpi_cnt == 0) begin
            state <= ST_FETCH;
        end else if(!cpi_wait) begin
            cpi_cnt = cpi_cnt - 1;
        end
    endcase
endmodule

module belt (clk, rst, drop, wdata, r1, rdata1, r2, rdata2);
    input clk, rst;

    input drop;
    input [31:0] wdata;

    input [3:0] r1;
    output reg [31:0] rdata1;

    input [3:0] r2;
    output reg [31:0] rdata2;

    reg [31:0] belt [0:15];
    reg [3:0] idx;

    initial begin
        belt[0] <= 0;  belt[1] <= 0;  belt[2] <= 0;  belt[3] <= 0;
        belt[4] <= 0;  belt[5] <= 0;  belt[6] <= 0;  belt[7] <= 0;
        belt[8] <= 0;  belt[9] <= 0;  belt[10] <= 0; belt[11] <= 0;
        belt[12] <= 0; belt[13] <= 0; belt[14] <= 0; belt[15] <= 0;
    end

    always @(posedge clk) begin
        if(rst) begin
            idx <= 0;
        end else begin
            rdata1 <= belt[(idx-r1-1) & 4'hf];
            rdata2 <= belt[(idx-r2-1) & 4'hf];

            if(drop) begin
                belt[idx] <= wdata;
                idx <= idx + 1;
            end
        end
    end
endmodule
