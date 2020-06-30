#include <stdio.h>
#include <limits.h>
/*#include <sys/time.h>*/

// Example main arguments
// #define MARGS ""

#include "lime.h"

#ifndef STREAM_ARRAY_SIZE
#define STREAM_ARRAY_SIZE 10000000
#endif


#ifdef NTIMES
#if NTIMES<=1
#define NTIMES 10
#endif
#endif

#ifndef NTIMES
#define NTIMES 10
#endif

#define HLINE "-------------------------------------------------------------\n"

#ifndef MIN
#define MIN(x,y) ((x)<(y)?(x):(y))
#endif
#ifndef MAX
#define MAX(x,y) ((x)>(y)?(x):(y))
#endif

#ifndef STREAM_TYPE
#define STREAM_TYPE int
#endif
#define OFFSET 0

static STREAM_TYPE a[STREAM_ARRAY_SIZE+OFFSET],
  b[STREAM_ARRAY_SIZE+OFFSET],
  c[STREAM_ARRAY_SIZE+OFFSET];


static double	bytes[4] = {
  2 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,
  2 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,
  3 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE,
  3 * sizeof(STREAM_TYPE) * STREAM_ARRAY_SIZE
};

void config_gdt();

int MAIN(int argc, char *argv[])
{
  int BytesPerWord = sizeof(STREAM_TYPE);
  int sum;
  int j, k;
  /* --- Configure the Gaussian Delay Tables (GTD) --- */
  config_gdt();

  /* --- SETUP --- determine precision and check timing --- */

  printf(HLINE);
  printf("Starting Simple\n");
  printf(HLINE);
  printf("This system uses %d bytes per array element.\n",
	 sizeof(STREAM_TYPE));

  printf(HLINE);
  
  printf("Array size = %llu (elements)\n" , (unsigned long long) STREAM_ARRAY_SIZE);
  printf("Array addr %p %p %p\n", a, b, c);
  printf("Memory per array = %.1f MiB (= %.1f GiB).\n",
	 BytesPerWord * ( (double) STREAM_ARRAY_SIZE / 1024.0/1024.0),
	 BytesPerWord * ( (double) STREAM_ARRAY_SIZE / 1024.0/1024.0/1024.0));
  printf("Total memory required = %.1f MiB (= %.1f GiB).\n",
	 (3.0 * BytesPerWord) * ( (double) STREAM_ARRAY_SIZE / 1024.0/1024.),
	 (3.0 * BytesPerWord) * ( (double) STREAM_ARRAY_SIZE / 1024.0/1024./1024.));
  printf("The loop will be executed %d times.\n", NTIMES);


  for (j=0; j<STREAM_ARRAY_SIZE; j++) {
    a[j] = j;
    b[j] = 2;
    c[j] = 3;
  }

  printf(HLINE);

  /* --- MAIN LOOP --- repeat test cases NTIMES times --- */

  CLOCKS_EMULATE
    // CACHE_BARRIER(NULL)
    TRACE_START
    STATS_START
    sum = 0;
  for (k=0; k<NTIMES; k++)
    {
      for (j=0; j<STREAM_ARRAY_SIZE; j++)
	sum +=  a[j];
#if 0
      for (j=0; j<STREAM_ARRAY_SIZE; j++)
	b[j] = sum*c[j];

      for (j=0; j<STREAM_ARRAY_SIZE; j++)
	c[j] = a[j]+b[j];

      for (j=0; j<STREAM_ARRAY_SIZE; j++)
	a[j] = b[j]+sum*c[j];
#endif 
    }
  // CACHE_BARRIER(NULL)
  STATS_STOP
    TRACE_STOP
    CLOCKS_NORMAL
 printf("sum = %d\n", sum);

  printf(HLINE);

  STATS_PRINT

 printf(HLINE);   
  TRACE_CAP
    printf(HLINE);
    return 0;
}
