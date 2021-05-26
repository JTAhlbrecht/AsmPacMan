%include "/usr/local/share/csc314/asm_io.inc"
;/home/jordan.ahlbrecht/assemblyLanguage/final/game

; the file that stores the initial state
%define BOARD_FILE 'board.txt'
%define STUFF_FILE 'stuff.txt'

; how to represent everything
%define WALL_CHAR '#'
%define PLAYER_CHAR '@'
%define PLAYERL_CHAR '>'
%define PLAYERR_CHAR '<'
%define	PLAYERU_CHAR 'V'
%define PLAYERD_CHAR '^'
%define GATE_CHAR '-'
%define GHOST1_CHAR 'R'
%define GHOST2_CHAR 'P'
%define GHOST3_CHAR 'G'
%define GHOST4_CHAR 'T'
%define TICK 38462

; the size of the game screen in characters
%define HEIGHT 31
%define WIDTH 28

; the player starting position.
; top left is considered (0,0)
%define STARTX 14
%define STARTY 23
%define INT_MAX 2147483647

; these keys do things
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'

segment .data

	; used to fopen() the board file defined above
	board_file			db BOARD_FILE,0
	stuff_file			db STUFF_FILE,0

	; Set initial score
	score				dd	0

	; Dots remaining
	dots				dd	244

	; Power Pellet Timer
	pTimer				dd	0

	; Move timers
	pMovTim				dd	0
	g1MovTim			dd	0
	g2MovTim			dd	0
	g3MovTim			dd	0
	g4MovTim			dd	0

	; Set phase
	phase				dd	1 ; 0=chase, 1=scatter
	phaseTime			dd	182 ; Chase=520(20s) Scatter=182(7s)

	; Power Mode stats
	gEaten				dd	0
	eatScore			dd	200

	; used to change the terminal mode
	mode_r				db "r",0
	raw_mode_on_cmd		db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0

	; called by system() to clear/refresh the screen
	clear_screen_cmd	db "clear",0

	; things the program will print
	help_str			db 13,10,"Controls: ", \
							UPCHAR,"=UP / ", \
							LEFTCHAR,"=LEFT / ", \
							DOWNCHAR,"=DOWN / ", \
							RIGHTCHAR,"=RIGHT / ", \
							EXITCHAR,"=EXIT", \
							13,10,10,0

	score_str			db "SCORE: %d",10,13,0

	end_str				db "GAME OVER",10,13,"FINAL SCORE: %d",10,10,13,0

	; colors
	C_RED				db	0x1b,"[31m",0
	C_YEL				db	0x1b,"[33m",0
	C_PINK				db	0x1b,"[95m",0
	C_TUR				db	0x1b,"[96m",0
	C_GRN				db	0x1b,"[32m",0
	C_LBLU				db	0x1b,"[94m",0

	B_BLU				db	0x1b,"[44m",0

	A_BLINK				db	0x1b,"[5m",0
	A_BOLD				db	0x1b,"[1m",0

	C_DEF				db	0x1b,"[39m",0
	B_DEF				db	0x1b,"[49m",0
	A_DEF				db	0x1b,"[0m",0

segment .bss

	; this array stores the current rendered gameboard (HxW)
	board	resb	(HEIGHT * WIDTH)

	;An array for the dots/pellets/fruit
	stuff	resb	(HEIGHT * WIDTH)

	; these variables store the current player/ghost positions and directions
	xpos	resd	1
	ypos	resd	1
	g1X		resd	1
	g1Y		resd	1
	g1XTar	resd	1
	g1YTar	resd	1
	g1State	resd	1 ; 0=chase, 1=scatter, 2=run, 3=eaten
	g2X		resd	1
	g2Y		resd	1
	g2XTar	resd	1
	g2YTar	resd	1
	g2State	resd	1 ; 0=chase, 1=scatter, 2=run, 3=eaten
	g3X		resd	1
	g3Y		resd	1
	g3XTar	resd	1
	g3YTar	resd	1
	g3State	resd	1 ; 0=chase, 1=scatter, 2=run, 3=eaten
	g4X		resd	1
	g4Y		resd	1
	g4XTar	resd	1
	g4YTar	resd	1
	g4State	resd	1 ; 0=chase, 1=scatter, 2=run, 3=eaten
	playDir	resd	1
	g1Dir	resd	1
	g2Dir	resd	1
	g3Dir	resd	1
	g4Dir	resd	1
	g1TarDist	resd	1
	g1NewDir	resd	1
	g2TarDist	resd	1
	g2NewDir	resd	1
	g3TarDist	resd	1
	g3NewDir	resd	1
	g4TarDist	resd	1
	g4NewDir	resd	1
	dir0Val		resd	1
	dir1Val		resd	1
	dir2Val		resd	1
	dir3Val		resd	1

segment .text

	global	asm_main
	global  raw_mode_on
	global  raw_mode_off
	global  init_board
	global  render

	extern	system
	extern	putchar
	extern	getchar
	extern	fcntl
	extern	printf
	extern	fopen
	extern	fread
	extern	fgetc
	extern	fclose
	extern	usleep
	extern	rand
	extern	time
	extern	srand

