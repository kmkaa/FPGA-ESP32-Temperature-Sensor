#include <stdio.h>
#include <math.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/spi_master.h"
#include "esp_log.h"

#define PIN_SCLK 18
#define PIN_MOSI 23
#define PIN_MISO 19
#define PIN_CS   5

static const char *TAG = "temp_sensor";
spi_device_handle_t spi_handle;

void spi_init(void) {
    spi_bus_config_t buscfg = {
        .miso_io_num = PIN_MISO,
        .mosi_io_num = PIN_MOSI,
        .sclk_io_num = PIN_SCLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
    };

    spi_device_interface_config_t devcfg = {
        .clock_speed_hz = 1 * 1000 * 1000, // 1 MHz
        .mode = 0,                          // SPI mode 0
        .spics_io_num = PIN_CS,             
        .queue_size = 1,
    };

    spi_bus_initialize(SPI2_HOST, &buscfg, SPI_DMA_CH_AUTO);
    spi_bus_add_device(SPI2_HOST, &devcfg, &spi_handle);
}

int read_adc_code(void) {
    uint8_t tx_data[2] = {0x00, 0x00}; // Dummy bytes to generate SPI clock
    uint8_t rx_data[2] = {0, 0};

    spi_transaction_t t = {
        .length = 16,
        .rxlength = 16,
        .tx_buffer = tx_data,
        .rx_buffer = rx_data,
    };

    esp_err_t ret = spi_device_transmit(spi_handle, &t);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "SPI Transmit failed");
        return 0;
    }

    // 1. Declare and compute raw16 FIRST
    uint16_t raw16 = (rx_data[0] << 8) | rx_data[1];

    // 2. Now pass raw16 to the logger
    ESP_LOGI(TAG, "RX Bytes: [0x%02X, 0x%02X] -> Raw16: 0x%04X", rx_data[0], rx_data[1], raw16);

    // 3. Compute ADC code
    int adc_code = raw16 >> 6;
    return adc_code;
}

float raw_code_to_temp(int adc_code) {
    if (adc_code <= 0) {
        return -999.0f; 
    }
    if (adc_code >= 1023) {
        return -998.0f;
    }

    const float VREF = 3.3f;
    const float R_FIXED = 3000.0f;
    const float R0 = 10000.0f;
    const float BETA = 3950.0f;
    const float T0 = 298.15f;

    float v_adc = VREF * ((float)adc_code / 1024.0f);
    float r_therm = (VREF * R_FIXED / v_adc) - R_FIXED;
    float temp_k = 1.0f / ((logf(r_therm/R0) / BETA) +(1.0f / T0));
    return temp_k - 273.15f;
}

void app_main(void){
    spi_init();

    while(1){
        int code = read_adc_code();
        float temp = raw_code_to_temp(code);

        if (temp == -999.0f) {
            ESP_LOGW(TAG, "Sensor disconnected (open circuit)");
        } else if (temp == -998.0f) {
            ESP_LOGW(TAG, "Sensor shorted");
        } else {
            ESP_LOGI(TAG, "ADC Code: %d, Temperature: %.2f C", code, temp);
        }
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}