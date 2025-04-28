/*
-------------------------------------------------------------------
Snezziboy Builder 
*/
#define VERSION_NO  "0.23"
/*
Copyright (C) 2006 bubble2k

This program is free software; you can redistribute it and/or 
modify it under the terms of the GNU General Public License as 
published by the Free Software Foundation; either version 2 of 
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, 
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
GNU General Public License for more details.
-------------------------------------------------------------------
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


/*
	joins the snes emulator to the smc/fig file
*/

int snesRomPosition = 0x200000;

char *anchor = "SMEMMAP0";
char *iwramstart = ".IWRAMSTART";
char *iwramend = ".IWRAMEND";

int sramSizeBytes = 1;
int mapper[16];
int memorymap[256*8+2];

#define NOP(v)   0x00000000
#define LRAM(v)  ((v) & 0x0000FFFF) | 0x02000000
#define HRAM(v)  ((v) & 0x0000FFFF) | 0x02010000
#define LROM(v)  (((v) & 0x00007FFF)+(((v)>>1) & ((romSize-1) & ~0x7FFF))) + (0x08000000+snesRomPosition)
#define HROM(v)  (((v) & 0x0000FFFF)+(((v)) & ((romSize-1) & ~0xFFFF))) + (0x08000000+snesRomPosition)
#define ROM(v)   ((v) & 0x000FFFFF) + (0x08000000+snesRomPosition)
#define IO(v)    ((v) & 0x0000FFFF) | 0x80000000
#define SRAM(v)  ((v) & 0x00001FFF) + 0x80006000
#define SVEC(v)  ((v) & 0x000000FF) + 0x0203FF00


int mp = 0;
#define set(x,v) { memorymap[mp++] = (v((x)*0x2000)) -( (x)*0x2000); /*printf( "%8x -> %8x\n", (x)*0x2000, memorymap[x] ); getch();*/ }

#define map(s,e,m0,m1,m2,m3,m4,m5,m6,m7) \
    for( i=s; i<=e; i++ ) \
    { \
        int x = i*8; \
        set( x+0, m0 ) \
        set( x+1, m1 ) \
        set( x+2, m2 ) \
        set( x+3, m3 ) \
        set( x+4, m4 ) \
        set( x+5, m5 ) \
        set( x+6, m6 ) \
        set( x+7, m7 ) \
    } 


void formmemorymap( int loRom, int romSize ) // romSize in bytes
{
    int i,j;
    mp = 0;

    if( loRom==1 )
    {
        // LO ROM
        map( 0x00, 0x2f, LRAM,IO,  IO,  NOP, LROM,LROM,LROM,LROM);
        map( 0x30, 0x3f, LRAM,IO,  IO,  SRAM,LROM,LROM,LROM,LROM);
        map( 0x40, 0x6f, NOP, NOP, NOP, NOP, LROM,LROM,LROM,LROM);
        map( 0x70, 0x7d, SRAM,SRAM,SRAM,SRAM,LROM,LROM,LROM,LROM);
        map( 0x7e, 0x7e, LRAM,LRAM,LRAM,LRAM,LRAM,LRAM,LRAM,LRAM);
        map( 0x7f, 0x7f, HRAM,HRAM,HRAM,HRAM,HRAM,HRAM,HRAM,HRAM);

        map( 0x80, 0xaf, LRAM,IO,  IO,  NOP, LROM,LROM,LROM,LROM);
        map( 0xb0, 0xbf, LRAM,IO,  IO,  SRAM,LROM,LROM,LROM,LROM);
        map( 0xc0, 0xff, LROM,LROM,LROM,LROM,LROM,LROM,LROM,LROM);
    }
    else 
    {
        // HI ROM
        map( 0x00, 0x2f, LRAM,IO,  IO,  NOP, HROM,HROM,HROM,HROM);
        map( 0x30, 0x3f, LRAM,IO,  IO,  SRAM,HROM,HROM,HROM,HROM);
        map( 0x40, 0x6f, HROM,HROM,HROM,HROM,HROM,HROM,HROM,HROM); // fixed v0.23
        map( 0x70, 0x7d, SRAM,SRAM,SRAM,SRAM,HROM,HROM,HROM,HROM);
        map( 0x7e, 0x7e, LRAM,LRAM,LRAM,LRAM,LRAM,LRAM,LRAM,LRAM);
        map( 0x7f, 0x7f, HRAM,HRAM,HRAM,HRAM,HRAM,HRAM,HRAM,HRAM);

        map( 0x80, 0xaf, LRAM,IO,  IO,  NOP, HROM,HROM,HROM,HROM);
        map( 0xb0, 0xbf, LRAM,IO,  IO,  SRAM,HROM,HROM,HROM,HROM);
        map( 0xc0, 0xff, HROM,HROM,HROM,HROM,HROM,HROM,HROM,HROM);
    }
    memorymap[256*8] = sramSizeBytes-1;
    memorymap[256*8+1] = (0x08000000+snesRomPosition);
}