asm_main:
	enter	0,0
	pusha
	;***************CODE STARTS HERE***************************

	; put the terminal in raw mode so the game works nicely
	call	raw_mode_on

	; read the game board file into the global variable
	call	init_board
	call	init_stuff

	; seed random
	push 0
	call time
	add esp, 4
	push eax
	call srand
	add esp, 4

	; set the player/ghosts at the proper start positions
	mov		DWORD [xpos], STARTX
	mov		DWORD [ypos], STARTY
	mov		DWORD[playDir], 3
	mov 	DWORD[g1X], 13
	mov		DWORD[g1Y], 12
	mov		DWORD[g1Dir], 0
	mov		DWORD[g1State], 1
	mov		DWORD[g2X], 13
	mov		DWORD[g2Y], 12
	mov		DWORD[g2Dir], 0
	mov		DWORD[g2State], 1
	mov		DWORD[g3X], 14
	mov		DWORD[g3Y], 12
	mov		DWORD[g3Dir], 0
	mov		DWORD[g3State], 1
	mov		DWORD[g4X], 14
	mov		DWORD[g4Y], 12
	mov		DWORD[g4Dir], 0
	mov		DWORD[g4State], 1

	; the game happens in this loop
	; the steps are...
	;   1. render (draw) the current board
	;   2. get a character from the user
	;	3. store current xpos,ypos in esi,edi
	;	4. update xpos,ypos based on character from user
	;	5. check what's in the buffer (board) at new xpos,ypos
	;	6. if it's a wall, reset xpos,ypos to saved esi,edi
	;	7. otherwise, just continue! (xpos,ypos are ok)
	game_loop:

		; draw the game board
		call	render

		; get an action from the user
		call	nonblocking_getchar

		; store the current position
		; we will test if the new position is legal
		; if not, we will restore these
		mov		esi, [xpos]
		mov		edi, [ypos]

		cmp		al, -1
		jne		got_char
			jmp		input_end

		got_char:
		; choose what to do
		cmp		eax, EXITCHAR
		je		game_loop_end
		cmp		eax, UPCHAR
		je 		move_up
		cmp		eax, LEFTCHAR
		je		move_left
		cmp		eax, DOWNCHAR
		je		move_down
		cmp		eax, RIGHTCHAR
		je		move_right
		jmp		input_end			; or just do nothing

		; Change the player direction according to the input character
		move_up:
			mov		DWORD[playDir], 0
			jmp		input_end
		move_left:
			mov		DWORD[playDir], 3
			jmp		input_end
		move_down:
			mov		DWORD[playDir], 2
			jmp		input_end
		move_right:
			mov		DWORD[playDir], 1
		input_end:

		; Check if the player move timer is set and move if so
		cmp DWORD[pMovTim], 3
		jne	end_player_move
			mov DWORD[pMovTim], -1
		; Move the character
		cmp DWORD[playDir], 0
		jne r_move
			dec		DWORD[ypos]
			jmp end_move
		r_move:
		cmp DWORD[playDir], 1
		jne d_move
			;Check for Rteleport
			cmp		DWORD[xpos], 27
			jne		noTele1
				mov DWORD[xpos], 0
			noTele1:
			inc		DWORD[xpos]
			jmp end_move
		d_move:
		cmp DWORD[playDir], 2
		jne l_move
			inc		DWORD[ypos]
			jmp end_move
		l_move:
			;Check for Lteleport
			cmp		DWORD[xpos], 0
			jne		noTele2
				mov DWORD[xpos], 27
			noTele2:
			dec		DWORD[xpos]
		end_move:

		; (W * y) + x = pos

		; compare the current position to the wall character
		mov		eax, WIDTH
		mul		DWORD [ypos]
		add		eax, [xpos]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		gateCheck
			; oops, that was an invalid move, reset
			mov		DWORD [xpos], esi
			mov		DWORD [ypos], edi
		gateCheck:
		cmp BYTE[eax], GATE_CHAR
		jne valid_move
			; oops, that was an invalid move, reset
			mov		DWORD [xpos], esi
			mov		DWORD [ypos], edi
		valid_move:
		; Check for ghosts
		mov eax, DWORD[g1X]
		cmp DWORD[xpos],eax
		jne g2_check
			mov eax, DWORD[g1Y]
			cmp DWORD[ypos], eax
			jne g2_check
				cmp DWORD[g1State], 2
				jne g1_eaten_check
					mov	DWORD[g1State], 3
					mov ebx, DWORD[eatScore]
					add	DWORD[score], ebx
					mov eax, DWORD[eatScore]
					mov ebx, 2
					cdq
					imul ebx
					mov DWORD[eatScore], eax
					inc DWORD[gEaten]
					jmp g2_check
				g1_eaten_check:
				cmp DWORD[g1State], 3
				jne	game_loop_end
					jmp	g2_check
		g2_check:
		mov eax, DWORD[g2X]
		cmp DWORD[xpos],eax
		jne g3_check
			mov eax, DWORD[g2Y]
			cmp DWORD[ypos], eax
			jne g3_check
				cmp DWORD[g2State], 2
				jne g2_eaten_check
					mov	DWORD[g2State], 3
					mov ebx, DWORD[eatScore]
					add	DWORD[score], ebx
					mov eax, DWORD[eatScore]
					mov ebx, 2
					cdq
					imul ebx
					mov DWORD[eatScore], eax
					inc DWORD[gEaten]
					jmp g3_check
				g2_eaten_check:
				cmp	DWORD[g2State], 3
				jne	game_loop_end
					jmp	g3_check
		g3_check:
		mov eax, DWORD[g3X]
		cmp DWORD[xpos],eax
		jne g4_check
			mov eax, DWORD[g3Y]
			cmp DWORD[ypos], eax
			jne g4_check
				cmp DWORD[g3State], 2
				jne g3_eaten_check
					mov DWORD[g3State], 3
					mov ebx, DWORD[eatScore]
					add	DWORD[score], ebx
					mov eax, DWORD[eatScore]
					mov ebx, 2
					cdq
					imul ebx
					mov DWORD[eatScore], eax
					inc DWORD[gEaten]
					jmp g4_check
				g3_eaten_check:
				cmp	DWORD[g3State], 3
				jne	game_loop_end
					jmp	g4_check
		g4_check:
		mov eax, DWORD[g4X]
		cmp DWORD[xpos],eax
		jne endg_check
			mov eax, DWORD[g4Y]
			cmp DWORD[ypos], eax
			jne endg_check
				cmp DWORD[g4State], 2
				jne g4_eaten_check
					mov DWORD[g4State], 3
					mov ebx, DWORD[eatScore]
					add	DWORD[score], ebx
					mov eax, DWORD[eatScore]
					mov ebx, 2
					cdq
					imul ebx
					mov DWORD[eatScore], eax
					inc DWORD[gEaten]
					jmp endg_check
				g4_eaten_check:
				cmp	DWORD[g4State], 3
				jne	game_loop_end
		endg_check:

		; Check for dots/pellet/fruit
		mov		eax, WIDTH
		mul		DWORD [ypos]
		add		eax, [xpos]
		lea		eax, [stuff + eax]
		cmp		BYTE[eax], '.'
		jne		p_check
			add		DWORD[score], 10
			dec		DWORD[dots]
			mov		BYTE[eax], ' '
			jmp end_player_move
		p_check:
		cmp BYTE[eax], 'O'
		jne end_player_move
			add		DWORD[score], 50
			dec		DWORD[dots]
			mov		BYTE[eax], ' '
			mov		DWORD[pTimer], 208
			mov		DWORD[g1State], 2
			add		DWORD[g1Dir], 2
			cmp		DWORD[g1Dir], 4
			jl		g2Pel
				sub DWORD[g1Dir], 4
			g2Pel:
			mov		DWORD[g2State], 2
			add		DWORD[g2Dir], 2
			cmp		DWORD[g2Dir], 4
			jl		g3Pel
				sub	DWORD[g2Dir], 4
			g3Pel:
			mov		DWORD[g3State], 2
			add		DWORD[g3Dir], 2
			cmp		DWORD[g3Dir], 4
			jl		g4Pel
				sub DWORD[g3Dir], 4
			g4Pel:
			mov		DWORD[g4State], 2
			add		DWORD[g4Dir], 2
			cmp		DWORD[g4Dir], 4
			jl		end_player_move
				sub	DWORD[g4Dir], 4
		end_player_move:

	; Move the ghosts

	; Ghost 1
	mov DWORD[dir0Val], 1
	mov DWORD[dir1Val], 1
	mov DWORD[dir2Val], 1
	mov DWORD[dir3Val], 1

	; See if you need to leave the eaten state
	cmp	DWORD[g1State], 3
	jne	notEaten1
		cmp	DWORD[g1X], 13
		jne	notEaten1
			cmp	DWORD[g1Y], 11
			jne	notEaten1
				; If you're eaten and at spawn, switch to current phase
				cmp	DWORD[phase], 0
				jne	g1PhaseUpdateSc
					mov DWORD[g1State], 0
					jmp	notEaten1
				g1PhaseUpdateSc:
				mov	DWORD[g1State], 1
	notEaten1:

	; See if move timer is valid to move
	cmp	DWORD[g1State], 3	; Eaten ghosts move 13 dots a second
	jne	g1FMovC
		cmp	DWORD[g1MovTim], 2
		jne ghost2MoveStart
			mov	DWORD[g1MovTim], -1
			jmp g1MovTimEnd
	g1FMovC:
	cmp	DWORD[g1State], 2	; Frightened gosts move about 6 dots a second
	jne	g1NMovC
		cmp	DWORD[g1MovTim], 4
		jne	ghost2MoveStart
			mov	DWORD[g1MovTim], -1
			jmp	g1MovTimEnd
	g1NMovC:
	cmp	DWORD[g1MovTim], 3 	; Ghosts normally move about 7 dots a second
	jne	ghost2MoveStart
		mov	DWORD[g1MovTim], -1

	g1MovTimEnd:
	; Find out which directions are valid
	cmp DWORD[g1Dir], 0 ; Moving Up?
	jne dir1_1
		mov DWORD[dir2Val], 0
	dir1_1:
	cmp DWORD[g1Dir], 1 ; Moving Right?
	jne	dir1_2
		mov DWORD[dir3Val], 0
	dir1_2:
	cmp DWORD[g1Dir], 2 ; Moving Down?
	jne	dir1_3
		mov DWORD[dir0Val], 0
	dir1_3:
	cmp DWORD[g1Dir], 3 ; Moving Left?
	jne	g1WallCheck
		mov	DWORD[dir1Val], 0

	g1WallCheck:
	; Check Up
	cmp		DWORD[dir0Val], 0
	je		rWallC1
		mov		eax, WIDTH
		mov		ebx, DWORD[g1Y]
		dec		ebx
		mul		ebx
		add		eax, [g1X]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		rWallC1
			mov DWORD[dir0Val], 0
	rWallC1:
	cmp		DWORD[dir1Val], 0
	je		dWallC1
		; Check for Rteleport
		cmp		DWORD[g1X], 27
		jne		g1NoTele1
			jmp	dWallC1
		g1NoTele1:
		mov		eax, WIDTH
		mul		DWORD[g1Y]
		; I DUNNO IF THIS WILL WORK
		inc		DWORD[g1X]
		add		eax, [g1X]
		dec		DWORD[g1X]
		; END OF I DUNNO IF THIS WILL WORK
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		dWallC1
			mov DWORD[dir1Val], 0
	dWallC1:
	cmp		DWORD[dir2Val], 0
	je		lWallC1
		mov		eax, WIDTH
		mov		ebx, DWORD[g1Y]
		inc		ebx
		mul		ebx
		add		eax, [g1X]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		lWallC1
			mov DWORD[dir2Val], 0
	lWallC1:
	cmp		DWORD[dir3Val], 0
	je		g1StateCheck
		; Check for lTeleport
		cmp		DWORD[g1X], 0
		jne		g1NoTele2
			jmp	g1StateCheck
		g1NoTele2:
		mov		eax, WIDTH
		mul		DWORD[g1Y]
		; I DUNNO IF THIS WILL WORK
		dec		DWORD[g1X]
		add		eax, [g1X]
		inc		DWORD[g1X]
		; END OF I DUNNO IF THIS WILL WORK
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		g1StateCheck
			mov DWORD[dir3Val], 0

	; Get a target if possible
	g1StateCheck:
	cmp DWORD[g1State], 3 ; Eaten?
	jne scCheck1
		mov DWORD[g1XTar], 13
		mov DWORD[g1YTar], 11
		jmp newDir1
	scCheck1:
	cmp DWORD[g1State], 1 ; Scatter?
	jne	chCheck1
		mov DWORD[g1XTar], WIDTH
		mov DWORD[g1YTar], 0
		jmp newDir1
	chCheck1:
	cmp	DWORD[g1State], 0 ; Chasing?
	jne newDir1
		mov eax, DWORD[xpos]
		mov DWORD[g1XTar], eax
		mov eax, DWORD[ypos]
		mov DWORD[g1YTar], eax

	; Figure out the direction to move based on distance to tar and/or state
	newDir1:
	cmp DWORD[g1State], 2 ; If you're running, just pick a random valid direction
	jne newDir1_2
		newDir1_1:
		call rand
		cdq
		mov ebx, 4
		idiv ebx
		cmp edx, 0 ;Up
		jne newDir1_1r
			cmp	DWORD[dir0Val], 0
			je newDir1_1
				mov DWORD[g1NewDir], 0
				jmp g1Move
		newDir1_1r:
		cmp	edx, 1
		jne	newDir1_1d
			cmp	DWORD[dir1Val], 0
			je newDir1_1
				mov DWORD[g1NewDir], 1
				jmp g1Move
		newDir1_1d:
		cmp edx, 2
		jne	newDir1_1l
			cmp	DWORD[dir2Val], 0
			je newDir1_1
				mov DWORD[g1NewDir], 2
				jmp g1Move
		newDir1_1l:
		cmp DWORD[dir3Val], 0
		je	newDir1_1
			mov DWORD[g1NewDir], 3
			jmp g1Move

	; If you're not running, find out which valid direction is closest to target
	newDir1_2:
	; Default to gigantic distance to target
	mov DWORD[g1TarDist], INT_MAX

	; Priority is U,L,D,R so check in reverse and replace ties with current value
	cmp DWORD[dir1Val], 0
	je newDir1_2d
		mov eax, DWORD[g1X]
		inc eax
		sub eax, DWORD[g1XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g1Y]
		sub eax, DWORD[g1YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g1TarDist]
		jg	newDir1_2d
			mov DWORD[g1NewDir], 1
			mov DWORD[g1TarDist], eax
	newDir1_2d:
	cmp DWORD[dir2Val], 0
	je newDir1_2l
		mov eax, DWORD[g1X]
		sub eax, DWORD[g1XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g1Y]
		inc	eax
		sub eax, DWORD[g1YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g1TarDist]
		jg	newDir1_2l
			mov DWORD[g1NewDir], 2
			mov DWORD[g1TarDist], eax
	newDir1_2l:
	cmp DWORD[dir3Val], 0
	je newDir1_2u
		mov eax, DWORD[g1X]
		dec eax
		sub eax, DWORD[g1XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g1Y]
		sub eax, DWORD[g1YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g1TarDist]
		jg	newDir1_2u
			mov DWORD[g1NewDir], 3
			mov DWORD[g1TarDist], eax
	newDir1_2u:
	cmp DWORD[dir0Val], 0
	je g1Move
		mov eax, DWORD[g1X]
		sub eax, DWORD[g1XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g1Y]
		dec	eax
		sub eax, DWORD[g1YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g1TarDist]
		jg	g1Move
			mov DWORD[g1NewDir], 0

	; Move in the new direction found above
	g1Move:
	cmp DWORD[g1NewDir], 0
	jne g1MoveR
		dec DWORD[g1Y]
		mov DWORD[g1Dir], 0
		jmp ghost2MoveStart
	g1MoveR:
	cmp DWORD[g1NewDir], 1
	jne g1MoveD
		; Check for Rteleport
		cmp	DWORD[g1X], 27
		jne	g1NoTele3
			mov	DWORD[g1X], 0
			mov	DWORD[g1Dir], 1
			jmp	ghost2MoveStart
		g1NoTele3:
		inc DWORD[g1X]
		mov DWORD[g1Dir], 1
		jmp ghost2MoveStart
	g1MoveD:
	cmp DWORD[g1NewDir], 2
	jne g1MoveL
		inc DWORD[g1Y]
		mov DWORD[g1Dir], 2
		jmp ghost2MoveStart
	g1MoveL:
	; Check for Lteleport
	cmp	DWORD[g1X], 0
	jne	g1NoTele4
		mov	DWORD[g1X], 27
		mov	DWORD[g1Dir], 3
		jmp	ghost2MoveStart
	g1NoTele4:
	dec DWORD[g1X]
	mov DWORD[g1Dir], 3

	ghost2MoveStart:
	; Ghost 2
	mov DWORD[dir0Val], 1
	mov DWORD[dir1Val], 1
	mov DWORD[dir2Val], 1
	mov DWORD[dir3Val], 1

	; See if you need to leave the eaten state
	cmp	DWORD[g2State], 3
	jne	notEaten2
		cmp	DWORD[g2X], 13
		jne	notEaten2
			cmp	DWORD[g2Y], 11
			jne	notEaten2
				; If you're eaten and at spawn, switch to current phase
				cmp	DWORD[phase], 0
				jne	g2PhaseUpdateSc
					mov DWORD[g2State], 0
					jmp	notEaten2
				g2PhaseUpdateSc:
				mov	DWORD[g2State], 1
	notEaten2:

	; See if move timer is valid to move
	cmp	DWORD[g2State], 3	; Eaten ghosts move 13 dots a second
	jne	g2FMovC
		cmp	DWORD[g2MovTim], 2
		jne ghost3MoveStart
			mov	DWORD[g2MovTim], -1
			jmp g2MovTimEnd
	g2FMovC:
	cmp	DWORD[g2State], 2	; Frightened gosts move about 6 dots a second
	jne	g2NMovC
		cmp	DWORD[g2MovTim], 4
		jne	ghost3MoveStart
			mov	DWORD[g2MovTim], -1
			jmp	g2MovTimEnd
	g2NMovC:
	cmp	DWORD[g2MovTim], 3 	; Ghosts normally move about 7 dots a second
	jne	ghost3MoveStart
		mov	DWORD[g2MovTim], -1

	g2MovTimEnd:
	; Find out which directions are valid
	cmp DWORD[g2Dir], 0 ; Moving Up?
	jne dir2_1
		mov DWORD[dir2Val], 0
	dir2_1:
	cmp DWORD[g2Dir], 1 ; Moving Right?
	jne	dir2_2
		mov DWORD[dir3Val], 0
	dir2_2:
	cmp DWORD[g2Dir], 2 ; Moving Down?
	jne	dir2_3
		mov DWORD[dir0Val], 0
	dir2_3:
	cmp DWORD[g2Dir], 3 ; Moving Left?
	jne	g2WallCheck
		mov	DWORD[dir1Val], 0

	g2WallCheck:
	; Check Up
	cmp		DWORD[dir0Val], 0
	je		rWallC2
		mov		eax, WIDTH
		mov		ebx, DWORD[g2Y]
		dec		ebx
		mul		ebx
		add		eax, [g2X]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		rWallC2
			mov DWORD[dir0Val], 0
	rWallC2:
	cmp		DWORD[dir1Val], 0
	je		dWallC2
		; Check for Rteleport
		cmp		DWORD[g2X], 27
		jne		g2NoTele1
			jmp	dWallC2
		g2NoTele1:
		mov		eax, WIDTH
		mul		DWORD[g2Y]
		; I DUNNO IF THIS WILL WORK
		inc		DWORD[g2X]
		add		eax, [g2X]
		dec		DWORD[g2X]
		; END OF I DUNNO IF THIS WILL WORK
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		dWallC2
			mov DWORD[dir1Val], 0
	dWallC2:
	cmp		DWORD[dir2Val], 0
	je		lWallC2
		mov		eax, WIDTH
		mov		ebx, DWORD[g2Y]
		inc		ebx
		mul		ebx
		add		eax, [g2X]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		lWallC2
			mov DWORD[dir2Val], 0
	lWallC2:
	cmp		DWORD[dir3Val], 0
	je		g2StateCheck
		; Check for lTeleport
		cmp		DWORD[g2X], 0
		jne		g2NoTele2
			jmp	g2StateCheck
		g2NoTele2:
		mov		eax, WIDTH
		mul		DWORD[g2Y]
		; I DUNNO IF THIS WILL WORK
		dec		DWORD[g2X]
		add		eax, [g2X]
		inc		DWORD[g2X]
		; END OF I DUNNO IF THIS WILL WORK
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		g2StateCheck
			mov DWORD[dir3Val], 0

	; Get a target if possible
	g2StateCheck:
	cmp DWORD[g2State], 3 ; Eaten?
	jne scCheck2
		mov DWORD[g2XTar], 13
		mov DWORD[g2YTar], 11
		jmp newDir2
	scCheck2:
	cmp DWORD[g2State], 1 ; Scatter?
	jne	chCheck2
		mov DWORD[g2XTar], 0
		mov DWORD[g2YTar], 0
		jmp newDir2
	chCheck2:
	cmp	DWORD[g2State], 0 ; Chasing?
	jne newDir2
		mov eax, DWORD[xpos]
		mov DWORD[g2XTar], eax
		mov eax, DWORD[ypos]
		mov DWORD[g2YTar], eax
		cmp	DWORD[playDir], 0
		jne	g2TarCheck2
			sub	DWORD[g2XTar], 4
			sub	DWORD[g2YTar], 4
			jmp	newDir2
		g2TarCheck2:
		cmp	DWORD[playDir], 1
		jne	g2TarCheck3
			add	DWORD[g2XTar], 4
			jmp	newDir2
		g2TarCheck3:
		cmp	DWORD[playDir], 2
		jne	g2TarCheck4
			add	DWORD[g2YTar], 4
			jmp	newDir2
		g2TarCheck4:
			sub	DWORD[g2XTar], 4

	; Figure out the direction to move based on distance to tar and/or state
	newDir2:
	cmp DWORD[g2State], 2 ; If you're running, just pick a random valid direction
	jne newDir2_2
		newDir2_1:
		call rand
		cdq
		mov ebx, 4
		idiv ebx
		cmp edx, 0 ;Up
		jne newDir2_1r
			cmp	DWORD[dir0Val], 0
			je newDir2_1
				mov DWORD[g2NewDir], 0
				jmp g2Move
		newDir2_1r:
		cmp	edx, 1
		jne	newDir2_1d
			cmp	DWORD[dir1Val], 0
			je newDir2_1
				mov DWORD[g2NewDir], 1
				jmp g2Move
		newDir2_1d:
		cmp edx, 2
		jne	newDir2_1l
			cmp	DWORD[dir2Val], 0
			je newDir2_1
				mov DWORD[g2NewDir], 2
				jmp g2Move
		newDir2_1l:
		cmp DWORD[dir3Val], 0
		je	newDir2_1
			mov DWORD[g2NewDir], 3
			jmp g2Move

	; If you're not running, find out which valid direction is closest to target
	newDir2_2:
	; Default to gigantic distance to target
	mov DWORD[g2TarDist], INT_MAX

	; Priority is U,L,D,R so check in reverse and replace ties with current value
	cmp DWORD[dir1Val], 0
	je newDir2_2d
		mov eax, DWORD[g2X]
		inc eax
		sub eax, DWORD[g2XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g2Y]
		sub eax, DWORD[g2YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g2TarDist]
		jg	newDir2_2d
			mov DWORD[g2NewDir], 1
			mov DWORD[g2TarDist], eax
	newDir2_2d:
	cmp DWORD[dir2Val], 0
	je newDir2_2l
		mov eax, DWORD[g2X]
		sub eax, DWORD[g2XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g2Y]
		inc	eax
		sub eax, DWORD[g2YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g2TarDist]
		jg	newDir2_2l
			mov DWORD[g2NewDir], 2
			mov DWORD[g2TarDist], eax
	newDir2_2l:
	cmp DWORD[dir3Val], 0
	je newDir2_2u
		mov eax, DWORD[g2X]
		dec eax
		sub eax, DWORD[g2XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g2Y]
		sub eax, DWORD[g2YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g2TarDist]
		jg	newDir2_2u
			mov DWORD[g2NewDir], 3
			mov DWORD[g2TarDist], eax
	newDir2_2u:
	cmp DWORD[dir0Val], 0
	je g2Move
		mov eax, DWORD[g2X]
		sub eax, DWORD[g2XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g2Y]
		dec	eax
		sub eax, DWORD[g2YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g2TarDist]
		jg	g2Move
			mov DWORD[g2NewDir], 0

	; Move in the new direction found above
	g2Move:
	cmp DWORD[g2NewDir], 0
	jne g2MoveR
		dec DWORD[g2Y]
		mov DWORD[g2Dir], 0
		jmp ghost3MoveStart
	g2MoveR:
	cmp DWORD[g2NewDir], 1
	jne g2MoveD
		; Check for Rteleport
		cmp	DWORD[g2X], 27
		jne	g2NoTele3
			mov	DWORD[g2X], 0
			mov	DWORD[g2Dir], 1
			jmp	ghost3MoveStart
		g2NoTele3:
		inc DWORD[g2X]
		mov DWORD[g2Dir], 1
		jmp ghost3MoveStart
	g2MoveD:
	cmp DWORD[g2NewDir], 2
	jne g2MoveL
		inc DWORD[g2Y]
		mov DWORD[g2Dir], 2
		jmp ghost3MoveStart
	g2MoveL:
	; Check for Lteleport
	cmp	DWORD[g2X], 0
	jne	g2NoTele4
		mov	DWORD[g2X], 27
		mov	DWORD[g2Dir], 3
		jmp	ghost3MoveStart
	g2NoTele4:
	dec DWORD[g2X]
	mov DWORD[g2Dir], 3

	ghost3MoveStart:
	; Ghost 3
	mov DWORD[dir0Val], 1
	mov DWORD[dir1Val], 1
	mov DWORD[dir2Val], 1
	mov DWORD[dir3Val], 1

	; See if you need to leave the eaten state
	cmp	DWORD[g3State], 3
	jne	notEaten3
		cmp	DWORD[g3X], 13
		jne	notEaten3
			cmp	DWORD[g3Y], 11
			jne	notEaten3
				; If you're eaten and at spawn, switch to current phase
				cmp	DWORD[phase], 0
				jne	g3PhaseUpdateSc
					mov DWORD[g3State], 0
					jmp	notEaten3
				g3PhaseUpdateSc:
				mov	DWORD[g3State], 1
	notEaten3:

	; See if move timer is valid to move
	cmp	DWORD[g3State], 3	; Eaten ghosts move 13 dots a second
	jne	g3FMovC
		cmp	DWORD[g3MovTim], 2
		jne ghost4MoveStart
			mov	DWORD[g3MovTim], -1
			jmp g3MovTimEnd
	g3FMovC:
	cmp	DWORD[g3State], 2	; Frightened gosts move about 6 dots a second
	jne	g3NMovC
		cmp	DWORD[g3MovTim], 4
		jne	ghost4MoveStart
			mov	DWORD[g3MovTim], -1
			jmp	g3MovTimEnd
	g3NMovC:
	cmp	DWORD[g3MovTim], 3 	; Ghosts normally move about 7 dots a second
	jne	ghost4MoveStart
		mov	DWORD[g3MovTim], -1

	g3MovTimEnd:
	; Find out which directions are valid
	cmp DWORD[g3Dir], 0 ; Moving Up?
	jne dir3_1
		mov DWORD[dir2Val], 0
	dir3_1:
	cmp DWORD[g3Dir], 1 ; Moving Right?
	jne	dir3_2
		mov DWORD[dir3Val], 0
	dir3_2:
	cmp DWORD[g3Dir], 2 ; Moving Down?
	jne	dir3_3
		mov DWORD[dir0Val], 0
	dir3_3:
	cmp DWORD[g3Dir], 3 ; Moving Left?
	jne	g3WallCheck
		mov	DWORD[dir1Val], 0

	g3WallCheck:
	; Check Up
	cmp		DWORD[dir0Val], 0
	je		rWallC3
		mov		eax, WIDTH
		mov		ebx, DWORD[g3Y]
		dec		ebx
		mul		ebx
		add		eax, [g3X]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		rWallC3
			mov DWORD[dir0Val], 0
	rWallC3:
	cmp		DWORD[dir1Val], 0
	je		dWallC3
		; Check for Rteleport
		cmp		DWORD[g3X], 27
		jne		g3NoTele1
			jmp	dWallC3
		g3NoTele1:
		mov		eax, WIDTH
		mul		DWORD[g3Y]
		; I DUNNO IF THIS WILL WORK
		inc		DWORD[g3X]
		add		eax, [g3X]
		dec		DWORD[g3X]
		; END OF I DUNNO IF THIS WILL WORK
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		dWallC3
			mov DWORD[dir1Val], 0
	dWallC3:
	cmp		DWORD[dir2Val], 0
	je		lWallC3
		mov		eax, WIDTH
		mov		ebx, DWORD[g3Y]
		inc		ebx
		mul		ebx
		add		eax, [g3X]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		lWallC3
			mov DWORD[dir2Val], 0
	lWallC3:
	cmp		DWORD[dir3Val], 0
	je		g3StateCheck
		; Check for lTeleport
		cmp		DWORD[g3X], 0
		jne		g3NoTele2
			jmp	g3StateCheck
		g3NoTele2:
		mov		eax, WIDTH
		mul		DWORD[g3Y]
		; I DUNNO IF THIS WILL WORK
		dec		DWORD[g3X]
		add		eax, [g3X]
		inc		DWORD[g3X]
		; END OF I DUNNO IF THIS WILL WORK
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		g3StateCheck
			mov DWORD[dir3Val], 0

	; Get a target if possible
	g3StateCheck:
	cmp DWORD[g3State], 3 ; Eaten?
	jne scCheck3
		mov DWORD[g3XTar], 13
		mov DWORD[g3YTar], 11
		jmp newDir3
	scCheck3:
	cmp DWORD[g3State], 1 ; Scatter?
	jne	chCheck3
		mov DWORD[g3XTar], WIDTH
		mov DWORD[g3YTar], HEIGHT
		jmp newDir3
	chCheck3:
	cmp	DWORD[g3State], 0 ; Chasing?
	jne newDir3
		mov eax, DWORD[xpos]
		mov DWORD[g3XTar], eax
		mov eax, DWORD[ypos]
		mov DWORD[g3YTar], eax
		; Find offset of 2 in front of pacman
		cmp	DWORD[playDir], 0
		jne	g3TarCheck2
			sub	DWORD[g3XTar], 2
			sub	DWORD[g3YTar], 2
			jmp	getG3XTar
		g3TarCheck2:
		cmp	DWORD[playDir], 1
		jne	g3TarCheck3
			add	DWORD[g3XTar], 2
			jmp	getG3XTar
		g3TarCheck3:
		cmp	DWORD[playDir], 2
		jne	g3TarCheck4
			add	DWORD[g3YTar], 2
			jmp	getG3XTar
		g3TarCheck4:
			sub	DWORD[g3XTar], 2

		getG3XTar:
		; Find offset to g1 and flip 180
		mov eax, DWORD[g3XTar]
		cmp eax, DWORD[g1X]
		jl	g3XL
			sub	eax, DWORD[g1X]
			add	DWORD[g3XTar], eax
			jmp getG3YTar
		g3XL:
			mov	eax, DWORD[g1X]
			sub	eax, DWORD[g3XTar]
			sub	DWORD[g3XTar], eax
		getG3YTar:
		mov eax, DWORD[g3YTar]
		cmp eax, DWORD[g1Y]
		jl	g3YL
			sub	eax, DWORD[g1Y]
			add	DWORD[g3YTar], eax
			jmp newDir3
		g3YL:
			mov	eax, DWORD[g1Y]
			sub	eax, DWORD[g3YTar]
			sub	DWORD[g3YTar], eax


	; Figure out the direction to move based on distance to tar and/or state
	newDir3:
	cmp DWORD[g3State], 2 ; If you're running, just pick a random valid direction
	jne newDir3_2
		newDir3_1:
		call rand
		cdq
		mov ebx, 4
		idiv ebx
		cmp edx, 0 ;Up
		jne newDir3_1r
			cmp	DWORD[dir0Val], 0
			je newDir3_1
				mov DWORD[g3NewDir], 0
				jmp g3Move
		newDir3_1r:
		cmp	edx, 1
		jne	newDir3_1d
			cmp	DWORD[dir1Val], 0
			je newDir3_1
				mov DWORD[g3NewDir], 1
				jmp g3Move
		newDir3_1d:
		cmp edx, 2
		jne	newDir3_1l
			cmp	DWORD[dir2Val], 0
			je newDir3_1
				mov DWORD[g3NewDir], 2
				jmp g3Move
		newDir3_1l:
		cmp DWORD[dir3Val], 0
		je	newDir3_1
			mov DWORD[g3NewDir], 3
			jmp g3Move

	; If you're not running, find out which valid direction is closest to target
	newDir3_2:
	; Default to gigantic distance to target
	mov DWORD[g3TarDist], INT_MAX

	; Priority is U,L,D,R so check in reverse and replace ties with current value
	cmp DWORD[dir1Val], 0
	je newDir3_2d
		mov eax, DWORD[g3X]
		inc eax
		sub eax, DWORD[g3XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g3Y]
		sub eax, DWORD[g3YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g3TarDist]
		jg	newDir3_2d
			mov DWORD[g3NewDir], 1
			mov DWORD[g3TarDist], eax
	newDir3_2d:
	cmp DWORD[dir2Val], 0
	je newDir3_2l
		mov eax, DWORD[g3X]
		sub eax, DWORD[g3XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g3Y]
		inc	eax
		sub eax, DWORD[g3YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g3TarDist]
		jg	newDir3_2l
			mov DWORD[g3NewDir], 2
			mov DWORD[g3TarDist], eax
	newDir3_2l:
	cmp DWORD[dir3Val], 0
	je newDir3_2u
		mov eax, DWORD[g3X]
		dec eax
		sub eax, DWORD[g3XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g3Y]
		sub eax, DWORD[g3YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g3TarDist]
		jg	newDir3_2u
			mov DWORD[g3NewDir], 3
			mov DWORD[g3TarDist], eax
	newDir3_2u:
	cmp DWORD[dir0Val], 0
	je g3Move
		mov eax, DWORD[g3X]
		sub eax, DWORD[g3XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g3Y]
		dec	eax
		sub eax, DWORD[g3YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g3TarDist]
		jg	g3Move
			mov DWORD[g3NewDir], 0

	; Move in the new direction found above
	g3Move:
	cmp DWORD[g3NewDir], 0
	jne g3MoveR
		dec DWORD[g3Y]
		mov DWORD[g3Dir], 0
		jmp ghost4MoveStart
	g3MoveR:
	cmp DWORD[g3NewDir], 1
	jne g3MoveD
		; Check for Rteleport
		cmp	DWORD[g3X], 27
		jne	g3NoTele3
			mov	DWORD[g3X], 0
			mov	DWORD[g3Dir], 1
			jmp	ghost4MoveStart
		g3NoTele3:
		inc DWORD[g3X]
		mov DWORD[g3Dir], 1
		jmp ghost4MoveStart
	g3MoveD:
	cmp DWORD[g3NewDir], 2
	jne g3MoveL
		inc DWORD[g3Y]
		mov DWORD[g3Dir], 2
		jmp ghost4MoveStart
	g3MoveL:
	; Check for Lteleport
	cmp	DWORD[g3X], 0
	jne	g3NoTele4
		mov	DWORD[g3X], 27
		mov	DWORD[g3Dir], 3
		jmp	ghost4MoveStart
	g3NoTele4:
	dec DWORD[g3X]
	mov DWORD[g3Dir], 3

	ghost4MoveStart:
	; Ghost 4
	mov DWORD[dir0Val], 1
	mov DWORD[dir1Val], 1
	mov DWORD[dir2Val], 1
	mov DWORD[dir3Val], 1

	; See if you need to leave the eaten state
	cmp	DWORD[g4State], 3
	jne	notEaten4
		cmp	DWORD[g4X], 13
		jne	notEaten4
			cmp	DWORD[g4Y], 11
			jne	notEaten4
				; If you're eaten and at spawn, switch to current phase
				cmp	DWORD[phase], 0
				jne	g4PhaseUpdateSc
					mov DWORD[g4State], 0
					jmp	notEaten4
				g4PhaseUpdateSc:
				mov	DWORD[g4State], 1
	notEaten4:

	; See if move timer is valid to move
	cmp	DWORD[g4State], 3	; Eaten ghosts move 13 dots a second
	jne	g4FMovC
		cmp	DWORD[g3MovTim], 2
		jne endGhostMove
			mov	DWORD[g4MovTim], -1
			jmp g4MovTimEnd
	g4FMovC:
	cmp	DWORD[g4State], 2	; Frightened gosts move about 6 dots a second
	jne	g4NMovC
		cmp	DWORD[g4MovTim], 4
		jne	endGhostMove
			mov	DWORD[g4MovTim], -1
			jmp	g4MovTimEnd
	g4NMovC:
	cmp	DWORD[g4MovTim], 3 	; Ghosts normally move about 7 dots a second
	jne	endGhostMove
		mov	DWORD[g4MovTim], -1

	g4MovTimEnd:
	; Find out which directions are valid
	cmp DWORD[g4Dir], 0 ; Moving Up?
	jne dir4_1
		mov DWORD[dir2Val], 0
	dir4_1:
	cmp DWORD[g4Dir], 1 ; Moving Right?
	jne	dir4_2
		mov DWORD[dir3Val], 0
	dir4_2:
	cmp DWORD[g4Dir], 2 ; Moving Down?
	jne	dir4_3
		mov DWORD[dir0Val], 0
	dir4_3:
	cmp DWORD[g4Dir], 3 ; Moving Left?
	jne	g4WallCheck
		mov	DWORD[dir1Val], 0

	g4WallCheck:
	; Check Up
	cmp		DWORD[dir0Val], 0
	je		rWallC4
		mov		eax, WIDTH
		mov		ebx, DWORD[g4Y]
		dec		ebx
		mul		ebx
		add		eax, [g4X]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		rWallC4
			mov DWORD[dir0Val], 0
	rWallC4:
	cmp		DWORD[dir1Val], 0
	je		dWallC4
		; Check for Rteleport
		cmp		DWORD[g4X], 27
		jne		g4NoTele1
			jmp	dWallC4
		g4NoTele1:
		mov		eax, WIDTH
		mul		DWORD[g4Y]
		; I DUNNO IF THIS WILL WORK
		inc		DWORD[g4X]
		add		eax, [g4X]
		dec		DWORD[g4X]
		; END OF I DUNNO IF THIS WILL WORK
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		dWallC4
			mov DWORD[dir1Val], 0
	dWallC4:
	cmp		DWORD[dir2Val], 0
	je		lWallC4
		mov		eax, WIDTH
		mov		ebx, DWORD[g4Y]
		inc		ebx
		mul		ebx
		add		eax, [g4X]
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		lWallC4
			mov DWORD[dir2Val], 0
	lWallC4:
	cmp		DWORD[dir3Val], 0
	je		g4StateCheck
		; Check for lTeleport
		cmp		DWORD[g4X], 0
		jne		g4NoTele2
			jmp	g4StateCheck
		g4NoTele2:
		mov		eax, WIDTH
		mul		DWORD[g4Y]
		; I DUNNO IF THIS WILL WORK
		dec		DWORD[g4X]
		add		eax, [g4X]
		inc		DWORD[g4X]
		; END OF I DUNNO IF THIS WILL WORK
		lea		eax, [board + eax]
		cmp		BYTE [eax], WALL_CHAR
		jne		g4StateCheck
			mov DWORD[dir3Val], 0

	; Get a target if possible
	g4StateCheck:
	cmp DWORD[g4State], 3 ; Eaten?
	jne scCheck4
		mov DWORD[g4XTar], 13
		mov DWORD[g4YTar], 11
		jmp newDir4
	scCheck4:
	cmp DWORD[g4State], 1 ; Scatter?
	jne	chCheck4
		mov DWORD[g4XTar], 0
		mov DWORD[g4YTar], HEIGHT
		jmp newDir4
	chCheck4:
	cmp	DWORD[g4State], 0 ; Chasing?
	jne newDir4
		mov eax, DWORD[xpos]
		mov DWORD[g4XTar], eax
		mov eax, DWORD[ypos]
		mov DWORD[g4YTar], eax

		mov	eax, DWORD[g4XTar]
		cmp	eax, DWORD[xpos]
		jl	g4XL
			sub	eax, DWORD[xpos]
			mov ebx, eax
			jmp	getG4Y
		g4XL:
			mov	eax, DWORD[xpos]
			sub eax, DWORD[g4XTar]
			mov ebx, eax
		getG4Y:
		mov	eax, DWORD[g4YTar]
		cmp	eax, DWORD[ypos]
		jl	g4YL
			sub	eax, DWORD[ypos]
			add eax, ebx
			cmp	eax, 8
			jg	newDir4
				mov	DWORD[g4XTar], 0
				mov	DWORD[g4YTar], HEIGHT
				jmp	newDir4
		g4YL:
			mov	eax, DWORD[ypos]
			sub eax, DWORD[g4YTar]
			add eax, ebx
			cmp	eax, 8
			jg	newDir4
				mov	DWORD[g4XTar], 0
				mov	DWORD[g4YTar], HEIGHT
				jmp	newDir4

	; Figure out the direction to move based on distance to tar and/or state
	newDir4:
	cmp DWORD[g4State], 2 ; If you're running, just pick a random valid direction
	jne newDir4_2
		newDir4_1:
		call rand
		cdq
		mov ebx, 4
		idiv ebx
		cmp edx, 0 ;Up
		jne newDir4_1r
			cmp	DWORD[dir0Val], 0
			je newDir4_1
				mov DWORD[g4NewDir], 0
				jmp g4Move
		newDir4_1r:
		cmp	edx, 1
		jne	newDir4_1d
			cmp	DWORD[dir1Val], 0
			je newDir4_1
				mov DWORD[g4NewDir], 1
				jmp g4Move
		newDir4_1d:
		cmp edx, 2
		jne	newDir4_1l
			cmp	DWORD[dir2Val], 0
			je newDir4_1
				mov DWORD[g4NewDir], 2
				jmp g4Move
		newDir4_1l:
		cmp DWORD[dir3Val], 0
		je	newDir4_1
			mov DWORD[g4NewDir], 3
			jmp g4Move

	; If you're not running, find out which valid direction is closest to target
	newDir4_2:
	; Default to gigantic distance to target
	mov DWORD[g4TarDist], INT_MAX

	; Priority is U,L,D,R so check in reverse and replace ties with current value
	cmp DWORD[dir1Val], 0
	je newDir4_2d
		mov eax, DWORD[g4X]
		inc eax
		sub eax, DWORD[g4XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g4Y]
		sub eax, DWORD[g4YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g4TarDist]
		jg	newDir4_2d
			mov DWORD[g4NewDir], 1
			mov DWORD[g4TarDist], eax
	newDir4_2d:
	cmp DWORD[dir2Val], 0
	je newDir4_2l
		mov eax, DWORD[g4X]
		sub eax, DWORD[g4XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g4Y]
		inc	eax
		sub eax, DWORD[g4YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g4TarDist]
		jg	newDir4_2l
			mov DWORD[g4NewDir], 2
			mov DWORD[g4TarDist], eax
	newDir4_2l:
	cmp DWORD[dir3Val], 0
	je newDir4_2u
		mov eax, DWORD[g4X]
		dec eax
		sub eax, DWORD[g4XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g4Y]
		sub eax, DWORD[g4YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g4TarDist]
		jg	newDir4_2u
			mov DWORD[g4NewDir], 3
			mov DWORD[g4TarDist], eax
	newDir4_2u:
	cmp DWORD[dir0Val], 0
	je g4Move
		mov eax, DWORD[g4X]
		sub eax, DWORD[g4XTar]
		cdq
		imul eax
		mov ebx, eax

		mov eax, DWORD[g4Y]
		dec	eax
		sub eax, DWORD[g4YTar]
		cdq
		imul eax
		add eax, ebx
		cmp eax, DWORD[g4TarDist]
		jg	g4Move
			mov DWORD[g4NewDir], 0

	; Move in the new direction found above
	g4Move:
	cmp DWORD[g4NewDir], 0
	jne g4MoveR
		dec DWORD[g4Y]
		mov DWORD[g4Dir], 0
		jmp endGhostMove
	g4MoveR:
	cmp DWORD[g4NewDir], 1
	jne g4MoveD
		; Check for Rteleport
		cmp	DWORD[g4X], 27
		jne	g4NoTele3
			mov	DWORD[g4X], 0
			mov	DWORD[g4Dir], 1
			jmp	endGhostMove
		g4NoTele3:
		inc DWORD[g4X]
		mov DWORD[g4Dir], 1
		jmp endGhostMove
	g4MoveD:
	cmp DWORD[g4NewDir], 2
	jne g4MoveL
		inc DWORD[g4Y]
		mov DWORD[g4Dir], 2
		jmp endGhostMove
	g4MoveL:
	; Check for Lteleport
	cmp	DWORD[g4X], 0
	jne	g4NoTele4
		mov	DWORD[g4X], 27
		mov	DWORD[g4Dir], 3
		jmp	endGhostMove
	g4NoTele4:
	dec DWORD[g4X]
	mov DWORD[g4Dir], 3
	endGhostMove:


	; Check for ghosts now that all movement is done
	mov eax, DWORD[g1X]
	cmp DWORD[xpos],eax
	jne g2_check2
		mov eax, DWORD[g1Y]
		cmp DWORD[ypos], eax
		jne g2_check2
			cmp DWORD[g1State], 2
			jne g1_eaten_check2
				mov	DWORD[g1State], 3
				mov ebx, DWORD[eatScore]
				add	DWORD[score], ebx
				mov eax, DWORD[eatScore]
				mov ebx, 2
				cdq
				imul ebx
				mov DWORD[eatScore], eax
				inc DWORD[gEaten]
				jmp g2_check2
			g1_eaten_check2:
			cmp DWORD[g1State], 3
			jne	game_loop_end
				jmp	g2_check2
	g2_check2:
	mov eax, DWORD[g2X]
	cmp DWORD[xpos],eax
	jne g3_check2
		mov eax, DWORD[g2Y]
		cmp DWORD[ypos], eax
		jne g3_check2
			cmp DWORD[g2State], 2
			jne g2_eaten_check2
				mov	DWORD[g2State], 3
				mov ebx, DWORD[eatScore]
				add	DWORD[score], ebx
				mov eax, DWORD[eatScore]
				mov ebx, 2
				cdq
				imul ebx
				mov DWORD[eatScore], eax
				inc DWORD[gEaten]
				jmp g3_check2
			g2_eaten_check2:
			cmp	DWORD[g2State], 3
			jne	game_loop_end
				jmp	g3_check2
	g3_check2:
	mov eax, DWORD[g3X]
	cmp DWORD[xpos],eax
	jne g4_check2
		mov eax, DWORD[g3Y]
		cmp DWORD[ypos], eax
		jne g4_check2
			cmp DWORD[g3State], 2
			jne g3_eaten_check2
				mov DWORD[g3State], 3
				mov ebx, DWORD[eatScore]
				add	DWORD[score], ebx
				mov eax, DWORD[eatScore]
				mov ebx, 2
				cdq
				imul ebx
				mov DWORD[eatScore], eax
				inc DWORD[gEaten]
				jmp g4_check2
			g3_eaten_check2:
			cmp	DWORD[g3State], 3
			jne	game_loop_end
				jmp	g4_check2
	g4_check2:
	mov eax, DWORD[g4X]
	cmp DWORD[xpos],eax
	jne endg_check2
		mov eax, DWORD[g4Y]
		cmp DWORD[ypos], eax
		jne endg_check2
			cmp DWORD[g4State], 2
			jne g4_eaten_check2
				mov DWORD[g4State], 3
				mov ebx, DWORD[eatScore]
				add	DWORD[score], ebx
				mov eax, DWORD[eatScore]
				mov ebx, 2
				cdq
				imul ebx
				mov DWORD[eatScore], eax
				inc DWORD[gEaten]
				jmp endg_check2
			g4_eaten_check2:
			cmp	DWORD[g4State], 3
			jne	game_loop_end
	endg_check2:

	; Update pTimer as needed
	cmp DWORD[pTimer], 0
	je	no_timer
		dec DWORD[pTimer]
		cmp DWORD[pTimer], 0
		jne no_timer
			mov DWORD[eatScore], 200
			mov DWORD[gEaten], 0
			cmp	DWORD[phase], 0
			jne pelSca
				cmp DWORD[g1State], 3
				je	pel2C
					mov	DWORD[g1State], 0
				pel2C:
				cmp DWORD[g2State], 3
				je	pel3C
					mov	DWORD[g2State], 0
				pel3C:
				cmp DWORD[g3State], 3
				je	pel4C
					mov	DWORD[g3State], 0
				pel4C:
				cmp DWORD[g4State], 3
				je	no_timer
					mov	DWORD[g4State], 0
			pelSca:
				cmp DWORD[g1State], 3
				je	pel2S
					mov	DWORD[g1State], 1
				pel2S:
				cmp DWORD[g2State], 3
				je	pel3S
					mov	DWORD[g2State], 1
				pel3S:
				cmp DWORD[g3State], 3
				je	pel4S
					mov	DWORD[g3State], 1
				pel4S:
				cmp DWORD[g4State], 3
				je	no_timer
					mov	DWORD[g4State], 1
	no_timer:

	; Update move timers
	inc	DWORD[pMovTim]
	inc	DWORD[g1MovTim]
	inc	DWORD[g2MovTim]
	inc	DWORD[g3MovTim]
	inc	DWORD[g4MovTim]

	; Update phase timer/phase
	cmp	DWORD[phaseTime], 0
	jne	noPhaseSwitch
		cmp	DWORD[phase], 0
		jne	phaseSwitchC
			mov	DWORD[phase], 1
			mov	DWORD[phaseTime], 183
			jmp	phaseSwitch
		phaseSwitchC:
			mov	DWORD[phase], 0
			mov	DWORD[phaseTime], 521
	phaseSwitch:
	cmp	DWORD[g1State], 3
	je	g2PhaseSwitch
		mov eax, DWORD[phase]
		mov	DWORD[g1State], eax
	g2PhaseSwitch:
	cmp	DWORD[g2State], 3
	je	g3PhaseSwitch
		mov eax, DWORD[phase]
		mov	DWORD[g2State], eax
	g3PhaseSwitch:
	cmp	DWORD[g3State], 3
	je	g4PhaseSwitch
		mov eax, DWORD[phase]
		mov	DWORD[g3State], eax
	g4PhaseSwitch:
	cmp	DWORD[g4State], 3
	je	noPhaseSwitch
		mov eax, DWORD[phase]
		mov	DWORD[g4State], eax
	noPhaseSwitch:
	dec	DWORD[phaseTime]

	; Check if all dots eaten
	cmp DWORD[dots], 0
	je game_loop_end

	; Framerate
	push	TICK
	call	usleep
	add		esp, 4

	jmp		game_loop
	game_loop_end:

	; restore old terminal functionality
	call raw_mode_off

	; clear the screen
	push	clear_screen_cmd
	call	system
	add		esp, 4

	; Print final score
	push DWORD[score]
	push end_str
	call printf
	add esp, 8

	;***************CODE ENDS HERE*****************************
	popa
	mov		eax, 0
	leave
	ret

