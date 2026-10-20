/*=========================================================================*/
/*  Bootloader: downloads a program over UART into RAM, then jumps to it    */
/*=========================================================================*/

#include <stdint.h>

#define AHB_UART_BASE  0x60000000
#define AHB_RAM_BASE   0x00004000

#define AHB_OPORT_BASE 0x50000000

typedef volatile struct {
    uint32_t data;
    uint32_t status;
} uart_t;

static void uart_send(uint8_t c) {
    uart_t *u = (uart_t *)AHB_UART_BASE;
    while ((u->status & 0x1) == 0) {}
    u->data = c;
}

static uint8_t uart_recv(void) {
    uart_t *u = (uart_t *)AHB_UART_BASE;
    while ((u->status & 0x2) == 0) {}
    return (uint8_t)u->data;
}

int main(void) {
    uint32_t len;
    uint32_t i;
    uint8_t *dst = (uint8_t *)AHB_RAM_BASE;
    volatile uint32_t *leds = (volatile uint32_t *)AHB_OPORT_BASE;

    /* light up all LEDs to show bootrom is alive */
    *leds = 0x3FF;

    /* Read the physical switches */
    volatile uint32_t *switches = (volatile uint32_t *)0x40000000;
    
    /* If Switch 9 (0x200) is NOT ON, jump instantly to pre-loaded RAM */
    if ((*switches & 0x200) == 0) {
        ((void (*)(void))AHB_RAM_BASE)();
        return 0; // never reached
    }

    /* Otherwise, SW9 is ON -> Enter UART Download Mode */

    /* announce readiness so the host knows it can start sending */
    uart_send('R');
    uart_send('E');
    uart_send('A');
    uart_send('D');
    uart_send('Y');
    uart_send('\n');

    /* read the 4 byte big-endian length prefix */
    len  = ((uint32_t)uart_recv()) << 24;
    len |= ((uint32_t)uart_recv()) << 16;
    len |= ((uint32_t)uart_recv()) << 8;
    len |= ((uint32_t)uart_recv()) << 0;

    /* show the decoded length on the LEDs for 1 second */
    *leds = len;

    /* store the payload byte-by-byte starting at the RAM base address */
    /* also update the LEDs with the progress! */
    for (i = 0; i < len; i++) {
        dst[i] = uart_recv();
        if ((i % 16) == 0) {
            *leds = i; // show download progress
        }
    }

    /* acknowledge receipt */
    uart_send('O');
    uart_send('K');
    uart_send('\n');

    /* success! jump to the freshly downloaded program */
    ((void (*)(void))AHB_RAM_BASE)();

    /* never reached */
    return 0;
}
