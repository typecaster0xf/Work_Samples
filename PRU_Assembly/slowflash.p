#include <memoryMacros.hp>
#include <util.hp>



.origin 0
.entrypoint MAIN



/* Test code for updating GPIO pin P9_31 via the
 * output register. */
MAIN:
        MOV  R30, 0
        
        SET  R30.t2
        MEM_WRITE  R30, 0
        
        DELAY_CYCLES  CLOCK_HZ
        
        CLR  R30.t2
        MEM_WRITE  R30, 1
        
        DELAY_CYCLES  CLOCK_HZ
        
        EXIT