;== FUNCTION ===
nonblocking_getchar:

; returns -1 on no-data
; returns char on success

%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 2048
%define STDIN 0

	push	ebp
	mov		ebp, esp

	; single int used to hold flags
	; single character (aligned to 4 bytes) return
	sub		esp, 8

	; get current stdin flags
	; flags = fcntl(stdin, F_GETFL, 0)
	push	0
	push	F_GETFL
	push	STDIN
	call 	fcntl
	add		esp, 12
	mov		DWORD[ebp - 4], eax

	; set non-blocking mode in stdin
	; fcntl(stdin, F_SETFL, flags | O_NONBLOCK)
	or		DWORD[ebp - 4], O_NONBLOCK
	push	DWORD[ebp - 4]
	push	F_SETFL
	push	STDIN
	call	fcntl
	add		esp, 12

	call	getchar
	mov		DWORD[ebp - 8], eax

	; restore blocking mode
	; fcntl(stdin, F_SETFL, flags ^ O_NONBLOCK)
	xor		DWORD[ebp - 4], O_NONBLOCK
	push	DWORD[ebp-4]
	push	F_SETFL
	push	STDIN
	call	fcntl
	add		esp, 12

	mov		eax, DWORD[ebp - 8]

	mov		esp, ebp
	pop		ebp
	ret


