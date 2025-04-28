Snezziboy User Guide
-----------------------------------------------------------

Contents

1. Licensing
2. Building Snezziboy



1. Licensing
~~~~~~~~~~~~~~~~~~~~~

The Snezziboy Emulator ("Program") is:

Copyright (C) 2006 bubble2k

This program is free software; you can redistribute it and/or 
modify it under the terms of the GNU General Public License as 
published by the Free Software Foundation; either version 2 of 
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, 
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
GNU General Public License for more details.

You should have received a copy of the GNU General Public 
License along with this program; if not, write to the Free 
Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, 
MA 02111-1307 USA


2. Building Snezziboy
~~~~~~~~~~~~~~~~~~~~~

There are two components of Snezziboy:
a. Emulation Core
b. Snezziboy Builder


Emulation Core

The emulation core must be built the arm-elf-as assembler with 
the devkitPro for ARM7. The lnkscript for the organization of
the codes and data into the correct IWRAM/ROM spaces has also
been included.


Snezziboy Builder

The Snezziboy has been built with the DJGPP C Compiler. It 
should also compile in any respectable GCC compiler.

