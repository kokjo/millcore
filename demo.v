module demo(clk, rst, leds, uart_tx, uart_rx);
    input clk, rst;

    output reg [7:0] leds;
    output uart_tx;
    input uart_rx;

    wire mem_valid;
    reg mem_ready;
    wire [31:0] mem_addr;
    reg [31:0] mem_rdata;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;

    soc soc0 (
        .clk(clk),
        .rst(rst),
        .mem_valid(mem_valid),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb)
    );

    reg [31:0] rom [0:255];
    reg [31:0] iomem [0:3];

    assign leds = iomem[0][7:0];

    always @(posedge clk) begin
        mem_ready <= 0;

        if(mem_valid && !mem_ready && mem_addr[31:16] == 16'h0100) begin
            mem_ready <= 1;
            mem_rdata <= rom[mem_addr[9:2]];
        end

        if(mem_valid && !mem_ready && mem_addr[31:16] == 16'h0200) begin
            mem_ready <= 1;
            mem_rdata <= iomem[mem_addr[3:2]];
            if(mem_wstrb[0]) iomem[mem_addr[3:2]][ 7: 0] = mem_wdata[ 7: 0];
            if(mem_wstrb[1]) iomem[mem_addr[3:2]][15: 8] = mem_wdata[15: 8];
            if(mem_wstrb[2]) iomem[mem_addr[3:2]][23:16] = mem_wdata[23:16];
            if(mem_wstrb[3]) iomem[mem_addr[3:2]][31:24] = mem_wdata[31:24];
        end
    end
endmodule
