module soc (
    // clock and reset
    clk, rst,
    // external memory interface
    mem_valid, mem_ready, mem_addr, mem_rdata, mem_wdata, mem_wstrb
);
    parameter RESET_PC = 32'h01000000;
    parameter RAM_WORDS = 256;
    parameter ENABLE_SHIFT = 0;
    parameter ENABLE_RDRAND = 0;
    parameter ENABLE_RDTSC = 0;

    input clk, rst;

    output mem_valid;
    input mem_ready;
    output [31:0] mem_addr;
    input [31:0] mem_rdata;
    output [31:0] mem_wdata;
    output [3:0] mem_wstrb;

    wire cpu_valid;
    wire cpu_ready;
    wire [31:0] cpu_addr;
    wire [31:0] cpu_rdata;
    wire [31:0] cpu_wdata;
    wire [3:0] cpu_wstrb;
    wire cpi_valid;
    wire cpi_ready;
    wire cpi_wait;
    wire [31:0] cpi_inst;
    wire [31:0] cpi_r1;
    wire [31:0] cpi_r2;
    wire [31:0] cpi_data;
    wire cpi_drop;

    wire cp0_valid;
    wire cp0_ready;
    wire cp0_wait;
    wire [31:0] cp0_inst;
    wire [31:0] cp0_r1;
    wire [31:0] cp0_r2;
    wire [31:0] cp0_data;
    wire cp0_drop;

    wire cp1_valid;
    wire cp1_ready;
    wire cp1_wait;
    wire [31:0] cp1_inst;
    wire [31:0] cp1_r1;
    wire [31:0] cp1_r2;
    wire [31:0] cp1_data;
    wire cp1_drop;

    wire cp2_valid;
    wire cp2_ready;
    wire cp2_wait;
    wire [31:0] cp2_inst;
    wire [31:0] cp2_r1;
    wire [31:0] cp2_r2;
    wire [31:0] cp2_data;
    wire cp2_drop;

    wire ram_valid;
    wire ram_ready;
    wire [31:0] ram_addr;
    wire [31:0] ram_rdata;
    wire [31:0] ram_wdata;
    wire [3:0] ram_wstrb;

    cpu #(
        .RESET_PC(RESET_PC),
        .CPI_ENABLE(1)
    ) cpu0 (
        .clk(clk),
        .rst(rst),
        // memory
        .mem_valid(cpu_valid),
        .mem_ready(cpu_ready),
        .mem_addr(cpu_addr),
        .mem_rdata(cpu_rdata),
        .mem_wdata(cpu_wdata),
        .mem_wstrb(cpu_wstrb),
        // coprocessor
        .cpi_valid(cpi_valid),
        .cpi_ready(cpi_ready),
        .cpi_wait(cpi_wait),
        .cpi_inst(cpi_inst),
        .cpi_r1(cpi_r1),
        .cpi_r2(cpi_r2),
        .cpi_data(cpi_data),
        .cpi_drop (cpi_drop)
    ); 

    random_coproc #(
        .OPCODE(8'hff)
    ) cp0 (
        .clk(clk),
        .rst(rst),
        .cpi_valid(cp0_valid && ENABLE_RDRAND),
        .cpi_ready(cp0_ready),
        .cpi_wait(cp0_wait),
        .cpi_inst(cp0_inst),
        .cpi_r1(cp0_r1),
        .cpi_r2(cp0_r2),
        .cpi_data(cp0_data),
        .cpi_drop (cp0_drop)
    );

    tsc_coproc #(
        .OPCODE(8'hfe)
    ) cp1 (
        .clk(clk),
        .rst(rst),
        .cpi_valid(cp1_valid && ENABLE_RDTSC),
        .cpi_ready(cp1_ready),
        .cpi_wait(cp1_wait),
        .cpi_inst(cp1_inst),
        .cpi_r1(cp1_r1),
        .cpi_r2(cp1_r2),
        .cpi_data(cp1_data),
        .cpi_drop (cp1_drop)
    );

    shift_coproc #(
        .OPCODE(4'he)
    ) cp2 (
        .clk(clk),
        .rst(rst),
        .cpi_valid(cp2_valid && ENABLE_SHIFT),
        .cpi_ready(cp2_ready),
        .cpi_wait(cp2_wait),
        .cpi_inst(cp2_inst),
        .cpi_r1(cp2_r1),
        .cpi_r2(cp2_r2),
        .cpi_data(cp2_data),
        .cpi_drop (cp2_drop)
    );
    
    ram #(
        .RAM_WORDS(RAM_WORDS)
    ) ram0 (
        .clk(clk),
        .mem_valid(ram_valid),
        .mem_ready(ram_ready),
        .mem_addr(ram_addr),
        .mem_rdata(ram_rdata),
        .mem_wdata(ram_wdata),
        .mem_wstrb(ram_wstrb)
    );

    assign cp0_valid = cpi_valid;
    assign cp0_inst = cpi_inst;
    assign cp0_r1 = cpi_r1;
    assign cp0_r2 = cpi_r2;

    assign cp1_valid = cpi_valid;
    assign cp1_inst = cpi_inst;
    assign cp1_r1 = cpi_r1;
    assign cp1_r2 = cpi_r2;

    assign cp2_valid = cpi_valid;
    assign cp2_inst = cpi_inst;
    assign cp2_r1 = cpi_r1;
    assign cp2_r2 = cpi_r2;

    assign cpi_ready = cp0_ready | cp1_ready | cp2_ready;
    assign cpi_wait = cp0_wait | cp1_wait | cp2_wait;
    assign cpi_data = cp0_data | cp1_data | cp2_data;
    assign cpi_drop = cp0_drop | cp1_drop | cp2_drop;

    assign ram_valid = cpu_valid && cpu_addr[31:16] == 16'h0000;
    assign ram_addr = cpu_addr;
    assign ram_wdata = cpu_wdata;
    assign ram_wstrb = cpu_wstrb;

    assign mem_valid = cpu_valid && cpu_addr >= 32'h01000000;
    assign mem_addr = cpu_addr;
    assign mem_wdata = cpu_wdata;
    assign mem_wstrb = cpu_wstrb;

    assign cpu_ready = (ram_valid && ram_ready) |
                       (mem_valid && mem_ready) ;

    assign cpu_rdata = (ram_valid && ram_ready) ? ram_rdata :
                       (mem_valid && mem_ready) ? mem_rdata :
                       32'hxxxxxxxx;
