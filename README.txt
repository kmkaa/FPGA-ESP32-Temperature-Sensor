Real-Time Temperature Sensor (FPGA + Firmware + Analog)

An end-to-end hardware-software temperature sensing system. An NTC thermistor conditions an analog signal through an op-amp buffer, digitizes it via an SPI ADC, processes the logic on a Cyclone V FPGA, and streams serial data over a second SPI interface to an ESP32

Project Goals
- Mixed-Signal Interfacing: Design and validate an end-to-end signal pipeline bridging low-level analog sensing, hardware logic (FPGA), and embedded software (ESP32).

- Protocol & Logic Design in Verilog: Implement both SPI Master (to sample the ADC) and SPI Slave (to serve data to the MCU) state machines in hardware from scratch without vendor IP blocks.

- Verification-Build test benches using (+GOLDEN= Vector) and automated Python regression running ModelSim simulations

- Hardware-Firmware Boundary: Establish a low-latency digital link between an FPGA and a C-based ESP-IDF driver, delegating DSP filtering and temperature math (Beta parameter model) to the firmware layer.

- PCB Integration: Translate the validated breadboard prototype into a custom Altium board schematic and layout.

Hardware Architecture:
[NTC Thermistor] -> [MCP6002 Op-Amp Buffer] -> [MCP3008 ADC]
                                                     |
                                            (SPI Master Interface)
                                                     v
                                           [DE1-SoC FPGA (Cyclone V)]
                                                     |
                                            (SPI Slave Interface)
                                                     v
                                              [ESP32 Microcontroller]
                                                     |
                                                (UART Log)
                                                     v
                                             [Serial Monitor]

1. Analog
	Sensor: 10k Ohm NTC Thermistor in a voltage divider with 3k ohm resistor
	Buffer: MCP6002 op-amp configured as a unity-gain buffer to lower source impedance into ADC
2. ADC
	MCP3008: 8 channel, 10 bit ADC with Vdd = 3.3V. Digitized to buffer 0-3.3V analog signal into 10 bit digital code (0-1023)
3. FPGA (writer in Verilog)
	mcp3008_spi_master: Custom SPI master module that requests Channel 0 of ADC every 1 second. Handles clock divisions, chip select assertions and 17 bit register shifting
	esp32_spi_follower: double buffered SPI slave module that takes the latest 10 bit ADC sample to external master. Clock edge sync across domains to prevent metastability 
	fpgatemp_wrapper: Top level wrapper connecting above modules and syncing hardware resets and routing GPIO pin assignments
4. ESP32 
	Written in C using platformIO
	-operates SPI master polling FPGA at 1MHz
	Computes temperature using Beta parameter model
5. Verification
	Testbench for MCP3008 SPI master: Simulate MCP3008 ADC response by waiting for CS assertion, driving 10-bit test patterns on miso during falling edges and verifying ADC results.
	Testbench for ESP32 SPI Follower: Generate asynchronous 1MHz simulated ESP32 clock against FPGA 50Mhz clock. Asserts active-low CS, samples miso on rising edge and asserts pass when captured frames match the refernce
	Automated Python Regression: Sets up vsim in batch mode across a vector sweeping all zero, all 1m alternating and edge cases. Checks for PASS and generates a report summarizing PASS/FAILS
	 
6. PCB (Altium Designer) *in progress*
	Tested and verified on breadboard (Done)
	Create a motherboard to place all components using through hole and headers for ESP32
	2 layer PCB design. 

Lessons learned
	- Clock Domain sync: Solved asynchronous clocking glitches between ESP32 SPI clock and FPGA onboard clock using 2 stage flip flop for SCLK, CS and	 MOSI
	- SPI mode and Bit shift alignment- Aligned falling edge output transitions on FPGA slave shift reg to meet rising edge of ESP32 SPI Mode 0
	- Verified signal integrity across all nodes using multimeter
