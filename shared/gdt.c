/*
 * gdt.c
 *
 *  Created on: May 5, 2020
 *      Author: macaraeg1
 */
#include <stdio.h>
#include "gdt.h"
#include "xparameters.h"

// NOTE: files with nxx suffix contain gaussians; files with const_xx suffix contain constants
int gdt_data_n0[1024] = {
#include "gdt_data_n0.txt"
};

int gdt_data_n5[1024] = {
#include "gdt_data_n5.txt"
};

int gdt_data_n10[1024] = {
#include "gdt_data_n10.txt"
};

int gdt_data_n15[1024] = {
#include "gdt_data_n15.txt"
};

int gdt_data_n20[1024] = {
#include "gdt_data_n20.txt"
};

int gdt_data_n25[1024] = {
#include "gdt_data_n25.txt"
};

int gdt_data_n50[1024] = {
#include "gdt_data_n50.txt"
};

int gdt_data_n100[1024] = {
#include "gdt_data_n100.txt"
};

int gdt_data_n250[1024] = {
#include "gdt_data_n250.txt"
};

int gdt_data_n500[1024] = {
#include "gdt_data_n500.txt"
};

int gdt_data_n1000[1024] = {
#include "gdt_data_n1000.txt"
};

int gdt_data_n1500[1024] = {
#include "gdt_data_n1500.txt"
};

int gdt_data_n2000[1024] = {
#include "gdt_data_n2000.txt"
};

int gdt_data_n2500[1024] = {
#include "gdt_data_n2500.txt"
};

int gdt_data_n3000[1024] = {
#include "gdt_data_n3000.txt"
};

int gdt_data_n5000[1024] = {
#include "gdt_data_n5000.txt"
};

int gdt_data_n10000[1024] = {
#include "gdt_data_n10000.txt"
};

int gdt_data_n20000[1024] = {
#include "gdt_data_n20000.txt"
};

int gdt_data_const_0[1024] = {
#include "gdt_data_const_0.txt"
};

int gdt_data_const_5[1024] = {
#include "gdt_data_const_5.txt"
};

int gdt_data_const_10[1024] = {
#include "gdt_data_const_10.txt"
};

int gdt_data_const_15[1024] = {
#include "gdt_data_const_15.txt"
};

int gdt_data_const_25[1024] = {
#include "gdt_data_const_25.txt"
};

int gdt_data_const_100[1024] = {
#include "gdt_data_const_100.txt"
};

int gdt_data_const_500[1024] = {
#include "gdt_data_const_500.txt"
};

int gdt_data_const_1000[1024] = {
#include "gdt_data_const_1000.txt"
};

int gdt_data_const_1500[1024] = {
#include "gdt_data_const_1500.txt"
};

int gdt_data_const_10000[1024] = {
#include "gdt_data_const_10000.txt"
};

int gdt_wr_data[1024];

//delay0 is slot 0 CPU SRAM W, R
//delay1 is slot 0 CPU DRAM W, R
//delay2 is slot 1 ACC SRAM W, R
//delay3 is slot 1 ACC DRAM W, R

//CPU SRAM Write = 52; SRAM Read = 69;
//CPU DRAM Write = 52; DRAM Read = 69;
//ACC SRAM Write = 48; SRAM Read = 66;
//ACC DRAM Write = 48; DRAM Read = 66;

int cpu_wr_lat = 52;
int cpu_rd_lat = 69;
int acc_wr_lat = 48;
int acc_rd_lat = 66;

