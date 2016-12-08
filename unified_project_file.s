;file for integrating all code
;CMSC411, Russ Cain
;12/8/2016
;Authors: Rommel Trejo Castillo, Tsunsing Leung, Nathaniel Baylon, Krunal Hirpara
;
;Usage: Enter two inputs in dumb format in the INPUT1 and INPUT2 labels. The results are stored in the result labels, and 
; 		At the end of execution of the whole program, all of the results are copied from memory into the registers (see _CHECK_ANS subroutine)

;;memory
.data

	; Some common inputs(for example):
	; 0 = 0x0, 1.0 = 0x00010000, max number = 32767.65535 = 0x7FFFFFFF, +100 = 0x00640000 
	;		  -1.0 = 0x80010000, min number =-32767.65535 = 0xFFFFFFFF, -100 = 0x80640000
	
	;input labels											
	;enter inputs in dumb format here, in hex 		
	INPUT1: .word 0x7FFFFFFF 						
	INPUT2: .word 0x3FFFFFFF


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
    BL _DUMB_TO_IEEE		;convert to float, store in INPUT1_FLOAT and INPUT2_FLOAT
    BL _ADD					;addition, store in ADD_RESULT
    BL _SUB					;subtraction, store in SUB_RESULT
    BL _MUL					;multiplication, store in MUL_RESULT
    BL _BUILT_IN			;built in fops, store in FOP_ADD, FOP_SUB, FOP_MUL
    BL _CHECK_ANS			;move all results from memory to registers to easily check them
    B _exit					;exit


;;subroutines

