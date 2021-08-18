#define B_OFFSET 0x00010000
#define R_OFFSET 0x00020000
#define PWCLT_OFFSET 0x00030000

extern int gdt_data[1024];

#ifdef __cplusplus
extern "C" {
#endif
void config_gdt(volatile void *base, int latency, int gdt_input[]);
void clear_gdt(volatile void *base, int gdt_input[]);
#ifdef __cplusplus
}
#endif
