STACK_BASE		EQU     8000h

;+
; Interrupts
;-

INTR_MASK       EQU     FFFAh
KEY_0_IMASK     EQU     0001H	
KEY_UP_IMASK    EQU     0008H	
TIMER_IMASK     EQU     8000H	

;+
; Terminal
;

TERM_DATA       EQU     FFFEh
TERM_CURSOR     EQU     FFFCh
TERM_LINES      EQU     45
TERM_COLUMNS    EQU     80
KBD_DATA        EQU     FFFFh
KBD_CONTROL     EQU     FFFDh

;+
; Timer
;-

TIMER_CONTROL   EQU     FFF7H
TIMER_COUNT     EQU     FFF6H
TIMER_START     EQU     1
TIMER_STOP      EQU     0
TIMER_TICKS     EQU     2

;+
; 7 segment displays
;-

PRIMEIRO		EQU     FFF0H
SEGUNDO         EQU     FFF1H
TERCEIRO        EQU     FFF2H
QUARTO          EQU     FFF3H
QUINTO          EQU     FFEEH

; constant to increment the most significant byte
 
INC_MSB         EQU     0100h

; number od columns of game arena

COLS            EQU     80

; cactus constants

COLUMN_HEIGHT   EQU     11 ; CACTUS_LIMIT + 3
CACTUS_LIMIT    EQU     8
CACTUS_CHAR     EQU     219
GROUND_LINE     EQU     1400h
STOP_COLUMN     EQU     1450h

;+
; Dino constants
;-

DINO_COLUMN     EQU     15
DINO_BASE       EQU     130FH	; dino base coordinates
DINO_BASE_LINE  EQU		1300H
DINO_LIMIT      EQU     0A0FH	; jump limit

; dino states
DINO_IDLE       EQU     0
DINO_UP         EQU     1
DINO_DOWN       EQU     -1

; dino characters
DINO_TOP        EQU     31
DINO_BOTTOM     EQU     30

; text messages positions
KEY_0_POS		EQU		0B1DH
GAME_OVER_POS	EQU		0824H


; data segment

                ORIG    0h
 
; game arena              
arena           TAB     COLS

; random seed
seed            WORD    5

; timer ticks
timer_ticks     WORD    0

; dino state and current position
dino_state      TAB     1
dino_position   TAB     1 ; Expresso (MSByte: line, LSByte: column)

; game score

score           TAB     1

; True when Key 0 was pressed - set by the interrupt routine
key_0_pressed	TAB		1


; messages

press_key_0     STR     'PRESS KEY 0 TO START...', 0
game_over       STR     'GAME OVER', 0

; code segment

                ORIG    1000h
 
;+++++++++++++++++++++++++++++++++++++++++++++++++++
; Score utility functions
;---------------------------------------------------
         
;+
; divide_by_10: ...
;-
                
divide_by_10:
                MOV     R3, R0				
                MVI		R2, 10				
	
.divide_1:
                CMP     R1, R2
                BR.C	.divide_2
                SUB     R1, R1, R2
                INC     R3
                BR		.divide_1
.divide_2:
                JMP     R7
                
; display_score: displays the current score

display_score:  
                DEC     R6
                STOR    M[R6], R7
                
                MVI     R1, score
                LOAD    R1, M[R1]
                
                JAL     divide_by_10
                MVI     R2, PRIMEIRO
                STOR    M[R2], R1
                MOV     R1, R3
                
                JAL     divide_by_10
                MVI     R2, SEGUNDO
                STOR    M[R2], R1
                MOV     R1, R3
                
                JAL     divide_by_10
                MVI     R2, TERCEIRO
                STOR    M[R2], R1
                MOV     R1, R3
                
                JAL     divide_by_10
                MVI     R2, QUARTO
                STOR    M[R2], R1
                MOV     R1, R3
                
                JAL     divide_by_10
                MVI     R2, QUINTO
                STOR    M[R2], R1
                
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Basic terminal access functions
;
;------------------------------------------------------------------

;+
; addchar: writes a char at current cursor position
;-
        
addchar:
				MVI     R3, TERM_DATA
                STOR    M[R3], R1
                JMP     R7


;+
; mvaddchar: adds a char at the specified cursor position                
;-
                
mvaddchar:
		  		MVI     R3, TERM_CURSOR
                STOR    M[R3], R1
                MVI     R3, TERM_DATA
                STOR    M[R3], R2
                JMP     R7

