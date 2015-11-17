\
\ Blinking LED example in FORTH
\

: '-' 45 ;
: '.' 46 ;

\
\ RPi-specific definitions
\

16# 2000B420 CONSTANT ARM_TIMER_CNT

\ us@ ( -- t ) fetch microsecond timer value
: us@ ARM_TIMER_CNT @ ;

: usecs ;               \ usecs ( n -- dt ) convert microseconds to timer offset
: msecs 1000 * ;        \ msecs ( n -- dt ) convert milliseconds to timer offset
: secs 1000000 * ;      \ secs ( n -- dt ) convert seconds to timer offset

: us \ ( dt -- ) busy-wait until dt microseconds elapse
        us@ +                   \ timeout = current + dt
        BEGIN
                DUP             \ copy timeout
                us@ -           \ past|future = timeout - current
                0<=             \ loop until not future
        UNTIL
        DROP                    \ drop timeout
;

16# 20200004 CONSTANT GPFSEL1           \ GPIO function select (pins 10..19)
16# 001C0000 CONSTANT GPIO16_FSEL       \ GPIO pin 16 function select mask
16# 00040000 CONSTANT GPIO16_OUT        \ GPIO pin 16 function is output

GPFSEL1 @               \ read GPIO function selection
GPIO16_FSEL INVERT AND  \ clear function for pin 16
GPIO16_OUT OR           \ set function to output
GPFSEL1 !               \ write GPIO function selection

16# 2020001C CONSTANT GPSET0            \ GPIO pin output set (pins 0..31)
16# 20200028 CONSTANT GPCLR0            \ GPIO pin output clear (pins 0..31)
16# 00010000 CONSTANT GPIO16_PIN        \ GPIO pin 16 set/clear

: +gpio16 GPIO16_PIN GPSET0 ! ; \ set GPIO pin 16
: -gpio16 GPIO16_PIN GPCLR0 ! ; \ clear GPIO pin 16

: LED_ON -gpio16 ;              \ turn on ACT/OK LED (clear 16)
: LED_OFF +gpio16 ;             \ turn off ACT/OK LED (set 16)

\
\ Morse code (http://en.wikipedia.org/wiki/Morse_code)
\

: units 50 msecs * ;            \ units ( n -- dt ) convert dot-units to timer offset
: eoc 1 units us ;              \ end of character
: dit                           \ dot
        '.' EMIT                \       print dot
        LED_ON
        1 units us              \       wait 1 unit time
        LED_OFF
        eoc                     \ end
;
: dah                           \ dash
        '-' EMIT                \       print dash
        LED_ON
        3 units us              \       wait 3 unit times
        LED_OFF
        eoc                     \ end
;
: eol SPACE 2 units us ;        \ end of letter (assumes preceeding eoc)
: ___ eol eol ;                 \ word-break space (assumes preceeding eol)
: _C_ dah dit dah dit eol ;
: _D_ dah dit dit eol ;
: _E_ dit eol ;
: _M_ dah dah eol ;
: _O_ dah dah dah eol ;
: _R_ dit dah dit eol ;
: _S_ dit dit dit eol ;
: _SOS_ dit dit dit dah dah dah dit dit dit eol ;

_M_ _O_ _R_ _S_ _E_ ___ _C_ _O_ _D_ _E_
