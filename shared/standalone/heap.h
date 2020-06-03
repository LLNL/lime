
#ifndef HEAP_H_
#define HEAP_H_

extern char *heap_beg;
extern char *heap_end;
extern char *heap_ptr;

#ifdef __cplusplus
extern "C" {
#endif

extern char *sbrk(int nbytes);

#ifdef __cplusplus
}
#endif

#endif /* HEAP_H_ */
