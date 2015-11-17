#include <stdio.h>
#include <unistd.h>

extern void jonesforth();

int main(int argc, char **argv)
{
  jonesforth();
  return 0;
}

void
monitor()
{
  fprintf(stderr, "No monitor");
}

void
rcv_xmodem()
{
  fprintf(stderr, "xmodem needs to go away");
  _exit(-1);
}

void
hexdump()
{
  fprintf(stderr, "no hexdump");
}
