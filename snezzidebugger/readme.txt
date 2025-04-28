Snezziboy Debugger Guide
-----------------------------------------------------------

Contents

1. Licensing
2. How to compile
3. How to use


1. Licensing
~~~~~~~~~~~~~~~~~~~~~

The Snezziboy Debugger ("Program") is:

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


2. How to Compile
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Snezziboy debugger was developed with Visual C# Express,
using .NET 2.0 framework. The Visual Studio solution (.sln)
is provided and the entire project can be opened with that. 
Build the project in Visual C# Express to produce the 
executable.


3. How to Use
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Snezziboy Debugger works in more ways than one similar to the 
VBADump for SNES Advance, but it supports more advanced features 
such as:

  - Steps into each individual 65816 instruction
  - Shows the current horizontal count (HC) and 
    the vertical scanline (VC)
  - Allows running with trace
  - Allows running with breakpoint
  - As an advance feature it allows a comparison between
    Snes9x (Geiger build) logs and Snezziboy Debugger trace logs.


To use the debugger:

1. Build the SNES ROM using the Snezziboy Builder (Debug Version).
   That is, drag the SNES ROM onto the snezzid.exe file.

2. Open the .GBA file that the Snezziboy Builder has created with
   VisualBoyAdvance

3. Double-click on snezzidebugger to run the Snezziboy Debugger.

4. In the dropdown list on the top right of the window, select 
   "VisualBoyAdvance.exe" and click "Attach to Emulator"

5. The first instruction waiting to execute appears in the trace
   window, and all buttons below become enabled for your
   input.

There are 3 modes of running an SNES program:

STEP MODE

6. To step into the 65816 assembly code line by line, use the 
   "1" button. You can step into 
       5 lines, 
       10 lines, 
       20 lines,
       and up to a 10000 lines of code 
   with the click of one button. 

   This is the slowest mode of tracing the SNES program, and is
   especially useful when you are searching for the repetitive
   code that can be speed-hacked.

RUN WITH TRACE MODE

7. To run with the trace, tick the "Trace and Breakpoint" 
   checkbox and leave the breakpoint at "FFFFFF". Then click "Run",
   to see the SNES program run with the trace output to the trace
   window once every 1024 instructions executed. 

   This runs faster than the step mode, and is useful when you 
   would like to skip parts of the code quickly, and yet be able 
   to have a sense of where the SNES program is currently running.

RUN WITHOUT TRACE MODE

8. To run without the trace, untick the "Trace and Breakpoint"
   checkbox, then click "Run".

   This runs the fastest and slightly slower than the speed of 
   the Snezziboy emulator in non-debug mode, and is useful for 
   playing through the game. 

