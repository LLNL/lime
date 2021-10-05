/*
 * gdt.c
 *
 *  Created on: May 5, 2020
 *      Author: sarkar6
 */
#include <stdio.h>
#include <string.h>
#include "gdt.h"

// NOTE: files with nxx suffix contain gaussians; files with const_xx suffix contain constants
int gdt_data_n0[1024] = {
#include "gdt_data/gdt_data_n0.txt"
};

int gdt_data_n5[1024] = {
#include "gdt_data/gdt_data_n5.txt"
};

int gdt_data_n10[1024] = {
#include "gdt_data/gdt_data_n10.txt"
};

int gdt_data_n15[1024] = {
#include "gdt_data/gdt_data_n15.txt"
};

int gdt_data_n20[1024] = {
#include "gdt_data/gdt_data_n20.txt"
};

int gdt_data_n25[1024] = {
#include "gdt_data/gdt_data_n25.txt"
};

int gdt_data_n50[1024] = {
#include "gdt_data/gdt_data_n50.txt"
};

int gdt_data_n100[1024] = {
#include "gdt_data/gdt_data_n100.txt"
};

int gdt_data_n250[1024] = {
#include "gdt_data/gdt_data_n250.txt"
};

int gdt_data_n500[1024] = {
#include "gdt_data/gdt_data_n500.txt"
};

int gdt_data_n1000[1024] = {
#include "gdt_data/gdt_data_n1000.txt"
};

int gdt_data_n1500[1024] = {
#include "gdt_data/gdt_data_n1500.txt"
};

int gdt_data_n2000[1024] = {
#include "gdt_data/gdt_data_n2000.txt"
};

int gdt_data_n2500[1024] = {
#include "gdt_data/gdt_data_n2500.txt"
};

int gdt_data_n3000[1024] = {
#include "gdt_data/gdt_data_n3000.txt"
};

int gdt_data_n5000[1024] = {
#include "gdt_data/gdt_data_n5000.txt"
};

int gdt_data_n10000[1024] = {
#include "gdt_data/gdt_data_n10000.txt"
};

int gdt_data_n20000[1024] = {
#include "gdt_data/gdt_data_n20000.txt"
};

int gdt_data_const_0[1024] = {
#include "gdt_data/gdt_data_const_0.txt"
};

int gdt_data_const_5[1024] = {
#include "gdt_data/gdt_data_const_5.txt"
};

int gdt_data_const_10[1024] = {
#include "gdt_data/gdt_data_const_10.txt"
};

int gdt_data_const_15[1024] = {
#include "gdt_data/gdt_data_const_15.txt"
};

int gdt_data_const_25[1024] = {
#include "gdt_data/gdt_data_const_25.txt"
};

int gdt_data_const_100[1024] = {
#include "gdt_data/gdt_data_const_100.txt"
};

int gdt_data_const_500[1024] = {
#include "gdt_data/gdt_data_const_500.txt"
};

int gdt_data_const_1000[1024] = {
#include "gdt_data/gdt_data_const_1000.txt"
};

int gdt_data_const_1500[1024] = {
#include "gdt_data/gdt_data_const_1500.txt"
};

int gdt_data_const_10000[1024] = {
#include "gdt_data/gdt_data_const_10000.txt"
};

//int gdt_wr_data[1024];

void config_gdt(volatile void *base, int latency, int gdt_input[])
{
    int num_elements;
    int iii;

    volatile int *avd = (int *) (base);

//    num_elements = sizeof(gdt_input)/sizeof(gdt_input[0]);
//    printf("The size of Gaussian Delay Table in bytes is %lu\n", sizeof(gdt_input));
//    printf("The number of entries in the Gaussian Delay Table is %d\n", num_elements);

    for (iii = 0; iii < 1024; ++iii){

//		printf("%d %d\n", gdt_input[iii], iii);

//        gdt_wr_data[iii] = gdt_input[iii];

        if (gdt_input[iii] >= latency) {
            *avd = (gdt_input[iii] - latency)*(187.5/300);  // adjusted for latency and scaled for clock freq. difference (compared to master branch)
	    }
        else {
            *avd = 0;
	    }
        avd++;
    }
}

void clear_gdt(volatile void *base, int gdt_input[])
{
    int num_elements;
    int iii;

    volatile int *avd = (int *) (base);

//    printf("Clearing the GDT to set up for the next test...\n");
//    num_elements = sizeof(gdt_input)/sizeof(gdt_input[0]);

/*
    //Read and see what were the values to start with
    avd = (int *)base;
    for (iii = 0; iii < num_elements; ++iii){
        int val = *avd;
        if(val != gdt_wr_data[iii] - latency)
          printf("%p: avd = %d and gdt_data = %d\n", avd, val, gdt_wr_data[iii]);
        avd++;
    }
*/

    avd = (int *)(base);
    for (iii = 0; iii < 1024; ++iii){
        *avd = gdt_input[iii];  // CPU SRAM write response
        avd++;
    }
}