;+
; mvaddstr: adds a string at the specified cursor position
;-
               
mvaddstr:
		   		MVI     R3, TERM_CURSOR
                STOR    M[R3], R1
                MVI     R3, TERM_DATA
                
mvaddstr_1:     LOAD    R1, M[R2]
                CMP     R1, R0
                BR.Z    .mvaddstr_ret
                STOR    M[R3], R1
                INC     R2
                BR      mvaddstr_1
                
.mvaddstr_ret:	JMP     R7

;+
; clear_screen: clears the terminal screen
;-

clear_screen:  
                MVI     R1, TERM_CURSOR
                STOR    M[R1], R0
                
                MVI     R3, 3600        ; TERM_LINES * TERM_COLUMS
                MVI     R1, TERM_DATA
                MVI     R2, ' '
                
.clear_scr_1:
                STOR    M[R1], R2        ; addchar(' ')
                DEC     R3
                BR.NZ   .clear_scr_1
                JMP     R7

;==================================================================
;
; Utility functions to unmask and mask interrupt vectors
;
;------------------------------------------------------------------

;+
; unmask_intr: unmasks the specified interrupt vector
;-

unmask_intr:
				MVI		R2, INTR_MASK
				LOAD	R3, M[R2]
				OR		R3, R3, R1
				STOR	M[R2], R3
				JMP		R7

;+
; mask_intr: masks the specified interrupt vector
;-

mask_intr:
				MVI		R2, INTR_MASK
				LOAD	R3, M[R2]
				COM		R1
				AND		R3, R3, R1
				STOR	M[R2], R3
				JMP		R7

;++++++++++++++++++++++++++++++++++++++++++++++++
;
; Utility functions to setup and stop the timer
;
;------------------------------------------------

;+
;  setup_timer: sets up the timer
;-

setup_timer:
				DEC		R6
				STOR	M[R6], R7
				
                MVI		R1, timer_ticks
				STOR	M[R1], R0
				
				MVI		R1, TIMER_COUNT
				MVI		R2, TIMER_TICKS
				STOR	M[R1], R2
				
				MVI		R1, TIMER_CONTROL
				MVI		R2, TIMER_START
				STOR	M[R1], R2
				
; unmask timer interrupt vector 
				MVI		R1, TIMER_IMASK
				JAL		unmask_intr
				
				LOAD	R7, M[R6]
				INC		R6
				JMP		R7
				
; stop_timer: stops the timer and mask its interrupt

stop_timer:
				DEC		R6
				STOR	M[R6], R7
				
				MVI		R1, TIMER_CONTROL
				STOR	M[R1], R0
; mask interrupt
				MVI		R1, TIMER_IMASK
				JAL		mask_intr
				
				LOAD	R7, M[R6]
				INC		R6
				JMP		R7
				
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Interrupt service routines
;
;-------------------------------------------------------------------
			
;+
; timer_isr: timer interrupt service routine
;-

timer_isr:
                DEC		R6
                STOR	M[R6], R1
                DEC		R6
                STOR	M[R6], R2
	
; increment timer_ticks

                MVI		R1, timer_ticks
                LOAD	R2, M[R1]
                INC		R2
                STOR	M[R1], R2
	
; timer restart

                MVI		R1, TIMER_COUNT
                MVI		R2, TIMER_TICKS
                STOR	M[R1], R2
                MVI		R1, TIMER_CONTROL
                MVI		R2, TIMER_START
                STOR	M[R1], R2

                LOAD	R2, M[R6]
                INC		R6
                LOAD	R1, M[R6]
                INC		R6
                JMP		R7

;+
; key_up_isr: ISR for KEY UP interrupt vector
;-

key_up_isr:
				DEC		R6
				STOR	M[R6], R1
				DEC		R6
				STOR	M[R6], R2
				
				MVI		R1, dino_state
				LOAD	R2, M[R1]
				CMP		R2, R0			; ? dino_state == DINO_IDLE
				BR.NZ	.key_up_1
                MVI     R2, DINO_UP
				STOR	M[R1], R2		; dino_state = DINO_UP
				
.key_up_1:      
                LOAD	R2, M[R6]
				INC		R6
				LOAD	R1, M[R6]
				INC		R6
				JMP		R7

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Functions based on interrupts, namely wait_next_tick, wait_key_0 and dino_jump
 ;
;----------------------------------------------------------------------------------
				
