;lab 5
;Juan Emilio Reyes
;Programación de Microcontroladores
PROCESSOR 16F887
 #include <xc.inc>
 
 ;configuration word 1
  CONFIG FOSC=INTRC_NOCLKOUT	// Oscillador Interno sin salidas, XT
  CONFIG WDTE=OFF   // WDT disabled (reinicio repetitivo del pic)
  CONFIG PWRTE=OFF   // PWRT enabled  (espera de 72ms al iniciar)
  CONFIG MCLRE=OFF  // El pin de MCLR se utiliza como I/O
  CONFIG CP=OFF	    // Sin protección de código
  CONFIG CPD=OFF    // Sin protección de datos
  
  CONFIG BOREN=OFF  // Sin reinicio cuándo el voltaje de alimentación baja de 4V
  CONFIG IESO=OFF   // Reinicio sin cambio de reloj de interno a externo
  CONFIG FCMEN=OFF  // Cambio de reloj externo a interno en caso de fallo
  CONFIG LVP=OFF     // programación en bajo voltaje
 
 ;configuration word 2
  CONFIG WRT=OFF    // Protección de autoescritura por el programa desactivada
  CONFIG BOR4V=BOR40V // Reinicio abajo de 4V, (BOR21V=2.1V)
  
  
  ;------------------------- macro reset timer -----------------------------
  rest_tmr0 macro
    banksel PORTA
    movlw   250	    ;Tiempo deseado =4*tiempo de oscilación *(256-N)*(PRESCALER)
    movwf   TMR0    
    bcf	    T0IF    ; clear a la bandera luego del reinicio
    endm
    
  ;----------------------------- macro división -------------------------------
  wdivl	macro divisor  
    movwf	var_02    
    clrf	var_02+1  
	
    incf	var_02+1   ; Las veces que ha restado
    movlw	divisor  

    subwf	var_02, f   ;se resta con el divisor y se guarda en F
    btfsc	CARRY    ;revisa si existe acarreo
    goto	$-4	; si no hay acarreo, la resta se repite
	
    decf	var_02+1,W    ; se guardan los resultados en W
    movwf	cociente   
    
    movlw	divisor	    
    addwf	var_02, W
    movwf	residuo
	
    endm
    
 ;---------------------- variables equivalentes -------------------------------
 UP EQU 6
DOWN EQU 7 
 
;-------------------------------- variables ---------------------------------
 PSECT	udata_bank0
    banderas:	    DS 1
    nibble:	    DS 2
    display_var:    DS 3
  
    cociente:	DS 1
    residuo:	DS 1
    decena:	DS 1
    centena:	DS 1
    var_02:	DS 2
    unit:	DS 2
    var:	DS 1
   
 PSECT	udata_shr   ;common memory
    W_TEMP:	     DS 1
    STATUS_TEMP: DS 1
  
;----------------------------- vector reset -------------------------------; 
 PSECT resVect, class=CODE, abs, delta=2 
 ORG 00h          ;posición en 0
    
 resetVec:        ;regresar a la posicion 0 
  PAGESEL main	 
  goto main      

  
;------------------------- vector interrupcion ----------------------------;

PSECT intVect, class=CODE, abs, delta=2  
ORG 04h          ;posicion en 0004h 

push:
    movwf   W_TEMP	
    swapf   STATUS, W   
    movwf   STATUS_TEMP 
    
isr:
    btfsc   RBIF	 
    call    inter_iocb   
    
    btfsc   T0IF 
    call    inter_t0	  
pop:
    swapf   STATUS_TEMP, W  
    movwf   STATUS	    
    swapf   W_TEMP, F	    
    swapf   W_TEMP, W	    
    retfie
    
;--------------------- sub rutina de interrpcion ----------------------------;
inter_iocb:		     ;interrupcion de PORTB, push
    banksel PORTA
    btfss   PORTB,UP         ; PORTB 6 incrementa
    incf    PORTA	     
    btfss   PORTB,DOWN	     ;PORTB 7 decrementa
    decf    PORTA
    bcf	    RBIF
    return
   
inter_t0:	      ;interrupcion del TMRO
    rest_tmr0   ;20 mseg
    clrf    PORTD     ;apagar displays para no mostrar traslapes
    btfss   banderas, 0 
    goto    display0
    btfss   banderas, 1
    goto    display1
    goto    display2
    
;unidad    
display0:
    bsf	    banderas,	0
    movf    display_var+0, W
    movwf   PORTC
    bsf	    PORTD,0
    return
;decena    
display1:
    bcf	    banderas,	0
    bsf	    banderas,	1
    movf    display_var+1, W
    movwf   PORTC
    bsf	    PORTD,  1
    return
 
 ;centena   
