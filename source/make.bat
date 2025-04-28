arm-elf-as -g core.s -o core.o --defsym debug=0
if errorlevel 1 goto end

arm-elf-ld -T lnkscript.txt core.o -o core.elf
if errorlevel 1 goto end

arm-elf-objcopy -O binary core.elf snezzi.gba
if errorlevel 1 goto end

gcc snezzi.c -o snezzi.exe
if errorlevel 1 goto end

:end