void config_gdt()
{
	int num_elements;
	int iii;

    int *avd_0_0_b = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + B_OFFSET);
    int *avd_0_0_r = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + R_OFFSET);
    int *avd_0_1_b = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + B_OFFSET);
    int *avd_0_1_r = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + R_OFFSET);
    int *avd_1_0_b = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + B_OFFSET);
    int *avd_1_0_r = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + R_OFFSET);
    int *avd_1_1_b = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + B_OFFSET);
    int *avd_1_1_r = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + R_OFFSET);


    num_elements = sizeof(gdt_data)/sizeof(gdt_data[0]);
    printf("The size of Gaussian Delay Table in bytes is %lu\n", sizeof(gdt_data));
    printf("The number of entries in the Gaussian Delay Table is %d\n", num_elements);

    for (iii = 0; iii < num_elements; ++iii){
        gdt_wr_data[iii] = gdt_data_n10000[iii];  //***** Change target gdt filename here *****


        if (gdt_wr_data[iii] >= cpu_wr_lat) {
            *avd_0_0_b = gdt_wr_data[iii] - cpu_wr_lat;  // CPU SRAM write response
            *avd_0_1_b = gdt_wr_data[iii] - cpu_wr_lat;  // CPU DRAM write response
	    }
        else {
            *avd_0_0_b = 0;  // CPU SRAM write response
            *avd_0_1_b = 0;  // CPU DRAM write response
	    }

        if (gdt_wr_data[iii] >= cpu_rd_lat) {
            *avd_0_0_r = gdt_wr_data[iii] - cpu_rd_lat;  // CPU SRAM read response
            *avd_0_1_r = gdt_wr_data[iii] - cpu_rd_lat;  // CPU DRAM read response
	    }
        else {
            *avd_0_0_r = 0;  // CPU SRAM read response
            *avd_0_1_r = 0;  // CPU DRAM read response
		}

        if (gdt_wr_data[iii] >= acc_wr_lat) {
            *avd_1_0_b = gdt_wr_data[iii] - acc_wr_lat;  // Accererator SRAM write response
            *avd_1_1_b = gdt_wr_data[iii] - acc_wr_lat;  // Accererator DRAM write response
		}
        else {
            *avd_1_0_b = 0;  // Accererator SRAM write response
            *avd_1_1_b = 0;  // Accererator DRAM write response
		}

        if (gdt_wr_data[iii] >= acc_rd_lat) {
            *avd_1_0_r = gdt_wr_data[iii] - acc_rd_lat;  // Accererator SRAM read response
            *avd_1_1_r = gdt_wr_data[iii] - acc_rd_lat;  // Accererator DRAM read response
		}
        else {
            *avd_1_0_r = 0;  // Accererator SRAM read response
            *avd_1_1_r = 0;  // Accererator DRAM read response
		}

        avd_0_0_b++;
        avd_0_0_r++;
        avd_0_1_b++;
        avd_0_1_r++;
        avd_1_0_b++;
        avd_1_0_r++;
        avd_1_1_b++;
        avd_1_1_r++;
	}
}

void clear_gdt()
{
	int num_elements;
	int iii;

    int *avd_0_0_b = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + B_OFFSET);
    int *avd_0_0_r = (int *) (XPAR_DELAY_0_AXI_DELAY_0_BASEADDR + R_OFFSET);
    int *avd_0_1_b = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + B_OFFSET);
    int *avd_0_1_r = (int *) (XPAR_DELAY_0_AXI_DELAY_1_BASEADDR + R_OFFSET);
    int *avd_1_0_b = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + B_OFFSET);
    int *avd_1_0_r = (int *) (XPAR_DELAY_1_AXI_DELAY_0_BASEADDR + R_OFFSET);
    int *avd_1_1_b = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + B_OFFSET);
    int *avd_1_1_r = (int *) (XPAR_DELAY_1_AXI_DELAY_1_BASEADDR + R_OFFSET);

    printf("Clearing the GDT to set up for the next test...\n");
    num_elements = sizeof(gdt_data)/sizeof(gdt_data[0]);

    for (iii = 0; iii < num_elements; ++iii){

        *avd_0_0_b = gdt_data_n0[iii];  // CPU SRAM write response
        *avd_0_0_r = gdt_data_n0[iii];  // CPU SRAM read response
        *avd_0_1_b = gdt_data_n0[iii];  // CPU DRAM write response
        *avd_0_1_r = gdt_data_n0[iii];  // CPU DRAM read response
        *avd_1_0_b = gdt_data_n0[iii];  // Accererator SRAM write response
        *avd_1_0_r = gdt_data_n0[iii];  // Accererator SRAM read response
        *avd_1_1_b = gdt_data_n0[iii];  // Accererator DRAM write response
        *avd_1_1_r = gdt_data_n0[iii];  // Accererator DRAM read response

        avd_0_0_b++;
        avd_0_0_r++;
        avd_0_1_b++;
        avd_0_1_r++;
        avd_1_0_b++;
        avd_1_0_r++;
        avd_1_1_b++;
        avd_1_1_r++;
	}
}