;+
; wait_next_tick: waits until the next timer tick
;-
                
wait_next_tick:
				DEC		R6
				STOR	M[R6], R7
				DEC		R6
				STOR	M[R6], R4
				DEC		R6
				STOR	M[R6], R5
							
      		  	MVI     R4, timer_ticks
                LOAD    R5, M[R4]

; wait next timer tick
                
.wait_next_tick_1:
				LOAD    R3, M[R4]
                CMP     R5, R3
                BR.NZ 	.wait_next_tick_ret

; check if a key was pressed at terminal

				MVI		R1, KBD_CONTROL
				LOAD	R2, M[R1]
				CMP		R2, R0
				BR.Z	.wait_next_tick_1
				MVI		R1, KBD_DATA
				LOAD	R1, M[R1]		; consume key

; call dino_jump when a key is pressed
				JAL		dino_jump
				BR		.wait_next_tick_1

.wait_next_tick_ret:
				LOAD	R5, M[R6]
				INC		R6
				LOAD	R4, M[R6]
				INC		R6
				LOAD	R7, M[R6]
				INC		R6
                JMP     R7

;+
; wait_key_0: waits until key 0 is pressed
;-

wait_key_0:
			 
				DEC		R6
				STOR	M[R6], R7
				
				MVI		R1, key_0_pressed	; clear keypressed
				STOR	M[R1], R0

; unmask KEY 0 interrupt vector and ensure interruts are enabled

				MVI		R1, KEY_0_IMASK
				JAL		unmask_intr
				ENI
				
; wait until key_0_pressed is True
				MVI		R1, key_0_pressed

.wait:
				LOAD	R2, M[R1]
				CMP		R2, R0
				BR.Z	.wait
				
; mask KEY 0 interrupt
				MVI		R1, KEY_0_IMASK
				JAL		mask_intr

				LOAD	R7, M[R6]
				INC		R6
                JMP     R7

;+
; dino_jump: called when jump key is pressed. Changes dino state if it is idle.
;-

dino_jump:
	  			MVI     R1, dino_state
                LOAD    R2, M[R1]
                CMP		R2, R0					; ? dino_state == DINO_IDLE
                JMP.NZ  R7			; return if dino not IDLE

; set dino_state = DINO_UP
                MVI     R2, DINO_UP
                STOR    M[R1], R2
                JMP     R7

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Functions of the first part of the project
;
;---------------------------------------------------------------------

; geracato: generates the next cactus
             
geracato:       
;salvaguardar R4
                DEC     R6 
                STOR    M[R6], R4
             
                MVI     R4, seed
                LOAD    R3, M[R4]
;? semente & 1 != 0
                SHR     R3         ;C = semente0, R3 = semente >> 1
                BR.NC   geracato_1
                
                MVI     R2, b400h
                XOR     R3, R3, R2
                
geracato_1:     
;atualizar o novo valor da semente
                STOR    M[R4], R3
                MVI     R2, 62559
                CMP     R3, R2
                BR.NC   geracato_2
                MOV     R3, R0
                BR      geracato_ret
                
geracato_2:     DEC     R1         ; altura = altura - 1
                AND     R3, R3, R1
                INC     R3         ; R3 = (semente & (altura -1)) + 1
                
geracato_ret:
                LOAD    R4, M[R6]
                INC     R6
                JMP     R7

;+
; actualizajogo: ...
;-

atualizajogo:   

                DEC     R6
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                
                MOV     R4, R1
                DEC     R2
                INC     R4
                        
.atualiza_1:    LOAD    R1, M[R4]
                DEC     R4
                STOR    M[R4], R1
                INC     R4
                INC     R4
                DEC     R2
                BR.NZ   .atualiza_1
                
                DEC     R4
                
                MVI     R1, CACTUS_LIMIT
                JAL     geracato
                
                STOR    M[R4], R3
                
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Functions used to display game state
;
;------------------------------------------------------------

;+
; clear_column: clears the specified game column.
;-
                
clear_column:
				DEC     R6
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                
                MVI     R2, GROUND_LINE
                ADD     R1, R1, R2
                MVI     R4, COLUMN_HEIGHT
                MVI     R2, ' '
                
.clear_col_1:   
                JAL     mvaddchar
                MVI     R3, INC_MSB
                SUB     R1, R1, R3
                DEC     R4
                BR.NZ   .clear_col_1
                
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7
 

;+
; show_cactus: show a cactus...
;-
 