char filePath[1024];

static unsigned long crc_table[256];

void gen_table(void)                /* build the crc table */
{
    unsigned long crc, poly;
    int	i, j;

    poly = 0xEDB88320L;
    for (i = 0; i < 256; i++)
        {
        crc = i;
        for (j = 8; j > 0; j--)
            {
            if (crc & 1)
                crc = (crc >> 1) ^ poly;
            else
                crc >>= 1;
            }
        crc_table[i] = crc;
        }
}


unsigned long get_crc( FILE *fp)    /* calculate the crc value */
{
    register unsigned long crc;
    int ch;

    crc = 0xFFFFFFFF;
    while ((ch = getc(fp)) != EOF)
        crc = (crc>>8) ^ crc_table[ (crc^ch) & 0xFF ];

    return( crc^0xFFFFFFFF );
}


int compute_hex( char *x )
{
    int v = 0;
    while( *x )
    {
        v = v * 16;
        if( *x>='0' && *x<='9' )
            v = v + (*x - '0');
        if( *x>='A' && *x<='F' )
            v = v + (*x - 'A' + 10);
        if( *x>='a' && *x<='f' )
            v = v + (*x - 'a' + 10);
        x++;
    }
    return v;
}

int compute_hex8( char *x )
{
    char h[10];
    h[0] = x[0];
    h[1] = x[1];
    h[2] = 0;
    return compute_hex( h );
}


void patch(int crc, char* buffer)
{
    char datFileName[1024];
    sprintf( datFileName, "%ssnezzi.dat", filePath );

    char string[4096];
    char hex[100];
    FILE *fp = fopen( datFileName, "rb" );
    if( fp==NULL )
    {
        printf( "No patch superdat found. The game may run slowly or not run at all.\n" );
        return;
    }

    sprintf( hex, "%8X", crc );

    while( !feof( fp ) )
    {
        memset( string, 0, 4096 );
        fgets( string, 4095, fp );
        if( string[strlen(string)-1] == 13 || string[strlen(string)-1] == 10 )
            string[strlen(string)-1] = 0;
        if( string[strlen(string)-1] == 13 || string[strlen(string)-1] == 10 )
            string[strlen(string)-1] = 0;

        char *ps = 0;
        char *s = strtok( string, "|" );
        

        if( s )
        {
            // this should be the CRC
            //
            if( strcmp( s, hex )!=0 )
            {
                continue;
            }
        }
        else
            continue;

        // CRC matches, so grab the patch
        //
        int c = 0;
        while( s )
        {
            ps = s;

            if( c==1 )
                printf( "Game        : %s\n", s );
            s = strtok( NULL, "|" );
            c++;
        }

        /*printf( "patch = %s\n", ps );*/

        // ps contains the patch
        //
        printf( "Patch       :\n" );
        s = strtok( ps, "," );
        while( s )
        {
            ps = s + (strlen(s)+1);
            char *addr = strtok( s, "=" );
            char *val = strtok( NULL, "=" );

            int iaddr = compute_hex(addr);
            while( *val && *(val+1) )
            {
                int c = compute_hex8( val );
                buffer[iaddr] = c;
                printf( "%08x = %02x\n", iaddr, c );
                iaddr += 1;
                val += 2;
            }

            s = strtok( ps, "," );
        }
        return;
    }
    printf( "No patch found. The game may run slowly or not run at all.\n" );

}


