;file for integrating all code
;Rommel, Sam, Nathaniel, Krunal

;;memory
.data

	;inputs
	;enter inputs in dumb format here, in hex
	INPUT1: .word 0x0;0x00640000 	;+100.000
	INPUT2: .word 0x0;0x80251F7C	;-37.123

	;results will be stored in memory, pointed to by these labels
	INPUT1_FLOAT: .word 0   ;result of conversion to float for input 1
	INPUT2_FLOAT: .word 0   ;result of conversion to float for input 2
	ADD_RESULT:  .word 0    ;result from addition algorithm
	SUB_RESULT:  .word 0    ;result from subtraction algorithm
	MUL_RESULT:  .word 0    ;result from multiplication algorithm
	FOP_ADD: .word 0        ;result from built in addition instruction
	FOP_SUB: .word 0        ;result from built in subtraction instruction
	FOP_MUL: .word 0        ;result from built in multiplication instruction


;;ARM instructions
.text
.global _main

_main:

    BL _DUMB_TO_IEEE		;convert to float
    BL _ADD					;addition
    BL _SUB					;subtraction
    BL _MUL					;multiplication
    B _exit					;exit

    
;;subroutines

;takes input from INPUT1 and INPUT2
;stores results in INPUT1_FLOAT and INPUT2_FLOAT
_DUMB_TO_IEEE:
    ;store LR on stack
    SUB SP, SP, #4
    STR LR, [SP,#0]

    ;Input 1
    LDR r0, =INPUT1 		;get input 1
    LDR r0, [r0]
    BL _GET_FLOAT			;invoke subroutine to convert to float (located below this subroutine)
    LDR r1, =INPUT1_FLOAT	
    STR r0, [r1]			;store in memory

    ;Input 2
    LDR r0, =INPUT2 		;get input 2
    LDR r0, [r0]
    BL _GET_FLOAT 			;convert to float
    LDR r1, =INPUT2_FLOAT 	;store answer
    STR r0, [r1]

    ;restore LR and stack pointer
    LDR LR, [SP,#0]
    ADD SP, SP, #4

    ;return
    MOV PC, LR


;convert a single number from dumb to ieee
;input in r0
;output in r0
_GET_FLOAT:

    ;;get sign layer in r1
    LDR r1, =0x80000000
    AND r1, r0, r1

    ;;put exponent layer in r2
    MOV r2, r0
    LDR r3, =0x7FFFFFFF			;remove sign
    AND r2, r3, r2
    
    CMP r2, #0					;compare to 0, special case
    BEQ CONVERT_ZERO

    LDR r4, =0x6F   			;determine exponent by counting bits from right
    							;counter starts at 111, eg, biased exponent -16
SR_LOOP:

    CMP r2, #1					;compare input to 1
    BEQ SR_LOOP_END				;done if input == 1
    MOV r2, r2, LSR #1			;shift right
    ADD r4, r4, #1				;increment counter
    B SR_LOOP
    
    SR_LOOP_END:
    MOV r2, r4, LSL #23			;counter becomes ieee exponent 

    ;;put mantissa layer in r3

    LDR r3, =0x86				;biased exponent 7
    MOV r5, r0 					
    LDR r6, =0x7FFFFFFF			;remove sign from input
    AND r5, r5, r6
 
    CMP r4, r3					;determine which way to shift the mantissa
    BLT SMALL					;shift mantissa left (too small)
    BGT BIG					;shift mantissa right (too big)
    B DONE_MAN					;exponent = 7, no need to shift

SMALL:
    SUB r6, r3, r4 				;get amount to shift left by
    MOV r5, r5, LSL r6 			;shift left
    B DONE_MAN

BIG:
    SUB r6, r4, r3				;get amount to shift right by
    MOV r5, r5, LSR r6 			;shift right

DONE_MAN:
    LDR r6, =0x7FFFFF
    AND r5, r5, r6 				;remove leading 1 from mantissa
    MOV r3, r5 					;store mantissa in r3
    
    ORR r0, r1, r2 				;OR layers together for final result
    ORR r0, r0, r3

    B CONVERT_DONE

CONVERT_ZERO:
	;;special case: zero
	MOV r0, #0

CONVERT_DONE:
    ;;return
    MOV PC, LR


;addition subroutine
;gets input from INPUT1_FLOAT and INPUT2_FLOAT
;puts output in ADD_RESULT
_ADD:     
    MOV r11, #0
    MOV r10, #0
    MOV r9, #0
    MOV r8, #0
    MOV r7, #0       ;clears registers
    MOV r4, #0
    MOV r5, #0
    MOV r6, #0
    
    
    LDR r4, =INPUT1_FLOAT
    LDR r4, [r4]				;r4 = input 1 in ieee754
    
	LDR r5, =INPUT2_FLOAT
    LDR r5, [r5]				;r5 = input 2 in ieee754
   
    CMP r4, r6 					;check if input 1 is zero
    BEQ ADD_ZERO
    CMP r5, r6 					;check if input 2 is zero
    BEQ ADD_ZERO
	
	LDR r7, =0x7F800000 		;used to get exponent 
	AND r6, r4, r7				; r6 gets input1's exponent
	AND r7, r5, r7 				; r7 gets input2's exponent  
	
	LDR r10, =0x7FFFFF 			;used to get mantissa
	AND r8, r10, r4    			;r8 gets mantissa 1
	AND r9, r10, r5	   			;r9 gets mantissa 2

	MOV r12, #0x00800000		;give mantissas leading 1s
	ORR r8, r8, r12 
	ORR r9, r9, r12


	;;if exponents are different, we need to make them equal and adjust
	;;the mantissa of the smaller number
	CMP	r6,r7
	BGT	A2_Fix_Exp				;exponent 1 is smaller
	BLT A1_Fix_Exp 				;exponent 2 is smaller
	B	EQ_No_Fix_Needed 		;exponents equal
	
A1_Fix_Exp:
	MOV r8, r8, LSR #1			;shift mantissa 
	MOV r11, #0x800000			;set r11 to 'one'
	ADD r6, r6, r11				;add 'one' to exponent 1
	CMP r6,r7					;compare exponents
	BLT A1_Fix_Exp				;jump back to loop
	B EQ_No_Fix_Needed

A2_Fix_Exp:
	MOV r9, r9, LSR #1			; shift p2 mantissa
	MOV r11, #0x800000			;set r11 to 'one'
	ADD r7, r7, r11				;add 'one' to p2 exponent2
	CMP r6,r7					;compare exponents
	BGT A2_Fix_Exp				;jump back to loop
	B EQ_No_Fix_Needed
		
EQ_No_Fix_Needed:
	;;Prepare to add mantissas together
								;before adding, we need to convert negative numbers to twos comp
	LDR r10, =0x80000000		;sign bit
    MOV r1,r10					;r1 is also sign bit 
    AND r11, r5, r10			;r11 has sign #2
    AND r10, r4, r10			;r10 has sign #1
    
    SUB SP, SP, #8 				;push mantissas to stack before negating for later use
    STR r8, [SP,#0]
    STR r9, [SP,#4]             
 
    CMP r10, r1					;if sign 1 negative 
    BEQ A1_negate				;negate input 1
    B A1_Skip					;else skip negating input 1

A1_negate: 
	MVN r8,r8 					;twos complement
	ADD r8, r8, #1
	B A1_Skip

A1_Skip:
	CMP r11, r1					;if sign 2 negative
    BEQ A2_negate				;goto p2_negate
    B A2_Skip					;else skip negating input 2

A2_negate: 
	MVN r9,r9 					;twos complement
	ADD r9, r9, #1
	B A2_Skip

A2_Skip:
	ADD r2, r8, r9    			;add mantissas 
	
	;;check cases that result in negative answer
	;;1: if both are negative
	;;2: if bigger mantissa is negative

    LDR r9, [SP,#4] 			;mantissa 2 (shifted, but not negated)
    LDR r8, [SP,#0] 			;mantissa 1 (shifted, but not negated)
    ADD SP, SP, #8
    MOV r3, #0 					;init sign of answer to positive
    
	CMP r10, r1					;if #1 is negative  
	BEQ CASE_0
								
	CMP r11, r1		 			;elif #2 is negative
	BEQ CASE_1
	
	B GOOD_TO_GO_NEGS			;else
	
CASE_0:	 						;#1 is neg
	CMP r11, r1					;if #2 is also negative
	BEQ UNNEGATE
	
	CMP r8,r9 					;if mantissa #1 is bigger
	BGT UNNEGATE
	
	B GOOD_TO_GO_NEGS 			;else no need to unnegate
	
CASE_1:							;#2 is neg 
	CMP r9,r8 					;check if mantissa #2 is bigger
	BGT UNNEGATE

	B GOOD_TO_GO_NEGS			;if not, no need to unnegate
			
UNNEGATE:
	MVN r2, r2 					;undo twos complement
	ADD r2, r2, #1
	MOV r3, r1 					;negative sign (previously set to positive)
	
	B GOOD_TO_GO_NEGS

GOOD_TO_GO_NEGS:
	;;check if need to normalize answer
    MOV r1, #0x00FFFFFF			;check if needs normalization (more than 24 bits)
    CMP r2, r1
	BGT NORMALIZE1
	MOV r1, #0x00800000 		;check if needs normalization (less than 24 bits)
	CMP r1, r2
	BLT NORMALIZE2
	B NORM_GOOD 				;exactly 24 bits, no need to normalize

NORMALIZE1:
	MOV r2, r2, LSR #1 			;shift mantissa right
	MOV r7, #0x00800000
	ADD r6, r6, r7 				;adjust exponent (add 1)
	
	MOV r7, #0x00FFFFFF 		;check for normalization
    CMP r2, r7
	BGT NORMALIZE1
	B NORM_GOOD

NORMALIZE2:
	MOV r2, r2, LSL #1 			;shift mantissa left
	MOV r7, #0x00800000
	SUB r6, r6, r7 				;adjust exponent (subtract 1)

	CMP r7, r2 					;check if mantissa less than 24 bits
	BLT NORMALIZE2
	B NORM_GOOD

		
NORM_GOOD:
	LDR r7, =0x7F800000			;remove leading 1 from mantissa
	AND r2, r2, r7
	
	ORR r3, r3, r2 				;OR everything together
	ORR r3, r3, r6
	B DONE_ADD

ADD_ZERO:
	;special case: one of the inputs is zero
	;input 1 float is in r4, input 2 float is in r5
	;at least one of them is zero 
	ORR r3, r4, r5
	B DONE_ADD

DONE_ADD:
	LDR r0, =ADD_RESULT
	STR r3, [r0]
		
    ;return
    MOV PC, lr
    
            
;subtraction subroutine
;gets input from INPUT1_FLOAT and INPUT2_FLOAT
;puts output in SUB_RESULT                
_SUB:
    MOV r11, #0
    MOV r10, #0
    MOV r9, #0
    MOV r8, #0
    MOV r7, #0       ;clears registers
    MOV r4, #0
    MOV r5, #0
    MOV r6, #0

	LDR r4, =INPUT1_FLOAT
    LDR r4, [r4]				;r4 = input 1 in ieee754
    
	LDR r5, =INPUT2_FLOAT
    LDR r5, [r5]				;r5 = input 2 in ieee754
    
    CMP r5, r6 					;compare to input 2 to zero
    BEQ SUB_ZERO1 				;specical case 2: second input is zero, eg, input1float - 0
	
	;;negate input 2 to do subtraction
	LDR r0, =0x80000000
	AND r0, r0, r5				;get sign of input 2
	LDR r1, =0x7FFFFFFF 			
	AND r1, r1, r5 				;mask sign off of input 2
	MVN r0, r0 					;negate sign of input 2
	LDR r3, =0x80000000 			
	AND r0, r0, r3 				;prepare new sign
	ORR r5, r0, r1 				;input 2 is negated

    CMP  r4, r6 				;compare input 1 to zero 
    BEQ SUB_ZERO2 				;special case1: first input is zero, eg, 0 - input2float
    

	LDR r7, =0x7F800000  		;used to get exponent 
	AND r6, r4, r7				; r6 has input1's exponent
	AND r7, r5, r7 				; r7 has input2's exponent  
	
	LDR r10, =0x7FFFFF 			;get mantissa 
	AND r8, r10, r4    			;r8 has mantissa 1
	AND r9, r10, r5	   			;r9 has mantissa 2
	
	mov r12, #0x00800000		;give mantissas leading 1s
	ORR r8, r8, r12 
	ORR r9, r9, r12


	;;if exponents are different, we need to make them equal and adjust
	;;the mantissa of the smaller number

	CMP	r6,r7 				
	BGT	S2_Fix_Exp 				;exponent 1 is smaller
	BLT S1_Fix_Exp 				;exponent 2 is smaller 
	B	SEQ_No_Fix_Needed 		;exponents are equal
	
S1_Fix_Exp:
		;P2 > P1
		MOV r8, r8, LSR #1		; shift p1 mantissa
		MOV r11, #0x800000		;set r11 to 'one'
		ADD r6, r6, r11			;add 'one' to p1 exponent
		CMP r6,r7				;compare exponents
		BLT S1_Fix_Exp			;jump back to loop
		B SEQ_No_Fix_Needed

S2_Fix_Exp:
		;P1 > P2
		MOV r9, r9, LSR #1		; shift p2 mantissa
		MOV r11, #0x800000		;set r11 to 'one'
		ADD r7, r7, r11			;add 'one' to p2 exponent
		CMP r6,r7				;compare exponents
		BGT S2_Fix_Exp			;jump back to loop
		B SEQ_No_Fix_Needed
		
SEQ_No_Fix_Needed:
	
	;;prepare to add mantissas together
								;before adding, we need to convert negative numbers to twos comp
	LDR r10, =0x80000000		;sign bit
    MOV r1,r10					;r1 is also sign bit 
    AND r11, r5, r10			;r11 has sign #2
    AND r10, r4, r10			;r10 has sign #1
    
    SUB SP, SP, #8 				;push mantissas to stack before negating for later use
    STR r8, [SP,#0]
    STR r9, [SP,#4]      

    CMP r10, r1 				;is input 1 negative?
    BEQ S1_negate 				;negate input 1
    B S1_Skip 					;skip negating input 1
    
S1_negate: 
	MVN r8,r8 					;twos complement
	ADD r8, r8, #1
	B S1_Skip

S1_Skip:
	CMP r11, r1					;if sign 2 negative
    BEQ S2_negate				;goto s2 negate
    B S2_Skip					;else skip negating input 2

S2_negate: 
	MVN r9,r9 					;twos complemnet
	ADD r9, r9, #1
	B S2_Skip

S2_Skip:
	ADD r2, r8, r9 				;add mantissas    
	
	;;check cases that result in negative answer
	;;1: if both are negative
	;;2: if bigger mantissa is negative

    LDR r9, [SP,#4] 			;mantissa 2 (shifted, but not negated)
    LDR r8, [SP,#0] 			;mantissa 1 (shifted, but not negated)
    ADD SP, SP, #8

    MOV r3, #0					;init sign of answer to zero
	CMP r10, r1					;if #1 is negative
	BEQ SUBCASE_0
	
	CMP r11, r1					;elif #2 is negative
	BEQ SUBCASE_1
	
	B SUBGOOD_TO_GO_NEGS 		;else
	
SUBCASE_0:	 					;#1 is negative
	CMP r11, r1		    		;if #2 is also negative
	BEQ S_UNNEGATE
	
	CMP r8,r9 					;check if mantissa #1 is bigger
	BGT S_UNNEGATE
	
	B SUBGOOD_TO_GO_NEGS 		;else no need to unnegate
	
SUBCASE_1:						;#2 is neg
	CMP r9,r8 					;check if mantissa #2 is bigger
	BGT S_UNNEGATE

	B SUBGOOD_TO_GO_NEGS		;if not, no need to unnegate		
			
S_UNNEGATE:
	MVN r2, r2 					;undo twos comlement
	ADD r2, r2, #1
	MOV r3, r1 					;negative sign, previously set to positive
	
	B SUBGOOD_TO_GO_NEGS

SUBGOOD_TO_GO_NEGS:
	;;check if need to normalize answer
    MOV r1, #0x00FFFFFF 		;check if needs normalization (more than 24 bits)
    CMP r2, r1
	BGT S_NORMALIZE1
	MOV r1, #0x00800000 		;check if needs normalization (less than 24 bits)
	BLT S_NORMALIZE2
	B 	SUBNORM_GOOD 			;exactly 24 bits, no need to normalize

S_NORMALIZE1:
	MOV r2, r2, LSR #1 			;shift mantissa 
	MOV r7, #0x00800000 		;adjust exponent (add 1)
	ADD r6, r6, r7
	
	MOV r7, #0x00FFFFFF			;check for normalization
    CMP r2, r7
	BGT S_NORMALIZE1
	B 	SUBNORM_GOOD

S_NORMALIZE2:
	MOV r2, r2, LSL #1 			;shift mantissa left
	MOV r7, #0x00800000
	SUB r6, r6, r7 				;adjust exponent (subtract 1)

	CMP r7, r2 					;check if mantissa less than 24 bits
	BLT S_NORMALIZE2
	B SUBNORM_GOOD

SUBNORM_GOOD:
	LDR r7, =0x7FFFFF 			;remove leading 1 from mantissa
	AND r2, r2, r7

	ORR r3, r3, r2 				;OR everything together
	ORR r3, r3, r6
	B SUB_DONE

SUB_ZERO2:
	;0 - x
	;negated input 2 is in r5
	MOV r3, r5 
	B SUB_DONE

SUB_ZERO1:
	;x - 0
	;input 1 is in r4
	MOV r3, r4
	B SUB_DONE

SUB_DONE:
	LDR r0, =SUB_RESULT
	STR r3, [r0]
		
    ;return
    MOV PC, lr


;Multiplication subroutine
;input: INPUT1_FLOAT, INPUT2_FLOAT
;output: MUL_RESULT
_MUL:
	;first get two inputs     
	ldr	r0,=INPUT1_FLOAT
	LDR r0,[r0]
	LDR	r1, =INPUT2_FLOAT
	LDR	r1, [r1]
	
	;;get exponents, check if either input is zero
	;;ieee, zero is represented with zero in exponent field
	;;no need to check mantissa for zero because the input is normalized
	
	LDR r3, =0x7F800000	;used to get exponent field
	MOV r4, #0
	
	AND r2, r3, r0			; get exponent 1
	AND r3, r3, r1			; get exponent 2

	CMP r2, r4 				; check if zero
	BEQ MULT_ZERO
	CMP r3, r4 				; check if zero
	BEQ MULT_ZERO

	;;temp use r4 for '127'
	mov r4, #0x3F800000
	
	SUB r2, r2, r4			; get rid of bias on exponent 1
	SUB r3, r3, r4			; get rid of bias on exponent 2		
		
	ADD r2,r2,r3			; add exponents together
	
	;;r4 and r3 empty 
	
	;;get the mantissas
	
	LDR r3, =0x7FFFFF 

	AND r4, r1 , r3	; get mantissa 2
	AND r3, r0 , r3	; get mantissa 1
	
	mov r5, #0x00800000
	ORR r3, r3, r5			;add leading 1 to mantissa 1
	ORR r4, r4, r5			;add leading 1 to mantissa 2


	MOV r6, #0				;result of multiplication will be in r6 and r7
	MOV r7, #0				;r7 extends r6's bits, since the result of 32 bit multiplication takes up to 64 bits
	MOV r8, #1				;added to r7 in case of r6 carrying out
	
	;;multiply		
	
	MOV r5, r4				; r5 (input 2 mantissa) is counter
	B	MULTIPLY_LOOP		; goto multiply loop 
	
MULTIPLY_LOOP: 

	ADCS	r6, r6, r3		;;add and accumulate mantissa 1 in r6, set carry flag if carry out
	ADDCS	r7,r7, r8		;;conditionally add 1 to r7 if carry out set ( carry out from r6 into r7 )
	
	SUB		r5,r5, #1		;; decrement counter 
	
	CMP		r5,#0			;;if r5 > 0
	BGT MULTIPLY_LOOP		;;loop again
	B OUT_OF_LOOPY

OUT_OF_LOOPY:
	;;normalize the result										
	LDR r5, =0x00007FFF		;used to check if more than 15 bits in r7
	
	MOV r8, #1
	EOR r9,r9,r9
							;;result of multiplying two 24 bit numbers will have at least 47 bits (32 bits in r6, 15 bits in r7)
							;;if it has more, it needs to be normalized
	CMP r7, r5				;;check if mantissa has more than 47 bits
	BGT MULT_NORMALIZER
	B MULT_NORMALIZER_DONE

MULT_NORMALIZER:		
	AND r9, r8,r7			; save first bit of r7
	MOV r9, r9, LSL #31		; shift r9 to 32ndth (tm) bit 
	
	mov r7, r7, lsr #1		; shift higher mantissa register to right one position
	mov r6, r6, lsr #1		; shift lower mantissa register to right one position
	
	ADD r6, r6, r9			; put shifted out bit from higher mantissa into lower mantissa

	EOR r9,r9,r9
	MOV r9, #0x800000		; set r9 to 'one', to be added to exponent (exponent is in the middle in ieee)
	
	ADD r2, r2,r9			;add 'one' to exponent
							
	CMP r7, r5				; if r7 > 15 bits
	BGT MULT_NORMALIZER		;do again
							;else
	B MULT_NORMALIZER_DONE	;done normalizing
	;;at this point, mantissa is in r6 and r7, with 15 bits in r7

MULT_NORMALIZER_DONE:		
	;; prepare mantissa for final answer
	MOV r7, r7, LSL #9		;put the 15 most significant mantissa bits in r7 bits 24 - 10
	MOV r6, r6, LSR #23		;put the 9 least significant mantissa bits in r6 bits 9 - 1 
	ORR r6, r6, r7			;or mantissa together, store in r6

	LDR r7, =0x7FFFFF 		;remove leading one from mantissa
	AND r6,r6,r7 			
							
	B 	MULT_GET_THE_SIGN	;go to next step 

MULT_GET_THE_SIGN:
	;;get the sign		
	LDR r8, =0x80000000;	GET_SIGN
	
	;recap
	;r0: input 1
	;r1: input 2
	;r2: has the exponent
	;r6: has the mantissa
	;r3 wil hold the sign

	
	EOR r3,r3,r3			;used for final answer sign
	EOR r4,r4,r4			;used for input 1	sign
	EOR r5,r5,r5			;used for input 2	sign
	
	AND r4, r0, r8			; get input 1 sign bit
	AND r5, r1, r8			; get input 2 sign bit
	
	EOR	r3, r4, r5			; answer positive if signs are same, negative if different
	
	B MULT_ASSEMBLE

MULT_ZERO:
	;;answer is zero, special case
	MOV r3, #0
	MOV r2, #0
	MOV r6, #0

MULT_ASSEMBLE:
	ORR r3, r3, r2			;put the exponent in 
	ORR	r3, r3, r6			;put the mantissa in

;;store answer in memory	
	LDR r4, =MUL_RESULT		;get pointer to result var
	STR	r3, [r4]			;put into memory 

	;return
    MOV PC, lr    

_exit:
    mov     r0, #0      	;status -> 0 
    mov     r7, #1      	;exit is syscall #1 
    swi     0x11        	;invoke syscall exit