show_cactus:
				DEC     R6
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                
                MVI     R3, GROUND_LINE
                ADD     R1, R1, R3
                MOV     R4, R2
                
show_cactus_1:
	  			MVI     R2, CACTUS_CHAR
                JAL     mvaddchar
                MVI     R3, INC_MSB
                SUB     R1, R1, R3
                DEC     R4
                BR.NZ   show_cactus_1
                
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

; clear_dino: clears dino

clear_dino:     
                DEC     R6
                STOR    M[R6], R7
                
                MVI     R1, dino_position
                LOAD    R1, M[R1]
                MVI     R2, ' '
                JAL     mvaddchar		; down char = ' '
                MVI     R3, INC_MSB
                SUB     R1, R1, R3
                MVI     R2, ' '         ; up char = ' '
                JAL     mvaddchar
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;+
; show_normal_dino: displays dino in the normal state
;-

show_normal_dino:
; save R7
                DEC     R6
                STOR    M[R6], R7
                
                MVI     R1, dino_position
                LOAD    R1, M[R1]
                MVI     R2, DINO_TOP
                JAL     mvaddchar
                MVI     R3, INC_MSB
                SUB     R1, R1, R3
                MVI     R2, DINO_BOTTOM
                JAL     mvaddchar

                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;+
; show_dino_collision: display dino in the collision stae (inverts the char order).
;-

show_collision_dino:
                DEC     R6
                STOR    M[R6], R7

                MVI     R1, dino_position
                LOAD    R1, M[R1]
                MVI     R2, DINO_BOTTOM		
                JAL     mvaddchar
                MVI     R3, INC_MSB
                SUB     R1, R1, R3
                MVI     R2, DINO_TOP
                JAL     mvaddchar
                
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7
 
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; State machine that defines dino state: called every tick
;
;------------------------------------------------------------------

;+
; update_dino: updates the dino state
;-

update_dino:
				MVI     R1, dino_state
                LOAD    R2, M[R1]
                CMP		R2, R0
                BR.NZ   .upd_dino_up_down
                
.upd_dino_ret:
				JMP     R7

.upd_dino_up_down:   
                MVI     R1, dino_position
				MVI		R3, INC_MSB
                BR.N    .upd_dino_down			; dino_state == DINO_DOWN
				
.upd_dino_up:
				LOAD    R2, M[R1]
                SUB		R2, R2, R3			; up one line
                STOR    M[R1], R2
                MVI     R3, DINO_LIMIT
                CMP     R2, R3
                BR.NZ	.upd_dino_ret
				
                MVI     R1, dino_state
                MVI     R3, DINO_DOWN
                STOR    M[R1], R3
                JMP     R7
				
.upd_dino_down:
	  			LOAD    R2, M[R1]
                ADD		R2, R2, R3		; down one line
                STOR    M[R1], R2
				MVI		R3, DINO_BASE
				CMP		R2, R3
                BR.NZ   .upd_dino_ret
                MVI     R1, dino_state
                STOR    M[R1], R0		; dino_state = DINO_IDLE
                JMP     R7
                

;+
; check_collision: checks if dino position collides with cactus at dino column.
;-

check_collision:
                MVI     R1, arena
                MVI     R2, DINO_COLUMN
                ADD     R1, R1, R2        ; R1: &arena[DINO_COLUMN]
                LOAD    R1, M[R1]        ; cactus height
                CMP     R1, R0
                MOV     R3, R0

; return False if there is no cactus at column
                JMP.Z   R7

; compute position of cactus top
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1
                SHL     R1        			; R1: (line = cactus height, column = 0)
                MVI     R2, GROUND_LINE
                SUB     R1, R2, R1       	 ; line of cactus top, column = 0
                MVI     R2, dino_position
                LOAD    R2, M[R2]
                MVI     R3, FF00H        		; clear column field
                AND     R2, R2, R3
                CMP     R2, R1        			; ? dino_position > catcus_top_line
                MOV     R3, R0
                JMP.N   R7

; collison detected
                INC     R3
                JMP     R7

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Main game functions: start_game, game_step and stop_game.
;
;-----------------------------------------------------------------------------------

;+
; start_game: starts the game arena ...
;-

start_game:
                DEC     R6
                STOR    M[R6], R7

; clear the screen
                JAL     clear_screen
                
; for i in range(ROWS);
;     arena[i] = 0;

                MVI     R1, arena
                MVI     R2, COLS

