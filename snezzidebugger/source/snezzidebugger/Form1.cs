using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

namespace snezzidebugger
{
    
    public partial class Form1 : Form
    {
        public const bool releaseBuild = true;

        public Form1()
        {
            InitializeComponent();
        }


        private const string tag = "LINE----BRK";
        private int offset = 0;

        ProcessMemoryReaderLib.ProcessMemoryReader reader = null;

        private void button1_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process[] p = System.Diagnostics.Process.GetProcesses();

            int processIdx = 0;
            for( ; processIdx<p.Length; processIdx++ )
            {
                try
                {
                    if (p[processIdx].MainModule.FileName.ToLower().EndsWith(comboBox2.Text.ToLower()))
                        break;
                }
                catch
                {
                }
            }
            if (processIdx == p.Length)
            {
                label1.Text = "Unable to attach to gameboy emulator";
                return;
            }

            label1.Text = "Searching...";

            reader = new ProcessMemoryReaderLib.ProcessMemoryReader();
            reader.ReadProcess = p[processIdx];

            reader.OpenProcess();
            for (int i = 0; i < 0x4000000; i += 100000)
            {
                int bytesRead = 0;
                byte[] buffer = reader.ReadProcessMemory(new IntPtr(i), 100100, out bytesRead);
                if (buffer != null)
                {
                    for (int j = 0; j < buffer.Length - tag.Length; j++)
                    {
                        bool found = true;
                        for (int k = 0; k < tag.Length; k++)
                            if (buffer[j + k] != (int)tag[k])
                            {
                                found = false;
                                break;
                            }
                        if (found)
                        {
                            offset = i + j;
                            label1.Text = offset.ToString("X8");
                            textBox1.Clear();
                            showState();

                            label1.Text = "Attached to Snezziboy Emulator";
                            panel2.Enabled = true;
                            return;
                        }
                    }
                }
            }

            label1.Text = "Unable to attach to Snezziboy Emulator (either Snezziboy is not running or is not built in debug mode)";
            
        }

        private void button6_Click(object sender, EventArgs e)
        {
            textBox1.Text = "";
        }

        string opcodeStr = "";
        private void printf(string format, params int[] operand)
        {
            StringBuilder s = new StringBuilder(format.Replace("%02X", "{X:X2}") );
            int x1 = s.ToString().IndexOf("X:X2}");
            if (x1 >= 0)
                s[x1] = '0';

            int x2 = s.ToString().IndexOf("X:X2}");
            if (x2 >= 0)
                s[x2] = '1';

            int x3 = s.ToString().IndexOf("X:X2}");
            if (x3 >= 0)
                s[x3] = '2';

            if( operand.Length==0 )
                opcodeStr = String.Format(s.ToString());
            if (operand.Length == 1)
                opcodeStr = String.Format(s.ToString(), operand[0]);
            if (operand.Length == 2)
                opcodeStr = String.Format(s.ToString(), operand[0], operand[1]);
            if (operand.Length == 3)
                opcodeStr = String.Format(s.ToString(), operand[0], operand[1], operand[2]);
        }

