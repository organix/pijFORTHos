#include "vfs.h"
/*
 * Simple test of SD code
 * read sector 0 and dump to screen
 */
void readSector_0( void)
	{
		FILE * fp;
		unsigned char   buf[1024];
		fp = fopen("/fred","r");
		if(fp) fread(buf,14,1,fp);
		dump256(buf);
	}
int putc(int c,FILE *stream )
{
	return putchar(c);
}
