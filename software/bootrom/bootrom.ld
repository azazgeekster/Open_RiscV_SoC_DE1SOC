/*
 *  Linker script for the boot ROM downloader.
 *
 *  The bootloader lives in a 4K read-only ROM at 0x00000000,
 *  where the CPU starts fetching after reset. Its stack lives at
 *  the top of the 16K RAM at 0x00004000, which is also where it
 *  downloads programs to.
 */

MEMORY
{
   ROM   (rx)   : ORIGIN = 0x00000000, LENGTH = 4K
   RAM   (rwx)  : ORIGIN = 0x00004000, LENGTH = 16K
}


SECTIONS
{
   /*
    * The '.text' section contains code and read-only data
    * this can go straight into the ROM
    */
   .text :
   {
      _stext = .;          /* Provide the name for the start of this section */

      CREATE_OBJECT_SYMBOLS

      *(.reset.text)       /* Include the startup assembly code first */

      *(.text)
      *(.text.*)

      . = ALIGN(4);        /* Align the start of the rodata part */
      *(.rodata)
      *(.rodata.*)

      . = ALIGN(4);        /* Align the start of the small rodata part */
      *(.srodata)
      *(.srodata.*)

      . = ALIGN(4);        /* Align the end of the section */
      _etext = .;          /* Provide the name for the end of this section */

   } > ROM = 0


   /*
    * The '.data' section contains initialised data
    * this can go straight into the RAM in an FPGA based system
    */
   .data :
   {
      . = ALIGN(4);        /* Align the start of the section */
      _sdata = .;          /* Provide the name for the start of this section */

      *(.data)
      *(.data.*)

      . = ALIGN(4);        /* Align the start of the small data part */
      _small_data = .;     /* Provide the name for the start of this section */
      *(.sdata)
      *(.sdata.*)

      . = ALIGN(4);        /* Align the end of the section */
      _edata = .;          /* Provide the name for the end of this section */

   } > RAM


   /*
    * The '.bss' section contains uninitialised data
    * we would like this to go into RAM
    */
   .bss :
   {
      . = ALIGN(4);        /* Align the start of the section */
      _sbss = .;           /* Provide the name for the start of this section */

      *(.sbss)
      *(.sbss.*)

      . = ALIGN(4);        /* Align the start of bss part */
      *(.bss)
      *(.bss.*)

      . = ALIGN(4);        /* Align the end of the section */
      _ebss = .;           /* Provide the name for the end of this section */

   } > RAM


   /*
    * The following line assigns a symbol for the "bottom" of
    * the the stack. This symbol is used by the startup code in
    * order to initialise the stack pointer
    */
   _estack = ORIGIN(RAM) + LENGTH(RAM);


   /*
    * Assigning the special "__global_pointer$" symbol allows the
    * compiler to use gp relative addresses in the range:
    *  (__global_pointer$ - 0x800) - (__global_pointer$ + 0x7FF)
    *
    * The symbol is used by the startup code in order to initialise
    * the gp register.
    */
   __global_pointer$ = _small_data + 0x800;


   /*
    * Exception frames are not supported by this embedded system
    * so we will discard the 'eh_frame' section
    */
   /DISCARD/ :
   {
      *(.eh_frame)
   }

}

/*
 * The ENTRY section can be used to tell an emulator where
 * to start executing the code
 */
ENTRY(_start)
