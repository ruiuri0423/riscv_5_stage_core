ENTRY( _start )

__text_size = 4096;
PROVIDE( _text_size = __text_size );

__data_size = 2048;
PROVIDE( _data_size = __data_size );

__stack_size = 2048;
PROVIDE( _stack_size = __stack_size );

MEMORY
{
    FLASH (rx) : ORIGIN = 0xFFFF0000, LENGTH = __text_size
    RAM (xrw) : ORIGIN = 0xFFFF1000, LENGTH = __data_size + __stack_size
}

SECTIONS
{   
    .text ORIGIN(FLASH) : 
    { 
        *(.text) 
        . = ORIGIN(FLASH) + LENGTH(FLASH);
    } >FLASH

    .data ORIGIN(RAM):
    {
        *(.data)
        . = ORIGIN(RAM) + __data_size;
    } >RAM

    .stack ORIGIN(RAM) + LENGTH(RAM) - __stack_size:
    {
        . = ALIGN(4);
        PROVIDE( _susrstack = . );
        . = . + __stack_size;
        PROVIDE( _eusrstack = . );
    } >RAM
}