endmodule

module ram (
    // clock and reset
    input clk, output rst,
    // memory interface
    input mem_valid, output reg mem_ready,
    input [31:0] mem_addr, output reg [31:0] mem_rdata,
    input [31:0] mem_wdata, input [3:0] mem_wstrb
);
    parameter RAM_WORDS = 256;
    
    wire [29:0] mem_word = mem_addr >> 2;

    reg [31:0] mem [0:RAM_WORDS-1];

    always @(posedge clk) begin
        mem_ready <= 0;
        if(mem_valid && !mem_ready) begin
            mem_ready <= 1;
            mem_rdata <= mem[mem_addr];
            if(mem_wstrb[0]) mem[mem_word][ 7: 0] <= mem_wdata[ 7 :0];
            if(mem_wstrb[1]) mem[mem_word][15: 8] <= mem_wdata[15: 8];
            if(mem_wstrb[2]) mem[mem_word][23:16] <= mem_wdata[23:16];
            if(mem_wstrb[3]) mem[mem_word][31:24] <= mem_wdata[31:24];
        end
    end
endmodule

module random_coproc (
    // clock and reset
    input clk, input rst,
    // coprocessor interface
    input cpi_valid, output reg cpi_ready, output reg cpi_wait,
    input [31:0] cpi_inst, input [31:0] cpi_r1, input [31:0] cpi_r2,
    output reg [31:0] cpi_data, output reg cpi_drop 
);
    parameter OPCODE = 8'hff;

    reg [63:0] random;
    wire feedback = random[63] ^ random[62] ^ random[60] ^ random[59];

    always @(posedge clk) if(rst) begin
        random <= 64'h0123456789abcdef;
    end else begin
        random <= {random[62:0], feedback};
        {cpi_wait, cpi_ready, cpi_drop} <= 3'b000;
        cpi_data <= 0;
        if(cpi_valid && !cpi_ready && cpi_inst[31:24] == OPCODE) begin
            random <= random ^ {cpi_r1, cpi_r2};
            cpi_data <= random[31:0];
            {cpi_wait, cpi_ready, cpi_drop} <= 3'b111;
        end
    end
