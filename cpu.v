module cpu (
    clk, rst,
    mem_valid, mem_ready, mem_addr, mem_rdata, mem_wdata, mem_wstrb
);
    parameter RESET_PC = 32'h00000000;

    input clk, rst;

    output reg mem_valid;
    input mem_ready;
    output reg [31:0] mem_addr;
    input [31:0] mem_rdata;
    output reg [31:0] mem_wdata;
    output reg [3:0] mem_wstrb;

    reg [3:0] state;
    reg [31:0] pc;
    reg [31:0] inst;

    wire [3:0] r1;
    wire [3:0] r2;
    wire [3:0] op;
    wire [3:0] subop;
    wire [15:0] imm16;
    wire [31:0] imm16_sx;
    wire [27:0] imm28;
    wire [31:0] imm28_sx;

    assign {op, subop, r1, r2, imm16} = inst;
    assign imm16_sx = {{16{imm16[15]}}, imm16};
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

    localparam  ST_FETCH=0,
                ST_WAIT_MEM=1,
                ST_DECODE=2,
                ST_ALU=3,
                ST_NEXT=4,
                ST_BRANCH=5,
                ST_MEM=6,
                ST_MEM_WRITE=7,
                ST_MEM_READ=8;

    localparam  OP_DROP=0,
                OP_DROPREL=1,
                OP_ALU=2,
                OP_BRANCH=3,
                OP_MEM=4;

    always @(posedge clk) if(rst) begin
            pc <= 32'h01000000;
            state <= ST_FETCH;
            belt_drop <= 0;
            mem_valid <= 0;
            mem_wstrb <= 0;
            mem_wdata <= 0;
            inst <= 0;
        end else case(state)
        ST_FETCH: begin
            if(!mem_ready) begin
                mem_valid <= 1;
                belt_drop <= 0;
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
            OP_ALU: state <= ST_ALU;
            OP_BRANCH: state <= ST_BRANCH;
            OP_MEM: state <= ST_MEM;
        endcase

        ST_BRANCH: begin
            case(subop)
                4'h0: if(|belt_rdata1) pc <= belt_rdata2;     // b.nz r1, r2
                4'h1: if(|belt_rdata1) pc <= pc+imm16_sx;     // b.nz r1, off
                3'h2: if(belt_rdata1 == 0) pc <= belt_rdata2; // b.z r1, r2
                3'h2: if(belt_rdata1 == 0) pc <= pc+imm16_sx; // b.z r1, r2
                4'h4: pc <= belt_rdata2;                      // jmp r2
                4'h5: pc <= pc + imm16_sx                     // jmp off
            endcase
            state <= ST_FETCH;
        end

        ST_MEM: begin
            mem_addr <= belt_rdata1[31:2];
            if(subop[3]) begin
                case(subop[2:0])
                    0: begin // write dword
                        mem_wdata <= belt_rdata2;
                        mem_wstrb <= 4'b1111;
                    end
                    1: begin //write word
                        mem_wdata <= belt_rdata2 << (belt_rdata1[1]*16);
                        mem_wstrb <= 4'b0011 << (belt_rdata1[1]*2);
                    end
                    2: begin // write byte
                        mem_wdata <= belt_rdata2 << (belt_rdata1[1:0]*8);
                        mem_wstrb <= 2'b0001 << (belt_rdata1[1:0]);
                    end
                    3: begin // bad instruction
                        mem_wdata <= 32'hxxxxxxxx;
                        mem_wstrb <= 0;
                    end
                endcase
                state <= ST_MEM_WRITE;
            end else begin
                mem_valid <= 1;
                state <= ST_MEM_READ;
            end
        end

        ST_MEM_WRITE: begin
            mem_valid <= 0;
            mem_wstrb <= 0;
            state <= ST_FETCH;
        end

        ST_MEM_READ: if(mem_ready) begin
            case(subop[2:0])
                0: begin 
                    belt_wdata <= mem_rdata;
                    belt_drop <= 1;
                end
                1: begin
                    belt_wdata <= mem_rdata >> (belt_rdata1[1]*16);
                    belt_drop <= 1;
                end
                2: begin
                    belt_wdata <= mem_rdata >> (belt_rdata1[1:0]*8);
                    belt_drop <= 1;
                end
                3: begin
                    belt_wdata <= 32'hxxxxxxxx;
                    belt_drop <= 0;
                end
            endcase
            mem_valid <= 0;
            state <= ST_FETCH;
        end

        ST_ALU: begin
            case(subop)
                4'h0: belt_wdata <= belt_rdata1 + belt_rdata2;
                4'h1: belt_wdata <= belt_rdata1 - belt_rdata2;
                4'h2: belt_wdata <= belt_rdata1 | belt_rdata2;
                4'h3: belt_wdata <= belt_rdata1 & belt_rdata2;
                4'h4: belt_wdata <= belt_rdata1 ^ belt_rdata2;
                4'h5: belt_wdata <= belt_rdata1 == belt_rdata2;
                4'h6: belt_wdata <= belt_rdata1 <= belt_rdata2;
                default: belt_wdata <= 32'hxxxxxxxx;
            endcase
            belt_drop <= 1;
            state <= ST_FETCH;
        end
    endcase
endmodule