int find_buffer( char *buffer, char *s, int bufferSize, int strSize )
{
    int i, j;
    for( i=0; i<bufferSize-strSize; i++ )
    {
        int found = 1;
        for( j=0; j<strSize; j++ )
        {
            if( buffer[i+j]!=s[j] )
            {
                found = 0;
                break;
            }
        }
        if( found )
            return i;
    }
    return 0;
}

int main( int argc, char **argv )
{
    printf( "----------------------------------------------------------------\n" );
#ifdef DEBUG 
    printf( " Snezziboy Builder v%s (Debug Build)\n", VERSION_NO );
#else
    printf( " Snezziboy Builder v%s\n", VERSION_NO );
#endif
    printf( " Copyright (C) 2006 bubble2k\n" );
    printf( " \n" );
    printf( " This program is free software; you can redistribute it and/or \n" );
    printf( " modify it under the terms of the GNU General Public License as \n" );
    printf( " published by the Free Software Foundation; either version 2 of \n" );
    printf( " the License, or (at your option) any later version.\n" );
    printf( "----------------------------------------------------------------\n" );

    strcpy( filePath, argv[0] );
#ifdef DEBUG 
    filePath[strlen(filePath)-11] = 0;
#else
    filePath[strlen(filePath)-10] = 0;
#endif
    
    if( argc<2 )
    {
        printf( "Syntax: snesgba game1.smc game2.smc game3.smc...\n" );
        return;
    }

    int argindex = 1;

    while( argindex < argc )
    {
        char outFileName[1024];
        sprintf( outFileName, "%s.gba", argv[argindex] );

        char emuFileName[1024];
#ifdef DEBUG 
        sprintf( emuFileName, "%ssnezzid.gba", filePath );
#else
        sprintf( emuFileName, "%ssnezzi.gba", filePath );
#endif

        FILE *fp1 = fopen( emuFileName, "rb" );
        FILE *fp2 = fopen( argv[argindex], "rb" );
        FILE *fp3 = fopen( outFileName, "wb" );
        
        if( fp1==NULL )
        {
            printf( "Unable to open %s\n", emuFileName );
            printf( "Press any key...\n" );
            getch();
            return;
        }
        if( fp2==NULL )
        {
            printf( "Unable to open %s\n", argv[argindex] );
            printf( "Press any key...\n" );
            getch();
            return;
        }
        if( fp3==NULL )
        {
            printf( "Unable to open %s\n", outFileName );
            printf( "Press any key...\n" );
            getch();
            return;
        }

        gen_table();

        //-------------------------------------------
        // get ROM size
        //-------------------------------------------
        fseek( fp2, 0, SEEK_END );
        int romSize = ftell( fp2 );
        int fileSize = romSize;
        int testSize = 32768;
        
        //-------------------------------------------
        // auto detect header
        //-------------------------------------------
        char headerBuffer[512];
        int  hasHeader = 0;
        int  count;
        int  i,j;

        fseek( fp2, 0, SEEK_END );
        if( fileSize>512 )
        {
            hasHeader = 1;
            fseek( fp2, 0, SEEK_SET );
            fread( headerBuffer, 512, 1, fp2 );
            count = 0;
            for( i=64; i<512; i++ )
                if( headerBuffer[i]!=0 )
                    hasHeader = 0;
        }
        if( hasHeader )
        {
            printf( "Header      : Yes\n" );
            romSize -= 512;
        }
        else
        {
            printf( "Header      : No\n" );
        }
        
        //-------------------------------------------
        // compute ROM size (power of 2)
        //-------------------------------------------
        for( testSize = 32768; testSize<=4194304; testSize*=2 )
            if( testSize>=romSize )
                break;
        romSize = testSize;
        printf( "ROM Size    : %d megabits\n", romSize*8/(1024*1024) );
        
        //-------------------------------------------
        // compute CRC
        //-------------------------------------------
        if( hasHeader )
            fseek( fp2, 512, SEEK_SET );
        else
            fseek( fp2, 0, SEEK_SET );
        unsigned long crc = get_crc( fp2 );
        printf( "CRC Checksum: %8X\n", crc );


        //-------------------------------------------
        // load and write the emulator core
        //-------------------------------------------
        char buffer[4096];
        fseek( fp1, 0, SEEK_END );
        int emuSize = ((ftell( fp1 )+4096) / 4096) * 4096;
        char *emuBuffer = (char *) malloc( emuSize );
        printf( "Emu Core    : %d KB\n", emuSize/1024 );

        fseek( fp1, 0, SEEK_SET );
        fseek( fp3, 0, SEEK_SET );
        
        fread( emuBuffer, emuSize, 1, fp1 );
        fwrite( emuBuffer, emuSize, 1, fp3 );
        
        //-------------------------------------------
        // find all anchor positions
        //-------------------------------------------
        int anchorfound = find_buffer( emuBuffer, anchor, emuSize, 8 );
        int iwramstartfound = find_buffer( emuBuffer, iwramstart, emuSize, 8 );
        int iwramendfound = find_buffer( emuBuffer, iwramend, emuSize, 8 );

        snesRomPosition = (emuSize/65536) * 65536;
        if( emuSize%65536!=0 )
            snesRomPosition += 65536;

        printf( "SMEMMAP     : %08X\n", anchorfound );
        printf( "SNES ROM    : %08X\n", snesRomPosition );

        if( iwramendfound-iwramstartfound<=(32*1024-512) )
            printf( "IWRAM Size  : %d out of %d bytes\n", iwramendfound-iwramstartfound, (32*1024-512) );
        else
            printf( "IWRAM size  : %d bytes (Invalid)\n", iwramendfound-iwramstartfound );
        
        //-------------------------------------------
        // attach SNES rom into the GBA file
        //-------------------------------------------
        char *romBuffer = (char *) malloc( romSize+4096 );
        if( hasHeader )
        {
            fseek( fp2, 512, SEEK_SET );
            fread( romBuffer, romSize, 1, fp2 );
        }
        else
        {
            fseek( fp2, 0, SEEK_SET );
            fread( romBuffer, romSize, 1, fp2 );
        }

        //-------------------------------------------
        // check HIROM/LOROM
        //-------------------------------------------
        int     loROM = 1;
        
        unsigned short   romCheckSum = *((unsigned short *) (romBuffer+65472+28));
        unsigned short   romInvCheckSum = *((unsigned short *) (romBuffer+65472+28+2));
        if( (romCheckSum ^ romInvCheckSum)==0xffff )
            loROM = 0;
        else
        {
            romCheckSum = *((short *) (romBuffer+32704+28));
            romInvCheckSum = *((short *) (romBuffer+32704+28+2));
            if( (romCheckSum ^ romInvCheckSum)==0xffff )
                loROM = 1;
        }

        if( loROM )
            printf( "Memory Map  : LoROM\n" );
        else
            printf( "Memory Map  : HiROM\n" );
        

        //-------------------------------------------
        // obtain SRAM size from the header
        //-------------------------------------------
        int sramSize = 0;
        if( loROM )
            sramSize = romBuffer[32704+24];
        else
            sramSize = romBuffer[65472+24];
        if( sramSize==0 )
            sramSizeBytes = 1;
        else if( sramSize==1 )
            sramSizeBytes = 16*1024/8;
        else if( sramSize==2 )
            sramSizeBytes = 32*1024/8;
        else if( sramSize==3 )
            sramSizeBytes = 64*1024/8;
        
        printf( "SRAM Size   : %d KB\n", sramSizeBytes/1024 );


        //-------------------------------------------
        // do the necesasry patching
        //-------------------------------------------
        patch( crc, romBuffer );

        fseek( fp3, snesRomPosition, SEEK_SET );
        fwrite( romBuffer, romSize, 1, fp3 );
        free( romBuffer );


        //-------------------------------------------
        // write memory map to the emulator core
        //-------------------------------------------
        if( anchorfound!=0 )
        {
            formmemorymap( loROM, romSize );
            fseek( fp3, anchorfound+8, SEEK_SET );
            fwrite( memorymap, sizeof(memorymap), 1, fp3 );
        }
        else
        {
            printf( "\nCould not find %s\n", anchor );
        }
        

        printf( "\n\n\n" );
        fclose( fp1 );
        fclose( fp2 );
        fclose( fp3 );

        argindex ++;

    }

    printf( "Press any key...\n" );
    getch();

    return 0;
}

