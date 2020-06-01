#ifndef CONFIG_H_
#define CONFIG_H_

/* slave interface configuration */
#define S_AXI_ADDR_WIDTH 16
#define S_AXI_DATA_WIDTH 32
#define S_AXI_ID_WIDTH 1

/* system configuration */
#define SHOW_AXI_DATA 0
#define SHOW_AXI_IDS 1
#define SHOW_AXI_LEN 1
#define FIFO_AXIS_TDATA_WIDTH 328
#define NUM_MONITOR_SLOTS 2

/* event bit-field widths */
#define LOGID 1
#define TIMESTAMP 30
#define LOOP 1
#define SW_PACKET 32

/* slot bit-field widths */
typedef struct {
	unsigned EXT_EVENT;
	unsigned FLAGS;
	unsigned xxID;
	unsigned AxLEN;
	unsigned AxADDR;
	unsigned xDATA;
} sparam_t;

extern sparam_t slot_param[];

#endif /* CONFIG_H_ */