endmodule

module tsc_coproc (
    // clock and reset
    input clk, input rst,
    // coprocessor interface
    input cpi_valid, output reg cpi_ready, output reg cpi_wait,
    input [31:0] cpi_inst, input [31:0] cpi_r1, input [31:0] cpi_r2,
    output reg [31:0] cpi_data, output reg cpi_drop 
);
    parameter OPCODE = 8'hfe;

    reg [31:0] counter;
    always @(posedge clk) if(rst) begin
        counter <= 0;
    end else begin
        counter <= counter + 1;
        {cpi_wait, cpi_ready, cpi_drop} <= 3'b000;
        cpi_data <= 0;
        if(cpi_valid && !cpi_ready && cpi_inst[31:24] == OPCODE) begin
            cpi_data <= counter;
            {cpi_wait, cpi_ready, cpi_drop} <= 3'b111;
        end
    end
endmodule

module shift_coproc (
    // clock and reset
    input clk, input rst,
    // coprocessor interface
    input cpi_valid, output reg cpi_ready, output reg cpi_wait,
    input [31:0] cpi_inst, input [31:0] cpi_r1, input [31:0] cpi_r2,
    output reg [31:0] cpi_data, output reg cpi_drop 
);
    // [OPCODE:4; USE_IMM:1; SUBOP:3; R1:4; R2:4; xxx; IMM:6]
    parameter OPCODE = 4'he;


    localparam ST_INIT=0, ST_SHIFT=1;

    reg [1:0] state;
    reg [5:0] amount;
    reg [31:0] value;

    always @(posedge clk) if(rst) begin
        state <= ST_INIT;
        amount <= 0;
    end else begin
        state <= ST_INIT;
        {cpi_wait, cpi_ready, cpi_drop} <= 3'b000;
        cpi_data <= 0;
        if(cpi_valid && !cpi_ready && cpi_inst[31:28] == OPCODE) begin
            cpi_wait <= 1;
            case(state)
                ST_INIT: begin
                    value <= cpi_r1;
                    amount <= cpi_inst[27] ? cpi_r2[5:0] : cpi_inst[5:0];
                    state <= ST_SHIFT;
                end
                ST_SHIFT: if(amount != 0) begin
                    case(cpi_inst[26:24])
                        3'h0: value <= {1'b0, value[31:1]};      // shr
                        3'h1: value <= {value[0], value[31:1]};  // ror
                        3'h2: value <= {value[31], value[31:1]}; // ashr
                        3'h3: value <= 32'bxxxxxxxx;
                        3'h4: value <= {value[30:0], 1'b0};      // shl
                        3'h5: value <= {value[30:0], value[31]}; // rol
                        3'h6: value <= {value[30:0], value[0]};  // ashl
                        3'h7: value <= 32'bxxxxxxxx;
                    endcase
                    amount <= amount - 1;
                    state <= ST_SHIFT;
                end else begin
                    cpi_ready <= 1;
                    cpi_drop <= 1;
                    cpi_data <= value;
                end
            endcase
        end
    end
endmodule
