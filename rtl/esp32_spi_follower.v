module esp32_spi_follower (
	input wire clk,
	input wire rst_n,
	input wire sclk_ext,
	input wire cs_ext,
	input wire mosi_ext,
	input wire [9:0] adc_result,
	input wire result_valid, //maybe use idk
	output reg miso
);

	reg sclk_sync1, sclk_sync2, sclk_sync3;
	reg cs_sync1, cs_sync2;
	reg mosi_sync1, mosi_sync2;
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			sclk_sync1 <= 1'b0;
			sclk_sync2 <= 1'b0;
			sclk_sync3 <= 1'b0;
			cs_sync1 <= 1'b1;
			cs_sync2 <= 1'b1;
			mosi_sync1 <= 1'b0;
			mosi_sync2 <= 1'b0;
		end else begin
			sclk_sync1 <= sclk_ext;
			sclk_sync2 <= sclk_sync1;
			sclk_sync3 <= sclk_sync2;
			cs_sync1 <= cs_ext;
			cs_sync2 <= cs_sync1;
			mosi_sync1 <= mosi_ext;
			mosi_sync2 <= mosi_sync1;
		end
	end
	
	wire sclk_rising_edge = sclk_sync2 && !sclk_sync3;
	wire sclk_falling_edge = !sclk_sync2 && sclk_sync3;
	
	reg [9:0] tx_shift_reg;
	reg [3:0] bit_cnt;
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			miso <= 1'b0;
			tx_shift_reg <= 10'b0;
			bit_cnt <= 4'b0;
		end else if (cs_sync2) begin
			bit_cnt <= 4'b0;
			tx_shift_reg <= adc_result;
			miso <= 1'b0;
		end else begin
			miso <= tx_shift_reg[9];
			if (sclk_falling_edge) begin
				tx_shift_reg <= {tx_shift_reg[8:0], 1'b0};
				bit_cnt <= bit_cnt + 1'b1;
			end
		end
	end	
endmodule
	
	
	
	
	
	
	
	
	
	
	