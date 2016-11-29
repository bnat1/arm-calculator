@code for the add and substract subroutines/part of code
;file for integrating all code
;Rommel, Sam, Nat, Krunal

;This section is for labels pointing to memory
.data

;inputs
;+100.000
INPUT1: .word 0x00640000
;-37.123
INPUT2: .word 0x80251F7C

;results
INPUT1_FLOAT: .word 0   ;result of conversion to float for input 1
INPUT2_FLOAT: .word 0   ;result of conversion to float for input 2
ADDRESULT:  .word 0     ;result from addition algorithm
SUB_RESULT:  .word 0    ;result from subtraction algorithm
MUL_RESULT:  .word 0    ;result from multiplication algorithm
FOP_ADD: .word 0        ;result from built in addition instruction
FOP_SUB: .word 0        ;result from built in subtraction instruction
FOP_MUL: .word 0        ;result from built in multiplication instruction

;constants
GET_SIGN: .word 0x80000000      ;bitmask to get the sign of input
REM_SIGN: .word 0x7FFFFFFF      ;bitmask to remove the sign of input
EXP_INIT: .word 0x6F    ;111    ;value to start exponent counter
EXP_ZERO: .word 0x7F    ;127    ;zero exponent value
MAN_START: .word 0x86   ;       ;exponent where mantissa starts, eg, 2^7
REM_LEADING: .word 0xFF7FFFFF   ;bitmask to remove leading 1
GET_EXPONENT: .word 0x7F800000	;used to get the exponent in adder
GET_MANTISSA: .word 0x7FFFFF    ;used to get mantissa


;This section is for instructions
.text