display2:
    bcf	    banderas,	1
    bsf	    banderas,	2
    movf    display_var+2, W
    movwf   PORTC
    bsf   PORTD,  2
    
    return 
     
   
 ;---------------- CODIGO PRINCIPAL -------------------------------------
 
    
PSECT code, delta=2, abs 
ORG 100h	 ;posicion del codigo 100
 
;-------------------------- tabla para display  ------------------------
tabla:
    clrf    PCLATH
    bsf	    PCLATH, 0	;PCLATH =01    PCL=02
    andlw   0x0f
    addwf   PCL		;PC = PCLATH + PCL + W
    retlw   00111111B	;0
    retlw   00000110B	;1
    retlw   01011011B	;2
    retlw   01001111B	;3
    retlw   01100110B	;4
    retlw   01101101B	;5
    retlw   01111101B	;6
    retlw   00000111B	;7 
    retlw   01111111B	;8
    retlw   01101111B	;9
    retlw   01110111B	;A
    retlw   01111100B   ;B
    retlw   00111001B	;C
    retlw   01011110B	;D
    retlw   01111001B	;E
    retlw   01110001B	;F

;---------------------------  CONFIGURACIÓN  --------------------------------;

main:
    call config_io
    call config_reloj
    call config_timer0
    call config_iocrb
    call config_interrupcion
    banksel PORTA	     
    
;---------------------------  LOOP PRINCIPAL -------------------------------- 

loop:
    movf    PORTA, W  
    call    cente
    call    preparar_displays
    goto    loop 

;------------------- SUB RUTINAS ----------------------------------------------   
preparar_displays: 
    ;Se preparan los display para como apareceran 
    movf    unit, W
    call    tabla
    movwf   display_var+0
    
    movf    decena, W
    call    tabla
    movwf   display_var+1
    
    movf    centena,	W
    call    tabla
    movwf   display_var+2
    return

config_io:
    ; configuracion de entradas y salidas
    banksel ANSEL	
    clrf    ANSEL	
    clrf    ANSELH	; digitales
			
    
    banksel TRISA	
    clrf    TRISA	;PORTA como salida 
    clrf    TRISC	;PORTC como salida 
    
    bcf     TRISD,0	; PORTD 0 como salida para transistores
    bcf     TRISD,1	; PORTD 1 como salida para transistores
    bcf	    TRISD, 2	; PORTD 2 como salida para transistores
    
    bsf	    TRISB, UP     ;Pínes 6 y 7 del PUERTO B como entradas
    bsf	    TRISB, DOWN	
    
    bcf	    OPTION_REG, 7 ;activar los bit del puerto B como pull up
			   
    bsf	    WPUB, UP     ;pines 6 y 7 como pull up
    bsf	    WPUB, DOWN
    
    banksel PORTA	
    clrf    PORTA	;clear PORTA
    clrf    PORTC	;clear PORTC
    clrf    PORTD	;clear PORTD
    return  
    
config_reloj: ;configurar el oscilador
    banksel OSCCON 
		    
		    ;se configura a 2 MHz =101
    bsf IRCF2	    ;1 
    bcf IRCF1	    ; 0
    bsf IRCF0	    ; 1
    bsf SCS	   
    return
    
config_timer0: ;reloj interno
    banksel TRISA   
    bcf	    T0CS    ;colocar el reloj interno
    bcf	    PSA	    ;assignar el prescaler para el modulo timer0
    bsf	    PS2
    bsf	    PS1
    bsf	    PS0	    ;PS = 111, prescalrer = 1:256 
    banksel PORTA
    rest_tmr0
    return 
    
config_iocrb:
    banksel TRISA  
    bsf	    IOCB, UP     
    bsf	    IOCB, DOWN 	
    
    banksel PORTA
    movf    PORTB, W 
    bcf	    RBIF     ;la bandera se enciende si la condicion aun no termina
    return
    
config_interrupcion:
    bsf	    GIE	    ;HABILITA interrupciones no enmascaradas
    bsf	    T0IE    ;habilitar TMR0 1
    bcf	    T0IF    ;clear la bandera 1
    bsf	    RBIE    ;habilitar puerto B
    bcf	    RBIF    ;limpiar la bandera de interupcion
    return 
    
cente:	;centenas 
    wdivl   100	    ;llamar macro 
    movf    cociente, W
    movwf   centena
    movf    residuo,	W
    
decenas:    ;decenas 
    wdivl   10	;llamar macro
    movf    cociente,	W
    movwf   decena
    movf    residuo,	W
    
unidades:   ;unidades
    movwf   unit
    return   
end