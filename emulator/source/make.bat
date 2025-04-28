echo Compiling the Snezziboy Emulator

arm-elf-as -g core.s -o core.o --defsym debug=0
if errorlevel 1 goto end

arm-elf-ld -T lnkscript.txt core.o -o core.elf
if errorlevel 1 goto end

arm-elf-objcopy -O binary core.elf snezzi.gba
if errorlevel 1 goto end

gcc snezzi.c -o snezzi.exe
if errorlevel 1 goto end

echo Compiling the Snezziboy Emulator (Debug Build)

arm-elf-as -g core.s -o core.o --defsym debug=1
if errorlevel 1 goto end

arm-elf-ld -T lnkscript.txt core.o -o core.elf
if errorlevel 1 goto end

arm-elf-objcopy -O binary core.elf snezzid.gba
if errorlevel 1 goto end

gcc snezzi.c -o snezzid.exe -DDEBUG
if errorlevel 1 goto end