.global _start
_start:
    ;BL is branch with link, meaing branch and store the next instruction in link register lr
    ;after the procedure, use BR LR to branch to the return address
    ;(see _DUMB_TO_IEEE)
    
    ;convert to float
    BL _DUMB_TO_IEEE

    ;at this point, the two inputs will be stored in INPUT1_FLOAT and INPUT2_FLOAT for usage. 
    ;make sure those registers don't change!

    ;addition
    BL _ADD
    
    ;subtraction
    BL _SUB
    
    ;multiplication
    BL _MUL
    
    ;exit
    B _exit

    
    ;subroutines
    ;takes input from r0, gives output in r0
    _DUMB_TO_IEEE:
        ;store LR on stack
        SUB SP, SP, #4
        STR LR, [SP,#0]

        ;Input 1
        LDR r0, =INPUT1
        LDR r0, [r0]
        BL _GET_FLOAT
        LDR r1, =INPUT1_FLOAT
        STR r0, [r1]

        ;Input 2
        LDR r0, =INPUT2
        LDR r0, [r0]
        BL _GET_FLOAT
        LDR r1, =INPUT2_FLOAT
        STR r0, [r1]

        ;restore LR 
        LDR LR, [SP,#0]
        ADD SP, SP, #4

        ;return
        MOV PC, LR

    _GET_FLOAT:
        ;store lr and used registers (r4-r6) on stack
        SUB SP, SP, #16
        STR lr, [SP,#12]
        STR r4, [SP,#8]
        STR r5, [SP,#4]
        STR r6, [SP,#0]
        
        ;input is in r0

        ;get sign layer in r1
        LDR r1, =GET_SIGN
        LDR r1, [r1]
        AND r1, r0, r1

        ;get exponent layer in r2
        MOV r2, r0
        ;remove sign
        LDR r3, =REM_SIGN
        LDR r3, [r3]
        AND r2, r3, r2
        
        ;init shifting loop variables
        LDR r4, =EXP_INIT   ;counter
        LDR r4, [r4]    

        ;compare to 0, special case
        CMP r0, #0
        BEQ _ZERO

        ;shift right until == 1
        _SRLOOP:
        ;compare to 1
        CMP r2, #1
        BEQ _SRLOOP_END
        ;shift right
        MOV r2, r2, LSR #1
        ;increment counter
        ADD r4, r4, #1
        B _SRLOOP
        
        _ZERO:
        ;set exponent to 0, i.e. 127
        LDR r4, =EXP_ZERO
        LDR r4, [r4]
        B _SRLOOP_END

        _SRLOOP_END:
        ;shift counter left, store in r2
        MOV r2, r4, LSL #23

        ;get mantissa layer in r3
        LDR r3, =MAN_START
        LDR r3, [r3]
        MOV r5, r0
        LDR r6, =REM_SIGN
        LDR r6, [r6]
        AND r5, r5, r6

        ;determine which way to shift the mantissa 
        CMP r4, r3
        BLT _SMALL
        BGT _BIG
        ;exponent = 7, no need to shift
        B _DONE_MAN

        _SMALL:
        ;amout to shift left by
        SUB r6, r3, r4
        MOV r5, r5, LSL r6
        B _DONE_MAN

        _BIG:
        ;amount to shift right by
        SUB r6, r4, r3
        MOV r5, r5, LSR r6

        _DONE_MAN:
        ;remove leading 1
        LDR r6, =REM_LEADING
        LDR r6, [r6]
        AND r5, r5, r6
        MOV r3, r5

        ;OR everything together for final result
        ORR r0, r1, r2
        ORR r0, r0, r3

        ;stack: restore lr, registers 4-6, stack pointer
        LDR r6, [SP,#0]
        LDR r5, [SP,#4]
        LDR r4, [SP,#8]
        LDR lr, [SP,#12]
        ADD SP, SP, #16

        ;return
        MOV PC, LR

    _ADD:
 
    ;addition subroutine code goes here
    ;store lr and used registers (r4-r6) on stack
        SUB SP, SP, #36
        STR lr, [SP,#32]
        STR r11, [SP,#28]
        STR r10, [SP,#24]
        STR r9, [SP,#20]
        STR r8, [SP,#16]
        STR r7, [SP,#12]
        STR r4, [SP,#8]
        STR r5, [SP,#4]
        STR r6, [SP,#0] 
        
        MOV r7, #0       ;clears registers
        MOV r4, #0
        MOV r5, #0
        MOV r6, #0
        
        LDR r4, =INPUT1_FLOAT
        LDR r4, [r4]		;r4 = input 1 in ieee754
        LDR r6, =GET_SIGN	;r6 pointer to 100..
        LDR r5, [r6]		;r5 = 100..
        LDR r6, [r6]		;r6 = 100..
        AND r5, r4, r5		;r5 has either 100... or 000...
     
        CMP r5, r6		;if neg 
        BEQ P1_negate		;goto p1_negate
        B P1_Skip			;else skip negating p1
P1_negate: 
        MOV r7,#-1			
        MUL r5, r4, r7
        mov r4,r5				;;We keep input 1 float in r4
        ;B P1_negate_Back  	
P1_Skip:
		LDR r5, =INPUT2_FLOAT
        LDR r5, [r5]		;r5 = input 2 in ieee754
		;check if p2 is neg
		; if it is go p2_negate 
		;else branch to p2_skip
		;r5 is going to have p2

		LDR r7, =GET_EXPONENT  	;used to get exponent 
        LDR r7, [r7]		
		
		AND r6, r4, r7		; r6 has input1's exponent
		AND r7, r5, r7 		; r7 has input2's exponent  
		
		LDR r10, =GET_MANTISSA
		LDR r10, [r10]
		AND r8, r10, r4    ;r8 has p1 mantissa
		AND r9, r10, r5	   ;r9 has p2 mantissa
	
		CMP	r6,r7
		BLT	P2_Fix_Exp
		BGT P1_Fix_Exp
		B	EQ_No_Fix_Needed
		
P1_Fix_Exp:
			;P2 > P1
			MOV r8, r8, LSR #1
			MOV r11, #0x800000
			ADD r6, r6, r8
			CMP r6,r7
			BGT P1_Fix_Exp
P2_Fix_Exp:
			
EQ_No_Fix_Needed:
		
        
        ;stack: restore lr, registers 4-6, stack pointer
        LDR r6, [SP,#0]
        LDR r5, [SP,#4]
        LDR r4, [SP,#8]
        LDR r7, [SP,#12]
        LDR r8, [SP,#16]
        LDR r9, [SP,#20]
        LDR r10, [SP,#24]
        LDR r11, [SP,#28]
        LDR lr, [SP,#32]
        ADD SP, SP, #36
        
       
        
        
        

    _SUB:
    ;subtraction subroutine code goes here

    _MUL:
    ;multiplication subroutine code goes here

    _exit:
        mov     r0, #0      ;status -> 0 
        mov     r7, #1      ;exit is syscall #1 
        swi     0x11        ;invoke syscall 
