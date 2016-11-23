;file for integrating all code
;Rommel, Sam, Nat, Krunal

;This section is for labels pointing to memory
.data

;+100.000
INPUT1: .word 0x00640000

;-37.123
INPUT2: .word 0x80251F7C

;result from addition algorithm
ADDRESULT:  .word 0

;result from subtraction algorithm
SUB_RESULT:  .word 0

;result from multiplication algorithm
MUL_RESULT:  .word 0

;result from built in addition instruction
FOP_ADD: .word 0

;result from built in subtraction instruction
FOP_SUB: .word 0

;result from built in multiplication instruction
FOP_MUL: .word 0


;This section is for instructions
.text

.global _start
_start:
    ;convert to float
    ;BL is branch with link, meaing branch and store the next instruction in link register lr
    ;at the beginning of a subroutine, store lr into a register for later use,
    ;at the end of the subroutine, put lr back into pc to go to the next instruction
    ;(see _FOPS as an example it doesn't do anything though)
    BL _DUMB_TO_IEEE

    ;addition
    BL _ADD
    
    ;subtraction
    BL _SUB
    
    ;multiplication
    BL _MUL
    
    ;built in fops
    BL _FOPS
    
    ;exit
    B _exit

    
    ;subroutines
    _DUMB_TO_IEEE:
    ;conversion subroutine code goes here

    _ADD:
    ;addition subroutine code goes here

    _SUB:
    ;subtraction subroutine code goes here

    _MUL:
    ;multiplication subroutine code goes here

    _FOPS:
    ;built in fops subroutine code goes here
    mov r4, lr
    nop
    mov pc, r4 

    _exit:
        mov     r0, #0      ;status -> 0 
        mov     r7, #1      ;exit is syscall #1 
        swi     0x11        ;invoke syscall 