        private string opcode(byte[] buffer)
        {
            opcodeStr = "";
            int flags = buffer[0x18];
            byte[] operand = new byte[3];
            operand[0] = buffer[0x21];
            operand[1] = buffer[0x22];
            operand[2] = buffer[0x23];

            switch (buffer[0x20])
            {
                case 0x00: printf("BRK $%02X    ", operand[0]); break;
                case 0x01: printf("ORA ($%02X,X)", operand[0]); break;
                case 0x02: printf("COP $%02X    ", operand[0]); break;
                case 0x03: printf("ORA $%02X,S  ", operand[0]); break;
                case 0x04: printf("TSB $%02X    ", operand[0]); break;
                case 0x05: printf("ORA $%02X    ", operand[0]); break;
                case 0x06: printf("ASL $%02X    ", operand[0]); break;
                case 0x07: printf("ORA [$%02X]  ", operand[0]); break;
                case 0x08: printf("PHP         "); break;
                case 0x09:
                    {
                        if ((flags & 0x20)>0) printf("ORA #$%02X   ", operand[0]);
                        else printf("ORA #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//may break on 16bit accumulator
                case 0x0A: printf("ASL        "); break;
                case 0x0B: printf("PHD        "); break;
                case 0x0C: printf("TSB $%02X%02X  ", operand[1], operand[0]); break;
                case 0x0D: printf("ORA $%02X%02X  ", operand[1], operand[0]); break;
                case 0x0E: printf("ASL $%02X%02X  ", operand[1], operand[0]); break;
                case 0x0F: printf("ORA $%02X%02X%02X", operand[2], operand[1], operand[0]); break;

                case 0x10: printf("BPL $%02X    ", operand[0]); break;
                case 0x11: printf("ORA ($%02X),Y", operand[0]); break;
                case 0x12: printf("ORA ($%02X)  ", operand[0]); break;
                case 0x13: printf("ORA ($%02X,S),Y", operand[0]); break;
                case 0x14: printf("TRB $%02X    ", operand[0]); break;
                case 0x15: printf("ORA $%02X,X  ", operand[0]); break;
                case 0x16: printf("ASL $%02X,X  ", operand[0]); break;
                case 0x17: printf("ORA [$%02X],Y", operand[0]); break;
                case 0x18: printf("CLC        "); break;
                case 0x19: printf("ORA $%02X%02X,Y", operand[1], operand[0]); break;
                case 0x1A: printf("INC        "); break;
                case 0x1B: printf("TCS        "); break;
                case 0x1C: printf("TRB $%02X%02X  ", operand[1], operand[0]); break;
                case 0x1D: printf("ORA $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0x1E: printf("ASL $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0x1F: printf("ORA $%02X%02X%02X,X", operand[2], operand[1], operand[0]); break;

                case 0x20: printf("JSR $%02X%02X  ", operand[1], operand[0]); break;
                case 0x21: printf("AND ($%02X,X)    ", operand[0]); break;
                case 0x22: printf("JSR $%02X%02X%02X", operand[2], operand[1], operand[0]); break;
                case 0x23: printf("AND $%02X,S  ", operand[0]); break;
                case 0x24: printf("BIT $%02X    ", operand[0]); break;
                case 0x25: printf("AND $%02X    ", operand[0]); break;
                case 0x26: printf("ROL $%02X    ", operand[0]); break;
                case 0x27: printf("AND [$%02X]  ", operand[0]); break;
                case 0x28: printf("PLP        "); break;
                case 0x29:
                    {
                        if ((flags & 0x20)>0) printf("AND #$%02X   ", operand[0]);
                        else printf("AND #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//may break on 16bit accumulator
                case 0x2A: printf("ROL        "); break;
                case 0x2B: printf("PLD        "); break;
                case 0x2C: printf("BIT $%02X%02X  ", operand[1], operand[0]); break;
                case 0x2D: printf("AND $%02X%02X  ", operand[1], operand[0]); break;
                case 0x2E: printf("ROL $%02X%02X  ", operand[1], operand[0]); break;
                case 0x2F: printf("AND $%02X%02X%02X", operand[2], operand[1], operand[0]); break;

                case 0x30: printf("BMI $%02X    ", operand[0]); break;
                case 0x31: printf("AND ($%02X),Y", operand[0]); break;
                case 0x32: printf("AND ($%02X)    ", operand[0]); break;
                case 0x33: printf("AND ($%02X,S),Y", operand[0]); break;
                case 0x34: printf("BIT $%02X,X    ", operand[0]); break;
                case 0x35: printf("AND $%02X,X    ", operand[0]); break;
                case 0x36: printf("ROL $%02X,X    ", operand[0]); break;
                case 0x37: printf("AND [$%02X],Y", operand[0]); break;
                case 0x38: printf("SEC        "); break;
                case 0x39: printf("AND $%02X%02X,Y  ", operand[1], operand[0]); break;
                case 0x3A: printf("DEC        "); break;
                case 0x3B: printf("TSC        "); break;
                case 0x3C: printf("BIT $%02X%02X,X", operand[1], operand[0]); break;
                case 0x3D: printf("AND $%02X%02X,X", operand[1], operand[0]); break;
                case 0x3E: printf("ROL $%02X%02X,X", operand[1], operand[0]); break;
                case 0x3F: printf("AND $%02X%02X%02X,X", operand[2], operand[1], operand[0]); break;
                
                case 0x40: printf("RTI        "); break;
                case 0x41: printf("EOR ($%02X,X)", operand[0]); break;
                case 0x42: printf("WDM $%02X    ", operand[0]); break;//|16 ?
                case 0x43: printf("EOR ($%02X,S)", operand[0]); break;
                case 0x44: printf("MVP $%02X%02X  ", operand[1], operand[0]); break;
                case 0x45: printf("EOR $%02X    ", operand[0]); break;
                case 0x46: printf("LSR $%02X    ", operand[0]); break;
                case 0x47: printf("EOR [$%02X]  ", operand[0]); break;
                case 0x48: printf("PHA        "); break;
                case 0x49:
                    {
                        if ((flags & 0x20)>0) printf("EOR #$%02X   ", operand[0]);
                        else printf("EOR #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//may break on 16bit accumulator
                case 0x4A: printf("LSR        "); break;
                case 0x4B: printf("PHK        "); break;
                case 0x4C: printf("JMP $%02X%02X  ", operand[1], operand[0]); break;
                case 0x4D: printf("EOR $%02X%02X  ", operand[1], operand[0]); break;
                case 0x4E: printf("LSR $%02X%02X  ", operand[1], operand[0]); break;
                case 0x4F: printf("EOR $%02X%02X%02X", operand[2], operand[1], operand[0]); break;

                case 0x50: printf("BVC $%02X    ", operand[0]); break;
                case 0x51: printf("EOR ($%02X),Y  ", operand[0]); break;
                case 0x52: printf("EOR ($%02X)    ", operand[0]); break;
                case 0x53: printf("EOR ($%02X,S),Y", operand[0]); break;
                case 0x54: printf("MVN $%02X%02X  ", operand[1], operand[0]); break;
                case 0x55: printf("EOR $%02X,X  ", operand[0]); break;
                case 0x56: printf("LSR $%02X,X  ", operand[0]); break;
                case 0x57: printf("EOR [$%02X],Y", operand[0]); break;
                case 0x58: printf("CLI        "); break;
                case 0x59: printf("EOR $%02X%02X,Y  ", operand[1], operand[0]); break;
                case 0x5A: printf("PHY        "); break;
                case 0x5B: printf("TCD        "); break;
                case 0x5C: printf("JMP $%02X%02X%02X", operand[2], operand[1], operand[0]); break;
                case 0x5D: printf("EOR $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0x5E: printf("LSR $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0x5F: printf("EOR $%02X%02X%02X,X", operand[2], operand[1], operand[0]); break;

                case 0x60: printf("RTS        "); break;
                case 0x61: printf("ADC ($%02X,X)    ", operand[0]); break;
                case 0x62: printf("PER $%02X%02X  ", operand[1], operand[0]); break;
                case 0x63: printf("ADC $%02X,S    ", operand[0]); break;
                case 0x64: printf("STZ $%02X    ", operand[0]); break;
                case 0x65: printf("ADC $%02X    ", operand[0]); break;
                case 0x66: printf("ROR $%02X    ", operand[0]); break;
                case 0x67: printf("ADC [$%02X]  ", operand[0]); break;
                case 0x68: printf("PLA        "); break;
                case 0x69:
                    {
                        if ((flags & 0x20)>0) printf("ADC #$%02X   ", operand[0]);
                        else printf("ADC #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//may break on 16bit Accumultaor
                case 0x6A: printf("ROR        "); break;
                case 0x6B: printf("RTL        "); break;
                case 0x6C: printf("JMP ($%02X%02X)  ", operand[1], operand[0]); break;
                case 0x6D: printf("ADC $%02X%02X  ", operand[1], operand[0]); break;
                case 0x6E: printf("ROR $%02X%02X  ", operand[1], operand[0]); break;
                case 0x6F: printf("ADC $%02X%02X%02X", operand[2], operand[1], operand[0]); break;

                case 0x70: printf("BVS $%02X    ", operand[0]); break;
                case 0x71: printf("ADC ($%02X),Y    ", operand[0]); break;
                case 0x72: printf("ADC ($%02X)    ", operand[0]); break;
                case 0x73: printf("ADC ($%02X,S),Y    ", operand[0]); break;
                case 0x74: printf("STZ $%02X,X    ", operand[0]); break;
                case 0x75: printf("ADC $%02X,X   ", operand[0]); break;
                case 0x76: printf("ROR $%02X,X    ", operand[0]); break;
                case 0x77: printf("ADC [$%02X],Y    ", operand[0]); break;
                case 0x78: printf("SEI        "); break;
                case 0x79: printf("ADC $%02X%02X,Y  ", operand[1], operand[0]); break;
                case 0x7A: printf("PLY        "); break;
                case 0x7B: printf("TDC        "); break;
                case 0x7C: printf("JMP ($%02X%02X,X)  ", operand[1], operand[0]); break;
                case 0x7D: printf("ADC $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0x7E: printf("ROR $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0x7F: printf("ADC $%02X%02X%02X,X", operand[2], operand[1], operand[0]); break;

                case 0x80: printf("BRA $%02X    ", operand[0]); break;
                case 0x81: printf("STA ($%02X,X)", operand[0]); break;
                case 0x82: printf("BRL $%02X%02X  ", operand[1], operand[0]); break;
                case 0x83: printf("STA $%02X,S    ", operand[0]); break;
                case 0x84: printf("STY $%02X    ", operand[0]); break;
                case 0x85: printf("STA $%02X    ", operand[0]); break;
                case 0x86: printf("STX $%02X    ", operand[0]); break;
                case 0x87: printf("STA [$%02X]    ", operand[0]); break;
                case 0x88: printf("DEY        "); break;
                case 0x89:
                    {
                        if ((flags & 0x20)>0) printf("BIT #$%02X   ", operand[0]);
                        else printf("BIT #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//break on 16bit Accumultaor
                case 0x8A: printf("TXA        "); break;
                case 0x8B: printf("PHB        "); break;
                case 0x8C: printf("STY $%02X%02X  ", operand[1], operand[0]); break;
                case 0x8D: printf("STA $%02X%02X  ", operand[1], operand[0]); break;
                case 0x8E: printf("STX $%02X%02X  ", operand[1], operand[0]); break;
                case 0x8F: printf("STA $%02X%02X%02X", operand[2], operand[1], operand[0]); break;

                case 0x90: printf("BCC $%02X    ", operand[0]); break;
                case 0x91: printf("STA ($%02X),Y    ", operand[0]); break;
                case 0x92: printf("STA ($%02X)    ", operand[0]); break;
                case 0x93: printf("STA ($%02X,S),Y    ", operand[0]); break;
                case 0x94: printf("STY $%02X,X    ", operand[0]); break;
                case 0x95: printf("STA $%02X,X    ", operand[0]); break;
                case 0x96: printf("STX $%02X,Y    ", operand[0]); break;
                case 0x97: printf("STA [$%02X],Y    ", operand[0]); break;
                case 0x98: printf("TYA        "); break;
                case 0x99: printf("STA $%02X%02X,Y  ", operand[1], operand[0]); break;
                case 0x9A: printf("TXS        "); break;
                case 0x9B: printf("TXY        "); break;
                case 0x9C: printf("STZ $%02X%02X  ", operand[1], operand[0]); break;
                case 0x9D: printf("STA $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0x9E: printf("STZ $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0x9F: printf("STA $%02X%02X%02X,X", operand[2], operand[1], operand[0]); break;
                
                case 0xA0:
                    {
                        if ((flags & 0x10)>0) printf("LDY #$%02X   ", operand[0]);
                        else printf("LDY #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//break on 8-bit index registers
                case 0xA1: printf("LDA ($%02X,X)    ", operand[0]); break;
                case 0xA2:
                    {
                        if ((flags & 0x10)>0) printf("LDX #$%02X   ", operand[0]);
                        else printf("LDX #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//break on 8-bit index registers
                case 0xA3: printf("LDA $%02X,S    ", operand[0]); break;
                case 0xA4: printf("LDY $%02X    ", operand[0]); break;
                case 0xA5: printf("LDA $%02X    ", operand[0]); break;
                case 0xA6: printf("LDX $%02X    ", operand[0]); break;
                case 0xA7: printf("LDA [$%02X]    ", operand[0]); break;
                case 0xA8: printf("TAY        "); break;
                case 0xA9:
                    {
                        if ((flags & 0x20)>0) printf("LDA #$%02X   ", operand[0]);
                        else printf("LDA #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//break on 16bit Accumultaor
                case 0xAA: printf("TAX        "); break;
                case 0xAB: printf("PLB        "); break;
                case 0xAC: printf("LDY $%02X%02X  ", operand[1], operand[0]); break;
                case 0xAD: printf("LDA $%02X%02X  ", operand[1], operand[0]); break;
                case 0xAE: printf("LDX $%02X%02X  ", operand[1], operand[0]); break;
                case 0xAF: printf("LDA $%02X%02X%02X", operand[2], operand[1], operand[0]); break;

                case 0xB0: printf("BCS $%02X    ", operand[0]); break;
                case 0xB1: printf("LDA ($%02X),Y    ", operand[0]); break;
                case 0xB2: printf("LDA ($%02X)    ", operand[0]); break;
                case 0xB3: printf("LDA ($%02X,S),Y    ", operand[0]); break;
                case 0xB4: printf("LDY $%02X,X    ", operand[0]); break;
                case 0xB5: printf("LDA $%02X,X    ", operand[0]); break;
                case 0xB6: printf("LDX $%02X,Y    ", operand[0]); break;
                case 0xB7: printf("LDA [$%02X],Y    ", operand[0]); break;
                case 0xB8: printf("CLV        "); break;
                case 0xB9: printf("LDA $%02X%02X,Y  ", operand[1], operand[0]); break;
                case 0xBA: printf("TSX        "); break;
                case 0xBB: printf("TYX        "); break;
                case 0xBC: printf("LDY $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0xBD: printf("LDA $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0xBE: printf("LDX $%02X%02X,Y  ", operand[1], operand[0]); break;
                case 0xBF: printf("LDA $%02X%02X%02X,X", operand[2], operand[1], operand[0]); break;

                case 0xC0:
                    {
                        if ((flags & 0x10)>0) printf("CPY #$%02X   ", operand[0]);
                        else printf("CPY #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//break on 8-bit index registers
                case 0xC1: printf("CMP ($%02X,X)    ", operand[0]); break;
                case 0xC2: printf("REP #$%02X   ", operand[0]); break;
                case 0xC3: printf("CMP $%02X,S    ", operand[0]); break;
                case 0xC4: printf("CPY $%02X    ", operand[0]); break;
                case 0xC5: printf("CMP $%02X    ", operand[0]); break;
                case 0xC6: printf("DEC $%02X    ", operand[0]); break;
                case 0xC7: printf("CMP [$%02X]    ", operand[0]); break;
                case 0xC8: printf("INY        "); break;
                case 0xC9:
                    {
                        if ((flags & 0x20)>0) printf("CMP #$%02X   ", operand[0]);
                        else printf("CMP #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//break on 16bit Accumultaor
                case 0xCA: printf("DEX        "); break;
                case 0xCB: printf("WAI        "); break;
                case 0xCC: printf("CPY $%02X%02X  ", operand[1], operand[0]); break;
                case 0xCD: printf("CMP $%02X%02X  ", operand[1], operand[0]); break;
                case 0xCE: printf("DEC $%02X%02X  ", operand[1], operand[0]); break;
                case 0xCF: printf("CMP $%02X%02X%02X", operand[2], operand[1], operand[0]); break;

                case 0xD0: printf("BNE $%02X    ", operand[0]); break;
                case 0xD1: printf("CMP ($%02X),Y    ", operand[0]); break;
                case 0xD2: printf("CMP ($%02X)    ", operand[0]); break;
                case 0xD3: printf("CMP ($%02X,S),Y    ", operand[0]); break;
                case 0xD4: printf("PEI $%02X    ", operand[0]); break;
                case 0xD5: printf("CMP $%02X,X    ", operand[0]); break;
                case 0xD6: printf("DEC $%02X,X    ", operand[0]); break;
                case 0xD7: printf("CMP [$%02X],Y    ", operand[0]); break;
                case 0xD8: printf("CLD        "); break;
                case 0xD9: printf("CMP $%02X%02X,Y  ", operand[1], operand[0]); break;
                case 0xDA: printf("PHX        "); break;
                case 0xDB: printf("STP        "); break;
                case 0xDC: printf("JML [$%02X%02X]  ", operand[1], operand[0]); break;
                case 0xDD: printf("CMP $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0xDE: printf("DEC $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0xDF: printf("CMP $%02X%02X%02X,X", operand[2], operand[1], operand[0]); break;
                
                case 0xE0:
                    {
                        if ((flags & 0x10)>0) printf("CPX #$%02X   ", operand[0]);
                        else printf("CPX #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//break on 8-bit index registers
                case 0xE1: printf("SBC ($%02X,X)    ", operand[0]); break;
                case 0xE2: printf("SEP #$%02X   ", operand[0]); break;
                case 0xE3: printf("SBC $%02X,S    ", operand[0]); break;
                case 0xE4: printf("CPX $%02X    ", operand[0]); break;
                case 0xE5: printf("SBC $%02X    ", operand[0]); break;
                case 0xE6: printf("INC $%02X    ", operand[0]); break;
                case 0xE7: printf("SBC [$%02X]    ", operand[0]); break;
                case 0xE8: printf("INX        "); break;
                case 0xE9:
                    {
                        if ((flags & 0x10)>0) printf("SBC #$%02X   ", operand[0]);
                        else printf("SBC #$%02X%02X ", operand[1], operand[0]);
                        break;
                    }//break on 8-bit index registers
                case 0xEA: printf("NOP        "); break;
                case 0xEB: printf("XBA        "); break;
                case 0xEC: printf("CPX $%02X%02X  ", operand[1], operand[0]); break;
                case 0xED: printf("SBC $%02X%02X  ", operand[1], operand[0]); break;
                case 0xEE: printf("INC $%02X%02X  ", operand[1], operand[0]); break;
                case 0xEF: printf("SBC $%02X%02X%02X", operand[2], operand[1], operand[0]); break;
                
                case 0xF0: printf("BEQ $%02X    ", operand[0]); break;
                case 0xF1: printf("SBC ($%02X),Y    ", operand[0]); break;
                case 0xF2: printf("SBC ($%02X)    ", operand[0]); break;
                case 0xF3: printf("SBC ($%02X,S),Y    ", operand[0]); break;
                case 0xF4: printf("PEA $%02X%02X  ", operand[1], operand[0]); break;
                case 0xF5: printf("SBC $%02X,X    ", operand[0]); break;
                case 0xF6: printf("INC $%02X,X    ", operand[0]); break;
                case 0xF7: printf("SBC [$%02X],Y    ", operand[0]); break;
                case 0xF8: printf("SED        "); break;
                case 0xF9: printf("SBC $%02X%02X,Y  ", operand[1], operand[0]); break;
                case 0xFA: printf("PLX        "); break;
                case 0xFB: printf("XCE        "); break;
                case 0xFC: printf("JSR ($%02X%02X,X)  ", operand[1], operand[0]); break;
                case 0xFD: printf("SBC $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0xFE: printf("INC $%02X%02X,X  ", operand[1], operand[0]); break;
                case 0xFF: printf("SBC $%02X%02X%02X,X", operand[2], operand[1], operand[0]); break;
                default: printf("Error"); break;
            }
            return opcodeStr;
        }

        string lastState = "";

        private string showState()
        {
            return showState(true);
        }

        private string showState(bool show)
        {
            if (reader != null)
            {
                int bytesRead = 0;
                byte[] buffer = reader.ReadProcessMemory(new IntPtr(offset-0x70), 0x100, out bytesRead);

                if (buffer == null)
                {
                    panel2.Enabled = false;
                    return "";
                }

                string state =
                    String.Format("${0:X2}/{1:X2}{2:X2} {3:X2}{4:X2}{5:X2}{6:X2} ", buffer[0x16], buffer[0x15], buffer[0x14],
                    buffer[0x20], buffer[0x21], buffer[0x22], buffer[0x23]);

                state += String.Format( "{0,-15}", opcode(buffer) ) + " | ";

                state +=
                    String.Format("A:{2:X2}{3:X2} ", buffer[0x03], buffer[0x02], buffer[0x01], buffer[0x00]);

                state +=
                    String.Format("X:{2:X2}{3:X2} ", buffer[0x07], buffer[0x06], buffer[0x05], buffer[0x04]);

                state +=
                    String.Format("Y:{2:X2}{3:X2} ", buffer[0x0b], buffer[0x0A], buffer[0x09], buffer[0x08]);

                state +=
                    String.Format("D:{2:X2}{3:X2} ", buffer[0x0f], buffer[0x0e], buffer[0x0d], buffer[0x0c]);

                state +=
                    String.Format("DB:{3:X2} ", buffer[0x27], buffer[0x26], buffer[0x25], buffer[0x24]);

                state +=
                    String.Format("S:{2:X2}{3:X2} ", buffer[0x13], buffer[0x12], buffer[0x11], buffer[0x10]);

                state += "P:";
                state += (buffer[0x19] & 0x01) > 0 ? "E" : "e";
                state += (buffer[0x18] & 0x80) > 0 ? "N" : "n";
                state += (buffer[0x18] & 0x40) > 0 ? "V" : "v";
                state += (buffer[0x18] & 0x20) > 0 ? "M" : "m";
                state += (buffer[0x18] & 0x10) > 0 ? "X" : "x";
                state += (buffer[0x18] & 0x08) > 0 ? "D" : "d";
                state += (buffer[0x18] & 0x04) > 0 ? "I" : "i";
                state += (buffer[0x18] & 0x02) > 0 ? "Z" : "z";
                state += (buffer[0x18] & 0x01) > 0 ? "C" : "c";

                state +=
                    String.Format(" HC:{0:0000} ", buffer[0x28]+buffer[0x29]*256 );

                state +=
                    String.Format("VC:{0:0000} ", buffer[0x2c] + buffer[0x2d] * 256) + "\r\n";

                if (lastState != state && show)
                {
                    textBox1.AppendText(state);
                    textBox1.ScrollToCaret();
                }

                lastState = state;
                return state;
            }
            return "";
        }

        private void runSteps(int steps)
        {
            runSteps(steps, false, false);
        }

        private void runSteps(int steps, bool hidden, bool dontShowAtAll)
        {
            byte[] wbuffer = new byte[1];
            timer1.Enabled = false;
            DateTime start = DateTime.Now;
            StringBuilder accumState = new StringBuilder();
            for (int i = 0; i < steps; i++)
            {
                int bytesRead = 0;
                wbuffer[0] = 1;
                reader.WriteProcessMemory(new IntPtr(offset + 0xC), wbuffer, out bytesRead);

                for (int j = 0; j < 100; j++)
                {
                    System.Threading.Thread.Sleep(1);
                    byte[] buffer = reader.ReadProcessMemory(new IntPtr(offset + 0xC), 1, out bytesRead);
                    if (buffer == null)
                    {
                        i = 1000000;
                        panel2.Enabled = false;
                        break;
                    }
                    if (buffer[0] == 0)
                        break;
                }
                if (i % 500 == 0 && i!=0)
                {
                    Application.DoEvents();
                    TimeSpan s = (DateTime.Now - start);
                    label3.Text = "" + i + " / " + steps + ", Time Elapsed:" + String.Format("{0:HH.mm.ss.f}", s) + ", Time Left:" + String.Format("{0:HH.mm.ss.f}", new TimeSpan((steps-i)*s.Ticks/i) );
                }

                accumState.Append( showState(false) );
                if (!panel2.Enabled)
                    break;
            }
            label3.Text = "Writing to textbox...";
            textBox1.AppendText(accumState.ToString());
            textBox1.ScrollToCaret();
            accumState.Length = 0;
            timer1.Enabled = true;
            label3.Text = "";
        }

        private void runStepsLog(int steps)
        {
            System.IO.StreamWriter sw = new System.IO.StreamWriter("snezzidebugger.log.txt", true);
            timer1.Enabled = false;
            DateTime start = DateTime.Now;
            StringBuilder accumState = new StringBuilder();
            for (int i = 0; i < steps; i++)
            {
                int bytesRead = 0;
                byte[] wbuffer = new byte[1];
                wbuffer[0] = 1;
                reader.WriteProcessMemory(new IntPtr(offset + 0xC), wbuffer, out bytesRead);

                for (int j = 0; j < 100; j++)
                {
                    byte[] buffer = reader.ReadProcessMemory(new IntPtr(offset + 0xC), 1, out bytesRead);
                    if (buffer == null)
                    {
                        i = 1000000;
                        panel2.Enabled = false;
                        break;
                    }
                    if (buffer[0] == 0)
                        break;
                    System.Threading.Thread.Sleep(1);
                }
                if (i % 50 == 0)
                    Application.DoEvents();

                if (i % 50 == 0 && i != 0)
                {
                    TimeSpan s = (DateTime.Now - start);
                    label3.Text = "" + i + " / " + steps + ", Time Elapsed:" + String.Format("{0:HH.mm.ss.f}", s) + ", Time Left:" + String.Format("{0:HH.mm.ss.f}", new TimeSpan((steps - i) * s.Ticks / i));
                    sw.WriteLine(accumState);
                    accumState.Length = 0;
                }

                accumState.Append(showState(false));
            }
            timer1.Enabled = true;
            label3.Text = "";
            sw.WriteLine(accumState);
            sw.Close();
        }

        private void button2_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(1);
        }

        private void button3_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(5);
        }

        private void button4_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(10);
        }

        private void button5_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(20);
        }

        private void button7_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(20, true, false);
        }

        private void button8_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(100);

        }

        private void button9_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(500);
        }

        private void button11_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            int bytesRead;
            byte[] wbuffer = new byte[] { 1, 0, 0, 0 };
            reader.WriteProcessMemory(new IntPtr(offset + 0xC), wbuffer, out bytesRead);
            showState();

            panel1.Enabled = true;
        }

        //-----------------------------------------------------------
        // run with breakpoint (slower)
        //-----------------------------------------------------------

        private void button10_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);

        }

        //-----------------------------------------------------------
        // run 
        //-----------------------------------------------------------
        private void button12_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);

            if (!checkBox1.Checked)
            {
                int bytesRead;
                byte[] wbuffer = new byte[] { 1, 1, 0, 0 };
                reader.WriteProcessMemory(new IntPtr(offset + 0xC), wbuffer, out bytesRead);
                showState();
            }
            else
            {
                int bytesRead;
                int hexv = 0;
                try
                {
                    hexv = Convert.ToInt32(textBox2.Text, 16);
                }
                catch
                {
                }

                byte[] wbuffer = new byte[] { 1, ((byte)(hexv % 256)), (byte)((hexv / 256) % 256), (byte)((hexv / 65536) % 256) };
                reader.WriteProcessMemory(new IntPtr(offset + 0xC), wbuffer, out bytesRead);
                timer1.Enabled = true;
            }

            panel1.Enabled = false;
        }

        private void textBox2_TextChanged(object sender, EventArgs e)
        {

        }

        private void timer1_Tick(object sender, EventArgs e)
        {
            showState();
        }

        private void button7_Click_1(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(5000);
        }

        private void button13_Click(object sender, EventArgs e)
        {
            new Form2().Show();
        }

        private void button14_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(10000);
        }

        private void button15_Click(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(20000);
        }

        private void button14_Click_1(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runStepsLog(Convert.ToInt32(comboBox1.Items[comboBox1.SelectedIndex].ToString()));
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            comboBox2.SelectedIndex = 0;
            panel2.Enabled = false;
        }

        private void button10_Click_1(object sender, EventArgs e)
        {
            if (offset == 0)
                button1_Click(null, null);
            runSteps(10000);
        }

        private void button15_Click_1(object sender, EventArgs e)
        {
            
        }
    }
}