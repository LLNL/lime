#define B_OFFSET 0x00010000
#define R_OFFSET 0x00020000

extern int gdt_data[1024];

#ifdef __cplusplus
extern "C" {
#endif
void config_gdt(volatile void *);
void clear_gdt(volatile void *);
#ifdef __cplusplus
}
#endif
