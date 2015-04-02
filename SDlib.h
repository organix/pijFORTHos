/* functions availible in the SDlib */
#include <stddef.h>


typedef void FILE;

// call this before anything else 
void	libfs_init(void);

size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
size_t fwrite(void *ptr, size_t size, size_t nmemb, FILE *stream);
void *fopen(const char *path, const char *mode);
int fclose(void *fp);
int fseek(FILE *stream, long offset, int whence);
long ftell(FILE *stream);
long fsize(FILE *stream);
int feof(FILE *stream);
int ferror(FILE *stream);
int fflush(FILE *stream);
void rewind(FILE *stream);
//DIR *opendir(const char *name);
//struct dirent *readdir(DIR *dirp);
//int closedir(DIR *dirp);

// this is included in lib, but uses putc that needs to be defined
void printf(const char *fmt, ...);