; === FUNCTION ===
raw_mode_on:

	push	ebp
	mov		ebp, esp

	push	raw_mode_on_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
raw_mode_off:

	push	ebp
	mov		ebp, esp

	push	raw_mode_off_cmd
	call	system
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
init_board:

	push	ebp
	mov		ebp, esp

	; FILE* and loop counter
	; ebp-4, ebp-8
	sub		esp, 8

	; open the file
	push	mode_r
	push	board_file
	call	fopen
	add		esp, 8
	mov		DWORD [ebp-4], eax

	; read the file data into the global buffer
	; line-by-line so we can ignore the newline characters
	mov		DWORD [ebp-8], 0
	read_loop:
	cmp		DWORD [ebp-8], HEIGHT
	je		read_loop_end

		; find the offset (WIDTH * counter)
		mov		eax, WIDTH
		mul		DWORD [ebp-8]
		lea		ebx, [board + eax]

		; read the bytes into the buffer
		push	DWORD [ebp-4]
		push	WIDTH
		push	1
		push	ebx
		call	fread
		add		esp, 16

		; slurp up the newline
		push	DWORD [ebp-4]
		call	fgetc
		add		esp, 4

	inc		DWORD [ebp-8]
	jmp		read_loop
	read_loop_end:

	; close the open file handle
	push	DWORD [ebp-4]
	call	fclose
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
init_stuff:

	push	ebp
	mov		ebp, esp

	; FILE* and loop counter
	; ebp-4, ebp-8
	sub		esp, 8

	; open the file
	push	mode_r
	push	stuff_file
	call	fopen
	add		esp, 8
	mov		DWORD [ebp-4], eax

	; read the file data into the global buffer
	; line-by-line so we can ignore the newline characters
	mov		DWORD [ebp-8], 0
	read_loop_stuff:
	cmp		DWORD [ebp-8], HEIGHT
	je		read_loop_stuff_end

		; find the offset (WIDTH * counter)
		mov		eax, WIDTH
		mul		DWORD [ebp-8]
		lea		ebx, [stuff + eax]

		; read the bytes into the buffer
		push	DWORD [ebp-4]
		push	WIDTH
		push	1
		push	ebx
		call	fread
		add		esp, 16

		; slurp up the newline
		push	DWORD [ebp-4]
		call	fgetc
		add		esp, 4

	inc		DWORD [ebp-8]
	jmp		read_loop_stuff
	read_loop_stuff_end:

	; close the open file handle
	push	DWORD [ebp-4]
	call	fclose
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; === FUNCTION ===
render:

	push	ebp
	mov		ebp, esp

	; two ints, for two loop counters
	; ebp-4, ebp-8
	sub		esp, 8

	; clear the screen
	push	clear_screen_cmd
	call	system
	add		esp, 4

	; print the help information
	push	help_str
	call	printf
	add		esp, 4

	; print score
	push	DWORD[score]
	push	score_str
	call	printf
	add		esp, 8

	; outside loop by height
	; i.e. for(c=0; c<height; c++)
	mov		DWORD [ebp-4], 0
	y_loop_start:
	cmp		DWORD [ebp-4], HEIGHT
	je		y_loop_end

		; inside loop by width
		; i.e. for(c=0; c<width; c++)
		mov		DWORD [ebp-8], 0
		x_loop_start:
		cmp		DWORD [ebp-8], WIDTH
		je 		x_loop_end

			; check if (xpos,ypos)=(x,y)
			mov		eax, [xpos]
			cmp		eax, DWORD [ebp-8]
			jne		ghost1_Check
			mov		eax, [ypos]
			cmp		eax, DWORD [ebp-4]
			jne		ghost1_Check
				; if both were equal, print the player
				push C_YEL
				call printf
				add esp, 4

				push A_BOLD
				call printf
				add esp, 4

				; Print proper player direction char
				cmp		DWORD[playDir], 0
				jne dir2
					push	PLAYERU_CHAR
					jmp 	print_end
				dir2:
				cmp		DWORD[playDir], 1
				jne dir3
					push	PLAYERR_CHAR
					jmp		print_end
				dir3:
				cmp		DWORD[playDir], 2
				jne dir4
					push	PLAYERD_CHAR
					jmp		print_end
				dir4:
					push	PLAYERL_CHAR
					jmp		print_end
			ghost1_Check:
			mov		eax, [g1X]
			cmp		eax, DWORD[ebp - 8]
			jne 	ghost2_Check
			mov		eax, [g1Y]
			cmp		eax, DWORD[ebp - 4]
			jne		ghost2_Check
				; if both were equal, print ghost 1
				cmp DWORD[g1State], 2
				jne noBlue1
					cmp DWORD[pTimer], 26
					jg noBlink1
						push A_BLINK
						call printf
						add esp, 4
					noBlink1:
					push B_BLU
					call printf
					add esp, 4
					push GHOST1_CHAR
					jmp print_end
				noBlue1:
				cmp	DWORD[g1State], 3
				jne	r_notEaten1
					push	C_DEF
					call	printf
					add		esp, 4

					push	B_DEF
					call	printf
					add		esp, 4
					jmp		r_eaten1
				r_notEaten1:
				push C_RED
				call printf
				add esp, 4
				r_eaten1:
				push	GHOST1_CHAR
				jmp		print_end
			ghost2_Check:
			mov		eax, [g2X]
			cmp		eax, DWORD[ebp - 8]
			jne 	ghost3_Check
			mov		eax, [g2Y]
			cmp		eax, DWORD[ebp - 4]
			jne		ghost3_Check
				; if both were equal, print ghost 2
				cmp DWORD[g2State], 2
				jne noBlue2
					cmp DWORD[pTimer], 26
					jg noBlink2
						push A_BLINK
						call printf
						add esp, 4
					noBlink2:
					push B_BLU
					call printf
					add esp, 4
					push GHOST2_CHAR
					jmp print_end
				noBlue2:
				cmp	DWORD[g2State], 3
				jne	r_notEaten2
					push	C_DEF
					call	printf
					add		esp, 4

					push	B_DEF
					call	printf
					add		esp, 4
					jmp		r_eaten2
				r_notEaten2:
				push C_PINK
				call printf
				add esp, 4
				r_eaten2:
				push	GHOST2_CHAR
				jmp		print_end
			ghost3_Check:
			mov		eax, [g3X]
			cmp		eax, DWORD[ebp - 8]
			jne 	ghost4_Check
			mov		eax, [g3Y]
			cmp		eax, DWORD[ebp - 4]
			jne		ghost4_Check
				; if both were equal, print ghost 3
				cmp DWORD[g3State], 2
				jne noBlue3
					cmp DWORD[pTimer], 26
					jg noBlink3
						push A_BLINK
						call printf
						add esp, 4
					noBlink3:
					push B_BLU
					call printf
					add esp, 4
					push GHOST3_CHAR
					jmp print_end
				noBlue3:
				cmp	DWORD[g3State], 3
				jne	r_notEaten3
					push	C_DEF
					call	printf
					add		esp, 4

					push	B_DEF
					call	printf
					add		esp, 4
					jmp		r_eaten3
				r_notEaten3:
				push C_GRN
				call printf
				add esp, 4
				r_eaten3:
				push	GHOST3_CHAR
				jmp		print_end
			ghost4_Check:
			mov		eax, [g4X]
			cmp		eax, DWORD[ebp - 8]
			jne 	print_board
			mov		eax, [g4Y]
			cmp		eax, DWORD[ebp - 4]
			jne		print_board
				; if both were equal, print ghost 4
				cmp DWORD[g4State], 2
				jne noBlue4
					cmp DWORD[pTimer], 26
					jg noBlink4
						push A_BLINK
						call printf
						add esp, 4
					noBlink4:
					push B_BLU
					call printf
					add esp, 4
					push GHOST4_CHAR
					jmp print_end
				noBlue4:
				cmp	DWORD[g4State], 3
				jne	r_notEaten4
					push	C_DEF
					call	printf
					add		esp, 4

					push	B_DEF
					call	printf
					add		esp, 4
					jmp		r_eaten4
				r_notEaten4:
				push C_TUR
				call printf
				add esp, 4
				r_eaten4:
				push	GHOST4_CHAR
				jmp		print_end

				print_board:
				; otherwise print whatever's in the buffer
				mov		eax, [ebp-4]
				mov		ebx, WIDTH
				mul		ebx
				add		eax, [ebp-8]
				mov		ebx, 0
				mov		bl, BYTE[stuff + eax]
				cmp		bl, '#'
				jne fruitCheck
					push C_LBLU
					call printf
					add esp, 4
					push ebx
					jmp print_end
				fruitCheck:
				cmp		bl, 'B'
				jne pCheck
					push C_RED
					call printf
					add esp, 4
					push ebx
					jmp print_end
				pCheck:
				cmp		bl, 'O'
				jne noItem
					push A_BLINK
					call printf
					add esp, 4
				noItem:
				push	ebx
			print_end:
			call	putchar
			add		esp, 4

			push C_DEF
			call printf
			add esp, 4

			push A_DEF
			call printf
			add esp, 4

			push B_DEF
			call printf
			add	 esp, 4

		inc		DWORD [ebp-8]
		jmp		x_loop_start
		x_loop_end:

		; write a carriage return (necessary when in raw mode)
		push	0x0d
		call 	putchar
		add		esp, 4

		; write a newline
		push	0x0a
		call	putchar
		add		esp, 4

	inc		DWORD [ebp-4]
	jmp		y_loop_start
	y_loop_end:

	mov		esp, ebp
	pop		ebp
	ret
