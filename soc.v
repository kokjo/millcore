module soc (
    clk, rst,
    //leds,
    ext_mem_valid, ext_mem_ready, ext_mem_addr, ext_mem_rdata
);
    input clk, rst;
    wire [7:0] leds;
    output ext_mem_valid;
    input ext_mem_ready;
    output [7:0] ext_mem_addr;
    input [31:0] ext_mem_rdata;

    wire cpu_mem_valid;
    wire cpu_mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] cpu_mem_rdata;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;

    wire ram_mem_valid;
    wire ram_mem_ready;
    wire gpio_mem_valid;
    wire gpio_mem_ready;

    wire [31:0] ram_mem_rdata;

    assign ram_mem_valid  = cpu_mem_valid && mem_addr[31:24] == 8'h00;
    assign ext_mem_valid  = cpu_mem_valid && mem_addr[31:24] == 8'h01;
    assign gpio_mem_valid = cpu_mem_valid && mem_addr[31:24] == 8'h02;

    assign cpu_mem_ready = (ram_mem_valid  && ram_mem_ready) |
                           (ext_mem_valid  && ext_mem_ready) ;

    assign cpu_mem_rdata = (ram_mem_valid  && ram_mem_ready) ? ram_mem_rdata :
                           (ext_mem_valid  && ext_mem_ready) ? ext_mem_rdata :
                           32'hxxxxxxxx;

    assign ext_mem_addr = mem_addr[9:2];

    cpu cpu0 (
        .clk(clk),
        .rst(rst),
        .mem_valid(cpu_mem_valid),
        .mem_ready(cpu_mem_ready),
        .mem_addr(mem_addr),
        .mem_rdata(cpu_mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb)
    ); 
    
    ram ram0 (
        .clk(clk),
        .mem_valid(ram_mem_valid),
        .mem_ready(ram_mem_ready),
        .mem_addr(mem_addr),
        .mem_rdata(ram_mem_rdata),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb)
    );

    reg [31:0] gpio;
    assign leds = gpio[7:0];

    always @(posedge clk) begin
        if(gpio_mem_valid) begin
            if(mem_wstrb[0]) gpio[ 7: 0] <= mem_wdata[ 7: 0];
            if(mem_wstrb[1]) gpio[15: 8] <= mem_wdata[15: 8];
            if(mem_wstrb[2]) gpio[23:16] <= mem_wdata[23:16];
            if(mem_wstrb[3]) gpio[31:24] <= mem_wdata[31:24];
        end
    end

endmodule
