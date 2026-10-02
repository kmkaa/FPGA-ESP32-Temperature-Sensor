module mcp3008_spi_master (
    input wire clk,
    input wire rst_n,
    input wire miso,
    output reg sclk,
    output reg cs_n,
    output reg mosi,
    output reg [9:0] adc_result,
    output reg result_valid
);

    localparam IDLE     = 2'b00;
    localparam SHIFTING = 2'b01;
    localparam DONE     = 2'b10;

    reg [1:0] state;
    reg [25:0] delay_counter;
    reg [5:0] sclk_counter;
    reg [4:0] bit_counter;
    reg [16:0] shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            delay_counter <= 26'd0;
            sclk_counter <= 6'd0;
            bit_counter <= 5'd0;
            shift_reg <= 17'd0;
            sclk <= 1'b0;
            cs_n <= 1'b1;
            mosi <= 1'b0;
            adc_result <= 10'd0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= 1'b0;

            case (state)
                IDLE: begin
                    cs_n <= 1'b1;
                    sclk <= 1'b0;
                    mosi <= 1'b0;
                    if (delay_counter == 26'd49_999) begin // 1ms refresh rate
                        delay_counter <= 26'd0;
                        cs_n <= 1'b0;
                        // Command frame for MCP3008 CH0: Start Bit (1), Single-Ended (1), CH0 (000)
                        shift_reg <= {1'b1, 1'b1, 3'b000, 12'b0};
                        bit_counter <= 5'd0;
                        sclk_counter <= 6'd0;
                        state <= SHIFTING;
                    end else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                SHIFTING: begin
                    if (sclk_counter == 6'd39) begin
                        sclk_counter <= 6'd0;
                        sclk <= ~sclk;

                        if (sclk == 1'b0) begin
                            // Falling edge: Drive next MOSI bit
                            mosi <= shift_reg[16];
                        end else begin
                            // Rising edge: Sample MISO bit and shift
                            shift_reg <= {shift_reg[15:0], miso};
                            if (bit_counter == 5'd16) begin
                                state <= DONE;
                            end else begin
                                bit_counter <= bit_counter + 1'b1;
                            end
                        end
                    end else begin
                        sclk_counter <= sclk_counter + 1'b1;
                    end
                end

                DONE: begin
                    cs_n <= 1'b1;
                    sclk <= 1'b0;
                    mosi <= 1'b0;
                    adc_result <= shift_reg[9:0];
                    result_valid <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule