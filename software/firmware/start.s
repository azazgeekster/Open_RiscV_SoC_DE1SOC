.section .reset.text, "ax"
.global _start
_start:
    .cfi_startproc
    .cfi_undefined ra

    # set the global pointer (gp)
    #   (requires 'norelax' directive
    #    because gp is not yet defined)
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    # set the stack pointer (sp)
    la sp, _estack

    # set the frame pointer (s0) = sp
    mv s0, sp

    # call the reset handler
    jal ra, ResetHandler
    
    # ResetHandler should not return
    # so this instruction should not be reached
    do_nothing: j do_nothing

    .cfi_endproc
    .end
