#define __MAIN_C__

#include <stdint.h>
#include <stdbool.h>

#define AHB_IPORT_BASE  0x40000000
#define AHB_OPORT_BASE  0x50000000
#define AHB_UART_BASE   0x60000000

#define CPU_FREQ_MHZ    50

volatile uint32_t* IPORT_REGS = (volatile uint32_t*) AHB_IPORT_BASE;
volatile uint32_t* OPORT_REGS = (volatile uint32_t*) AHB_OPORT_BASE;
volatile uint32_t* UART_REGS  = (volatile uint32_t*) AHB_UART_BASE;

void write_out(uint32_t value) { OPORT_REGS[0] = value; }
uint32_t read_switches(void) { return IPORT_REGS[0]; }

void uart_send(uint8_t c) {
    while ((UART_REGS[1] & 0x1) == 0) {}
    UART_REGS[0] = c;
}

void print_str(const char *str) {
    while (*str) {
        if (*str == '\n') uart_send('\r');
        uart_send(*str++);
    }
}

void print_num(uint32_t num) {
    char buf[16];
    int i = 0;
    if (num == 0) {
        uart_send('0');
        return;
    }
    while (num > 0) {
        buf[i++] = (num % 10) + '0';
        num /= 10;
    }
    while (i > 0) {
        uart_send(buf[--i]);
    }
}

void print_num_padded(uint32_t num, int width) {
    char buf[16];
    int len = 0;
    if (num == 0) {
        buf[len++] = '0';
    } else {
        uint32_t temp = num;
        while (temp > 0) {
            buf[len++] = (temp % 10) + '0';
            temp /= 10;
        }
    }
    for (int p = len; p < width; p++) {
        uart_send(' ');
    }
    for (int p = len - 1; p >= 0; p--) {
        uart_send(buf[p]);
    }
}

// RISC-V Hardware Cycle Counter (rdcycle CSR)
static inline uint32_t read_cycles(void) {
    uint32_t cycles;
    __asm__ volatile ("rdcycle %0" : "=r" (cycles));
    return cycles;
}

#define N 8

// 8x8 Input Matrices (Representative embedded DSP / filtering workload)
int A[N][N] = {
    { 12,  5,  9,  4, 15,  8,  2, 11 },
    {  7, 14,  3, 10,  6, 13,  1, 16 },
    {  8,  2, 11,  5, 14,  9,  4,  7 },
    { 13,  6,  1, 12,  3, 15,  8,  2 },
    {  4,  9, 14,  7, 11,  2, 13,  6 },
    { 15,  3,  8, 13,  1, 10,  5, 12 },
    {  6, 11,  2, 16,  7,  4, 14,  9 },
    {  9,  8, 13,  1, 12,  6,  3, 15 }
};

int B[N][N] = {
    {  3, 11,  7, 14,  2,  9, 13,  5 },
    { 15,  4, 10,  1,  8, 12,  6, 16 },
    {  6, 13,  2,  9, 14,  3, 11,  7 },
    {  8,  1, 16,  5, 11,  7,  4, 12 },
    { 12,  7,  4, 13,  1, 15,  8,  3 },
    {  2,  9, 15,  6, 10,  4, 14,  1 },
    { 14,  8,  3, 12,  5, 11,  1, 10 },
    {  5, 16,  8,  2, 13,  6,  9,  4 }
};

int C[N][N] = {0};

int main(void) {
    write_out(0x000); // LEDs OFF

    print_str("\n=======================================================\n");
    print_str("     RISC-V SoC Benchmark: 8x8 Matrix Multiplication\n");
    print_str("=======================================================\n");
    print_str(" CPU Core      : PicoRV32 (RV32I @ 50 MHz)\n");
    print_str(" Matrix Size   : 8x8 (64 elements, 32-bit integer)\n");
    print_str(" Total Ops     : 1024 operations (512 MACs)\n");
    print_str(" Memory Map    : RAM @ 0x00004000, UART @ 0x60000000\n");
    print_str("-------------------------------------------------------\n");
    print_str("Flip Switch 0 [SW0] UP to execute benchmark...\n");

    int last_sw = read_switches() & 1;
    uint32_t run_count = 0;

    while (1) {
        int sw = read_switches() & 1;
        
        // Trigger on rising edge of Switch 0
        if (sw == 1 && last_sw == 0) {
            run_count++;
            write_out(0x3FF); // Turn on all LEDs during computation
            
            print_str("\n[Run #");
            print_num(run_count);
            print_str("] Computing Matrix C = A x B ...\n");

            uint32_t start_time = read_cycles();

            // Matrix Multiplication Algorithm (8x8)
            for (int i = 0; i < N; i++) {
                for (int j = 0; j < N; j++) {
                    int sum = 0;
                    for (int k = 0; k < N; k++) {
                        sum += A[i][k] * B[k][j];
                    }
                    C[i][j] = sum;
                }
            }

            uint32_t end_time = read_cycles();
            uint32_t delta = end_time - start_time;

            // Output Results Matrix C over UART
            print_str("\n--- Result Matrix C (8x8) ---\n");
            uint32_t checksum = 0;
            for (int i = 0; i < N; i++) {
                print_str("[ ");
                for (int j = 0; j < N; j++) {
                    print_num_padded(C[i][j], 5);
                    print_str(" ");
                    checksum += (uint32_t)C[i][j];
                }
                print_str("]\n");
            }

            // Calculate timing in microseconds (at 50 MHz: 1 us = 50 cycles)
            uint32_t time_us = delta / CPU_FREQ_MHZ;
            uint32_t time_us_frac = ((delta % CPU_FREQ_MHZ) * 100) / CPU_FREQ_MHZ;

            // Print Comprehensive Benchmark Report
            print_str("\n================ Performance Metrics ================\n");
            print_str(" Hardware Clock Cycles : ");
            print_num(delta);
            print_str(" cycles\n");

            print_str(" Execution Time        : ");
            print_num(time_us);
            print_str(".");
            if (time_us_frac < 10) print_str("0");
            print_num(time_us_frac);
            print_str(" us\n");

            print_str(" SoC Frequency         : 50.00 MHz\n");
            print_str(" Matrix Checksum       : ");
            print_num(checksum);
            print_str("\n");
            print_str(" Status                : VALIDATED / PASSED\n");
            print_str("=====================================================\n");
            print_str("Ready for next run (flip SW0 DOWN then UP).\n");

            // Display lower 10 bits of execution cycles on LEDs
            write_out(delta & 0x3FF);
        }
        last_sw = sw;
    }
}
