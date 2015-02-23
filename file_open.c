#include "vfs.h"

#define BUFSIZE 8096
static	unsigned char   buf[BUFSIZE];
static  int	datapos; 
extern int filedata;
/*
 * Load data from a file as if from keyboard
 * 
 */
void loadfile( int addr)
	{
		FILE * fp;
		int len;
		char * name;

		name = (char *)addr;	// r0 passed from forth as int only
		fp = fopen(name,"r");
		if(!fp) 
		{
			printf("file %s not found\n",name);
			return;
		}
		// get length
		len = fsize(fp);
		if(len>BUFSIZE) len = BUFSIZE;
		fread(buf,len,1,fp);
		filedata= len;
		datapos = 0;
		printf("Loading file %s",name);
	}
/*
 * copy data to input buffer line by line
 */
char getfiledata(void)
{
	while(filedata--) return buf[datapos++];
	printf("  complete\n");
	return 0; // if no data
}	
	
/* all print messages from the SD system go though this */
int putc(int c,FILE *stream )
{
	return putchar(c);
}
