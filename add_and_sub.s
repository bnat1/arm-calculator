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
ADD_RESULT:  .word 0     ;result from addition algorithm
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
        SUB SP, SP, #44
        STR lr, [SP,#32]
        STR r11, [SP,#28]
        STR r10, [SP,#24]
        STR r9, [SP,#20]
        STR r8, [SP,#16]
        STR r7, [SP,#12]
        STR r4, [SP,#8]
        STR r5, [SP,#4]
        STR r6, [SP,#0] 
        
        MOV r11, #0
        MOV r10, #0
        MOV r9, #0
        MOV r8, #0
        MOV r7, #0       ;clears registers
        MOV r4, #0
        MOV r5, #0
        MOV r6, #0
        
        
        LDR r4, =INPUT1_FLOAT
        LDR r4, [r4]		;r4 = input 1 in ieee754
        
		LDR r5, =INPUT2_FLOAT
        LDR r5, [r5]		;r5 = input 2 in ieee754
		
		LDR r7, =GET_EXPONENT  	;used to get exponent 
        LDR r7, [r7]		
		
		AND r6, r4, r7		; r6 has input1's exponent
		AND r7, r5, r7 		; r7 has input2's exponent  
		
		LDR r10, =GET_MANTISSA
		LDR r10, [r10]
		AND r8, r10, r4    ;r8 has p1 mantissa
		AND r9, r10, r5	   ;r9 has p2 mantissa
	
	;add leading one to mantissa for r8 and r9
	
		
		mov r12, #0x00800000
		ORR r8, r8, r12 
		ORR r9, r9, r12
	
	
	;if exponents are different
	
		CMP	r6,r7
		BGT	A2_Fix_Exp
		BLT A1_Fix_Exp
		B	EQ_No_Fix_Needed
		
A1_Fix_Exp:
			;P2 > P1
			MOV r8, r8, LSL #1	; shift p1 mantissa
			MOV r11, #0x800000	;set r11 to 'one'
			ADD r6, r6, r11		;add 'one' to p1 exponent
			CMP r6,r7			;compare exponents
			BLT A1_Fix_Exp		;jump back to loop
			B EQ_No_Fix_Needed
A2_Fix_Exp:
			;P1 > P2
			MOV r9, r9, LSL #1	; shift p2 mantissa
			MOV r11, #0x800000	;set r11 to 'one'
			ADD r7, r7, r11		;add 'one' to p2 exponent
			CMP r6,r7			;compare exponents
			BGT A2_Fix_Exp		;jump back to loop
			B EQ_No_Fix_Needed
			
EQ_No_Fix_Needed:
		
			;;add mantissas
		LDR r10, =GET_SIGN	;point r10  to 100..
        LDR r10, [r10]		;r10 = 100..
        MOV r1,r10			;r1 is get sign 
        ;r11 has 100.. if p2 is neg
        AND r11, r10, r5		;r10 has either 100... or 000...
        ;r10 has 1000.. if p1 is neg
        AND r10, r4, r10
        
     
     ;;before checking if their negative push mantissas to stack
             STR r8, [SP,#36]
             STR r9, [SP,#40]             
     
        CMP r10, r1		;if neg 
        BEQ A1_negate		;goto p1_negate
        B A1_Skip			;else skip negating p1
A1_negate: 
		MVN r8,r8
		ADD r8, r8, #1
		B A1_Skip
A1_Skip:

		CMP r11, r1		;if neg 
        BEQ A2_negate		;goto p2_negate
        B A2_Skip			;else skip negating p2
A2_negate: 
		MVN r9,r9
		ADD r9, r9, #1
		B A2_Skip
A2_Skip:
        
        ;;add the mantisas
		Add r2, r8, r9    
		
		;;check special cases
		;;case_2: if both are neg    
		;;case_1: if bigger mantissa is neg

        LDR r9, [SP,#40]
        LDR r8, [SP,#36]
        
        ;init sign of answer to zero
        MOV r3, #0
		;if #1 is neg
		CMP r10, r1		;if P1 neg 
		BEQ CASE_0
		
		;elif #2 is neg
		CMP r11, r1		;if P2 neg 
		BEQ CASE_1
		
		;else
		B GOOD_TO_GO_NEGS
		
CASE_0:	;p1 is neg
		CMP r11, r1		;if p2 neg
		BEQ UNNEGATE
		
		;CHECK IF mantissa for p1 is bigger
		CMP r8,r9
		BGT UNNEGATE
		;ELSE jump to good state
		B GOOD_TO_GO_NEGS
		
CASE_1:	;#2 is neg
		
		;check if mantissa #2 is bigger 
		CMP r9,r8
		BGT UNNEGATE

		B GOOD_TO_GO_NEGS				
				
UNNEGATE:
		SUB r2, r2, #1
		MVN r2, r2
		;put negative sign
		MOV r3, r1 	
		
		B GOOD_TO_GO_NEGS
GOOD_TO_GO_NEGS:
        ;check for normalization
        mov r1,#0x00FFFFFF
        CMP r2, r1
 		BGT NORMALIZE
 		B NORM_GOOD
NORMALIZE:
		;shift mantissa
		MOV r2, r2, LSR #1
		;adjust exponent
		mov r7, #0x800000
		ADD r6, r6, r7
		
		;check for normalization
		mov r7, #0x00FFFFFF
        CMP r2, r7
 		BGT NORMALIZE
 		B NORM_GOOD
 		
NORM_GOOD:

		;remove leading 1
		LDR r1, =GET_MANTISSA
		LDR r7, [r1]

		AND r2, r2, r7
		;OR everything together
		ORR r3, r3, r2
		ORR r3, r3, r6
		LDR r0, =ADD_RESULT
 		STR r3, [r0]
 		
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
        ADD SP, SP, #44
        MOV PC, lr
        
       
        
        
        

    _SUB:
    ;subtraction subroutine code goes here
    	SUB SP, SP, #44
        STR lr, [SP,#32]
        STR r11, [SP,#28]
        STR r10, [SP,#24]
        STR r9, [SP,#20]
        STR r8, [SP,#16]
        STR r7, [SP,#12]
        STR r4, [SP,#8]
        STR r5, [SP,#4]
        STR r6, [SP,#0] 
        
        MOV r11, #0
        MOV r10, #0
        MOV r9, #0
        MOV r8, #0
        MOV r7, #0       ;clears registers
        MOV r4, #0
        MOV r5, #0
        MOV r6, #0

		LDR r4, =INPUT1_FLOAT
        LDR r4, [r4]		;r4 = input 1 in ieee754
        
		LDR r5, =INPUT2_FLOAT
        LDR r5, [r5]		;r5 = input 2 in ieee754
		
		LDR r7, =GET_EXPONENT  	;used to get exponent 
        LDR r7, [r7]		
		
		AND r6, r4, r7		; r6 has input1's exponent
		AND r7, r5, r7 		; r7 has input2's exponent  
		
		LDR r10, =GET_MANTISSA
		LDR r10, [r10]
		AND r8, r10, r4    ;r8 has p1 mantissa
		AND r9, r10, r5	   ;r9 has p2 mantissa
	
	;add leading one to mantissa for r8 and r9
	
		
		mov r12, #0x00800000
		ORR r8, r8, r12 
		ORR r9, r9, r12
	
	
	;if exponents are different
	
		CMP	r6,r7
		BGT	S2_Fix_Exp
		BLT S1_Fix_Exp
		B	SEQ_No_Fix_Needed
		
S1_Fix_Exp:
			;P2 > P1
			MOV r8, r8, LSL #1	; shift p1 mantissa
			MOV r11, #0x800000	;set r11 to 'one'
			ADD r6, r6, r11		;add 'one' to p1 exponent
			CMP r6,r7			;compare exponents
			BLT S1_Fix_Exp		;jump back to loop
			B SEQ_No_Fix_Needed
S2_Fix_Exp:
			;P1 > P2
			MOV r9, r9, LSL #1	; shift p2 mantissa
			MOV r11, #0x800000	;set r11 to 'one'
			ADD r7, r7, r11		;add 'one' to p2 exponent
			CMP r6,r7			;compare exponents
			BGT S2_Fix_Exp		;jump back to loop
			B SEQ_No_Fix_Needed
			
SEQ_No_Fix_Needed:
		
			;;add mantissas
		LDR r10, =GET_SIGN	;point r10  to 100..
        LDR r10, [r10]		;r10 = 100..
        MOV r1,r10			;r1 is get sign 
        ;r11 has 100.. if p2 is neg
        AND r11, r10, r5		;r10 has either 100... or 000...
        ;r10 has 1000.. if p1 is neg
        AND r10, r4, r10
        
         ;;before checking if they're negative push mantissas to stack
             STR r8, [SP,#36]
             STR r9, [SP,#40] 
        
        CMP r10, r1
        BEQ other1
        B 	other2
        
        
        
 other1:
 		MOV r8, #0
 		AND r10, r10, r8
 		B 	other3
 other2:
 		ORR r10, r10, r1
 		B	other3
 other3:
     ;;before checking if they're negative push mantissas to stack
             EOR r8, r8, r8
             EOR r9, r9, r9             
     
        CMP r10, r1		;if neg 
        BEQ S1_negate		;goto p1_negate
        B S1_Skip			;else skip negating p1
S1_negate: 
		MVN r8,r8
		ADD r8, r8, #1
		B S1_Skip
S1_Skip:

		CMP r11, r1		;if neg 
        BEQ S2_negate		;goto p2_negate
        B S2_Skip			;else skip negating p2
S2_negate: 
		MVN r9,r9
		ADD r9, r9, #1
		B S2_Skip
S2_Skip:
        
        ;;add the mantisas
		Add r2, r8, r9    
		
		;;check special cases
		;;case_2: if both are neg    
		;;case_1: if bigger mantissa is neg

        LDR r9, [SP,#40]
        LDR r8, [SP,#36]
        
        ;init sign of answer to zero
        MOV r3, #0
		;if #1 is neg
		CMP r10, r1		;if P1 neg 
		BEQ SUBCASE_0
		
		;elif #2 is neg
		CMP r11, r1		;if P2 neg 
		BEQ SUBCASE_1
		
		;else
		B SUBGOOD_TO_GO_NEGS
		
SUBCASE_0:	;p1 is neg
		CMP r11, r1		;if p2 neg
		BEQ S_UNNEGATE
		
		;CHECK IF mantissa for p1 is bigger
		CMP r8,r9
		BGT S_UNNEGATE
		;ELSE jump to good state
		B SUBGOOD_TO_GO_NEGS
		
SUBCASE_1:	;#2 is neg
		
		;check if mantissa #2 is bigger 
		CMP r9,r8
		BGT S_UNNEGATE

		B SUBGOOD_TO_GO_NEGS				
				
S_UNNEGATE:
		SUB r2, r2, #1
		MVN r2, r2
		;put negative sign
		MOV r3, r1 	
		
		B SUBGOOD_TO_GO_NEGS
SUBGOOD_TO_GO_NEGS:
        ;check for normalization
        mov r1,#0x00FFFFFF
        CMP r2, r1
 		BGT S_NORMALIZE
 		B 	SUBNORM_GOOD
S_NORMALIZE:
		;shift mantissa
		MOV r2, r2, LSR #1
		;adjust exponent
		mov r7, #0x800000
		ADD r6, r6, r7
		
		;check for normalization
		mov r7, #0x00FFFFFF
        CMP r2, r7
 		BGT S_NORMALIZE
 		B 	SUBNORM_GOOD
 		
SUBNORM_GOOD:

		;remove leading 1
		LDR r1, =GET_MANTISSA
		LDR r7, [r1]

		AND r2, r2, r7
		;OR everything together
		ORR r3, r3, r2
		ORR r3, r3, r6
		LDR r0, =ADD_RESULT
 		STR r3, [r0]
 		
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
        ADD SP, SP, #44
        MOV PC, lr

    _MUL:
    ;multiplication subroutine code goes here

    _exit:
        mov     r0, #0      ;status -> 0 
        mov     r7, #1      ;exit is syscall #1 
        swi     0x11        ;invoke syscall 