.start_1:     
                STOR    M[R1], R0
                INC     R1
                DEC     R2
                BR.NZ   .start_1

; dino_state = DINO_IDLE
; dino_position = DINO_BASE

                MVI     R1, dino_state
                STOR    M[R1], R0        ; dino_state = DINO_IDLE
                MVI     R1, dino_position
                MVI     R3, DINO_BASE
                STOR    M[R1], R3        ; dino_position = DINO_BASE

; clear score
                MVI     R1, score
                STOR    M[R1], R0        ; score = 0
                
; unmask KEY UP interrupt
                MVI     R1, KEY_UP_IMASK
                JAL     unmask_intr

; setup timer
                JAL     setup_timer

; ensure that interrupts are enabled
                ENI
                
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7


;+
; game_step: executes a step of the game - executed at each timer tick.
;-

game_step:
		  		DEC     R6
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5

; update the state of game arena
				MVI		R1, arena
				MVI		R2, COLS
		 	   	JAL		atualizajogo

; clear dino
				JAL		clear_dino

; update the dino position
				JAL		update_dino

;+
; update screen with the new arena and dino states.
;-
                
                MVI     R4, arena
                MVI     R5, GROUND_LINE		; (20, 0)
                
.step_1:
				MOV     R1, R5
                MVI     R3, 00FFh
                AND     R1, R1, R3
                JAL     clear_column
                LOAD    R2, M[R4]
                CMP     R2, R0
                BR.NZ   .show_game_2

; ground char             
                MOV     R1, R5
                MVI     R2, '_'
                JAL     mvaddchar
                BR      .show_game_3
                
                
.show_game_2:
	   			MOV     R1, R5
                MVI     R3, 00FFh
                AND     R1, R1, R3
                JAL     show_cactus
                
.show_game_3:
	   			INC     R4		; increment arena address
                INC     R5		; increment column
                MVI     R3, STOP_COLUMN
                CMP     R5, R3
                BR.NZ   .step_1
				
; check if there is a collision
				JAL		check_collision
				CMP		R3, R0
				BR.Z	.step_4

; show dino for collision case
				JAL		show_collision_dino
				MVI		R3, 1
				BR		.step_ret

.step_4:
; increment score and display it
				MVI		R1, score
				LOAD	R2, M[R1]
				INC		R2
				STOR	M[R1], R2
				JAL		display_score

; show dino in normal state
				JAL		show_normal_dino
				MOV		R3, R0			; return no collision

.step_ret:				
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JAL     R7


;+
; stop_game: stop the game processing. 
;-

stop_game:
                DEC     R6
                STOR    M[R6], R7

; stop the timer
                JAL     stop_timer

; mask KEY UP interrupts

                MVI     R1, KEY_UP_IMASK
                JAL     mask_intr
                
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;==================================================
; Interrupt entry points
;--------------------------------------------------

;+
; Entry point for KEY 0 interrupt vector
;-

                ORIG    7F00H
key_0_isr_entry:
                DEC     R6
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R2
				
                MVI     R1, key_0_pressed        ; key_0_pressed = True
                MVI     R2, 1
                STOR    M[R1], R2
				
                LOAD    R2, M[R6]
                INC     R6
                LOAD    R1, M[R6]
                INC     R6                
                RTI
                
;+
; Entry point for KEY UP interrupt vector
;-
      
                ORIG	7F30H	
key_UP_isr_entry:

                DEC		R6
                STOR	M[R6], R7
                
				JAL		key_up_isr
				
                LOAD	R7, M[R6]
                INC		R6
                RTI

;+
; Entry point for timer interrupt
;-

				ORIG	7FF0H

timer_isr_entry:
				
                DEC		R6
                STOR	M[R6], R7
                
				JAL		timer_isr
				
                LOAD	R7, M[R6]
                INC		R6
                RTI

;+
; Main program
;-
				           
                ORIG    0h

main:           MVI     R6, STACK_BASE
.again:         
                MVI     R1, KEY_0_POS
                MVI     R2, press_key_0
                JAL     mvaddstr
                
                JAL     wait_key_0
                JAL     start_game

.play:        
                JAL     game_step
                CMP     R3, R0
                BR.NZ   .game_over
                JAL     wait_next_tick
                BR      .play
                
.game_over:     
                JAL     stop_game
                MVI     R1, GAME_OVER_POS
                MVI     R2, game_over
                JAL     mvaddstr
                BR      .again