;converts both dumb format inputs to ieee
;takes input from INPUT1 and INPUT2
;stores results in INPUT1_FLOAT and INPUT2_FLOAT
_DUMB_TO_IEEE:
    SUB SP, SP, #4
    STR LR, [SP,#0] 		;store LR on stack

    LDR r0, =INPUT1 		;get input 1
    LDR r0, [r0]
    BL _GET_FLOAT			;invoke subroutine to convert to float (located below this subroutine)
    LDR r1, =INPUT1_FLOAT	
    STR r0, [r1]			;store in memory

    LDR r0, =INPUT2 		;get input 2
    LDR r0, [r0]
    BL _GET_FLOAT 			;convert to float
    LDR r1, =INPUT2_FLOAT 	;store answer
    STR r0, [r1]

    LDR LR, [SP,#0] 		;restore LR and stack pointer
    ADD SP, SP, #4

    MOV PC, LR 				;return


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

_ADD:
    SUB SP, SP, #4
    STR LR, [SP,#0] 			;store LR on stack
	LDR r0, =INPUT1_FLOAT
	LDR r0, [r0] 				;floating input 1
	LDR r1, =INPUT2_FLOAT
	LDR r1, [r1] 				;floating input 2

	BL _ADD_SUB 				;call subroutine

	LDR r1, =ADD_RESULT
	STR r0, [r1] 				;store result in memory

    LDR LR, [SP,#0] 			;restore LR and stack pointer
    ADD SP, SP, #4

	MOV pc, lr 					;return

_SUB:
    SUB SP, SP, #4
    STR LR, [SP,#0] 			;store LR on stack

	LDR r0, =INPUT1_FLOAT
	LDR r0, [r0] 				;floating input 1
	LDR r1, =INPUT2_FLOAT
	LDR r1, [r1] 				;floating input 2
	CMP r1, #0 					;negate second input if not zero
	BEQ SUB_START
	 							;negate second input
	LDR r2, =0x80000000
	AND r2, r2, r1				;get sign of input 2
	LDR r3, =0x7FFFFFFF 			
	AND r3, r3, r1 				;mask sign off of input 2
	MVN r2, r2 					;negate sign of input 2
	LDR r4, =0x80000000 			
	AND r2, r2, r4 				;prepare new sign
	ORR r1, r2, r3 				;input 2 is negated
	B SUB_START

	SUB_START:
	BL _ADD_SUB 				;call subroutine
	LDR r1, =SUB_RESULT
	STR r0, [r1] 				;store in memory

    LDR LR, [SP,#0] 			;restore LR and stack pointer
    ADD SP, SP, #4
	
	MOV pc, lr 					;return

;addition/subtraction subroutine 
;subtraction is same as addition with negated second input
;gets input from r0 and r1
;puts output in r0
_ADD_SUB:     
    MOV r11, #0
    MOV r10, #0
    MOV r9, #0
    MOV r8, #0
    MOV r7, #0       ;clears registers
    MOV r3, #0
    MOV r4, #0
    MOV r5, #0
    MOV r6, #0
    
    MOV r4, r0
    MOV r5, r1 					;two inputs
   
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
	BGT	A2_Fix_Exp				;exponent 2 is smaller
	BLT A1_Fix_Exp 				;exponent 1 is smaller
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
	;;do the addition
	ADD r2, r8, r9    			;add mantissas 
	CMP r2, #0 					;compare result with zero
	BEQ ADD_ZERO_ANS			;result of adding mantissas is zero: need to make answer ieee zero
	BMI UNNEGATE 				;unnegate answer if negative
	B GOOD_TO_GO_NEGS 			;else dont unnegate
			
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
	BGT NORMALIZE2
	B NORM_GOOD 				;exactly 24 bits, no need to normalize

NORMALIZE1:
	MOV r2, r2, LSR #1 			;shift mantissa right
	MOV r7, #0x00800000
	ADD r6, r6, r7 				;adjust exponent (add 1)
	
	MOV r7, #0x00FFFFFF 		;check if mantisssa more than 24 bits
    CMP r2, r7
	BGT NORMALIZE1
	B NORM_GOOD

NORMALIZE2:
	MOV r2, r2, LSL #1 			;shift mantissa left
	MOV r7, #0x00800000
	SUB r6, r6, r7 				;adjust exponent (subtract 1)

	CMP r7, r2 					;check if mantissa less than 24 bits
	BGT NORMALIZE2
	B NORM_GOOD

NORM_GOOD:
	LDR r7, =0x7FFFFF			;remove leading 1 from mantissa
	AND r2, r2, r7
	
	ORR r3, r3, r2 				;OR everything together
	ORR r3, r3, r6
	B DONE_ADD

ADD_ZERO:
	;special case: one of the inputs is zero
	;input 1 is in r4, input 2 is in r5
	;at least one of them is zero 
	ORR r3, r4, r5
	B DONE_ADD

ADD_ZERO_ANS:
	;answer is zero
	MOV r3, #0
	B DONE_ADD

DONE_ADD:
	MOV r0, r3
    MOV PC, lr 					;return
    
            
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
	ADD r2, r2, r4 			; give bias back
	
	;;r4 and r3 empty 
	
	;;get the mantissas
	
	LDR r3, =0x7FFFFF 

	AND r4, r1 , r3	; get mantissa 2
	AND r3, r0 , r3	; get mantissa 1
	
	mov r5, #0x00800000
	ORR r3, r3, r5			;add leading 1 to mantissa 1
	ORR r4, r4, r5			;add leading 1 to mantissa 2


	MOV r6, #0				;result of multiplication will be in r6
	MOV r7, #0				
	MOV r8, #1				
	
	;;multiply
	
	MOV r5, r4				; r5 (input 2 mantissa)
	B	MULTIPLY_LOOP		; goto multiply loop 
	
	;mant 1 is in r3
	;mant 2 is r5
	;keep ans in r6

MULTIPLY_LOOP: 
	MOV r7, #1
	AND r7, r7, r5 			;get last bit of second number
	CMP r7, #1
	BNE MULT_CONT
	ADD r6, r6, r3 			;add first number to accumulated sum if 1
	B MULT_CONT
MULT_CONT:
	MOV r5, r5, LSR #1 		;shift second number right
	CMP r5, #0 				;check if zero 
	BEQ OUT_OF_LOOPY
	MOV r6, r6, LSR #1 		;shift answer right if not done
	B MULTIPLY_LOOP

OUT_OF_LOOPY:
	;;normalize the result										
	LDR r5, =0x00FFFFFF		;used to check if more than 24 bits in result
	MOV r8, #1
	MOV r9, #0x800000
	CMP r6, r5
	BGT MULT_NORMALIZER
	B MULT_NORMALIZER_DONE

MULT_NORMALIZER:		
	;shift right 1	
	MOV r6, r6, lsr #1		; shift ansright
	ADD r2, r2, r9			;add 'one' to exponent
	CMP r6, r5				; if r6 > 24 bits
	BGT MULT_NORMALIZER		;do again
							;else
	B MULT_NORMALIZER_DONE	;done normalizing
	;;at this point, mantissa is in r6 and r7, with 15 bits in r7

MULT_NORMALIZER_DONE:		
	;; prepare mantissa for final answer
	LDR r7, =0x7FFFFF 		;remove leading one from mantissa
	AND r6,r6,r7					
	B 	MULT_GET_THE_SIGN	;go to next step 

MULT_GET_THE_SIGN:
	LDR r8, =0x80000000 	;used to get the sign
	AND r4, r0, r8			; get input 1 sign bit
	AND r5, r1, r8			; get input 2 sign bit
	EOR	r3, r4, r5			; answer positive if signs are same, negative if different
	
	B MULT_ASSEMBLE 		; assemble parts of answer

MULT_ASSEMBLE:
	ORR r3, r3, r2			;or sign and exponent together
	ORR	r3, r3, r6			;put the mantissa in
	B MULT_DONE

MULT_ZERO:
	MOV r3, #0 				;answer is zero, special case

MULT_DONE:
	LDR r4, =MUL_RESULT		
	STR	r3, [r4]			;put answer into memory 
    MOV PC, lr    			;return

;;do built in floating point operations
;;input: INPUT1_FLOAT, INPUT2_FLOAT
;;output: stores answers in FOP_MUL, FOP_ADD, FOP_SUB
_BUILT_IN:
	LDR r0, =INPUT1_FLOAT 	;get inputs
	LDR r0,[r0]
	LDR r1, =INPUT2_FLOAT
	LDR r1, [r1]
	
	FMSR s0, r0 			;transfer over to floating point registers
	FMSR s1, r1
	
	FADDS s2, s0, s1 		;add
	FSUBS s3, s0, s1 		;subtract
	FMULS s4, s0, s1 		;multiply
	
	FMRS r2, s2 			;transfer back to regular registers
	FMRS r3, s3
	FMRS r4, s4

	LDR r5, =FOP_ADD 		;store in memory
	STR r2, [r5]
	LDR r5, =FOP_SUB
	STR r3, [r5]
	LDR r5, =FOP_MUL
	STR r4, [r5]

	MOV pc, lr 				;return

;;move results to registers to check them
_CHECK_ANS:
	LDR r0, =INPUT1 		;original input 1
	LDR r0, [r0] 
	LDR r1, =INPUT2 		;original input 2
	LDR r1, [r1]
	LDR r2, =INPUT1_FLOAT 	;converted input 1
	LDR r2, [r2]
	LDR r3, =INPUT2_FLOAT 	;converrted input 2
	LDR r3, [r3]
	LDR r4, =ADD_RESULT 	;result of our add
	LDR r4, [r4]
	LDR r5, =FOP_ADD 		;result of built in add
	LDR r5, [r5]
	LDR r6, =SUB_RESULT 	;result of our sub
	LDR r6, [r6]
	LDR r7, =FOP_SUB 		;result of built in sub
	LDR r7, [r7]
	LDR r8, =MUL_RESULT 	;result of our mul
	LDR r8, [r8]
	LDR r9, =FOP_MUL 		;result of built in mul
	LDR r9, [r9]

	MOV pc, lr 				;return

;;exit program 
_exit:
    swi     0x11        	;invoke syscall exit