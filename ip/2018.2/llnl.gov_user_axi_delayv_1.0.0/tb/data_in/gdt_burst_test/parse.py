#-------------------------------------------------------------------------------
# Lawrence Livermore National Laboratory
# parse.py
# This will concatenate the inter-event gap and the axi fields into a tightly packed binary vector,
# convert to hex, retain leading zeros, then output to generate_datain.py
#-------------------------------------------------------------------------------

from axi_delay_pkg import *
#import os
#import csv
#import sys
import math

def parse (opfile_name, ieg, s_axi_resp, s_axi_id, s_axi_addr, s_axi_data, s_axi_strb, s_axi_len, s_axi_size, s_axi_burst, \
                s_axi_lock, s_axi_cache, s_axi_prot, s_axi_qos, s_axi_region, s_axi_valid, s_axi_last):

   C_AXI_STRB_WIDTH = int(C_AXI_DATA_WIDTH/8)
   
   #-------------------------------------------------------------------------------
   # conversions
  
   #-------------------------------------------------------------------------------  
   #ieg_hex = '{0:08x}'.format(ieg)
   get_bin = lambda x, n: format(x, 'b').zfill(n)
   
   # pad with leading zeros for correct output vector length
   def padhexa(s,length):
       return s[0:].zfill(length)
   
   ##--------------------------
   ## open file
   ##--------------------------
   fo = open(opfile_name, "at")  ## "at" will append to file, "wt" will write

   # convert inter-event gap to binary
   ieg_binary = get_bin(ieg,32)

   # convert from hex integers to binary strings
   s_axi_resp = get_bin(s_axi_resp  , 2)
   s_axi_id   = get_bin(s_axi_id,C_AXI_ID_WIDTH)
   s_axi_addr = get_bin(s_axi_addr,C_AXI_ADDR_WIDTH)
   s_axi_data = get_bin(s_axi_data,C_AXI_DATA_WIDTH)
   s_axi_strb = get_bin(s_axi_strb,C_AXI_STRB_WIDTH)
   s_axi_len  = get_bin(s_axi_len,8)
   
   # convert from binary integers to binary strings
   s_axi_size   = get_bin(s_axi_size  , 3)
   s_axi_burst  = get_bin(s_axi_burst , 2)
   s_axi_lock   = get_bin(s_axi_lock  , 2) 
   s_axi_cache  = get_bin(s_axi_cache , 4)
   s_axi_prot   = get_bin(s_axi_prot  , 3) 
   s_axi_qos    = get_bin(s_axi_qos   , 4) 
   s_axi_region = get_bin(s_axi_region, 4)
   s_axi_valid  = get_bin(s_axi_valid , 1)
   s_axi_last   = get_bin(s_axi_last  , 1)
   
   ##--------------------------
   ## concatenated binary of all the fields to output
   ##--------------------------
   concat_bin = ieg_binary + s_axi_resp + s_axi_id + s_axi_addr + s_axi_data + s_axi_strb + s_axi_len + \
                s_axi_size + s_axi_burst + s_axi_lock + s_axi_cache + s_axi_prot + \
                s_axi_qos + s_axi_region + s_axi_valid + s_axi_last
   print(concat_bin)
   print(len(concat_bin))
   
   ##--------------------------
   ## hex conversion
   ##--------------------------
   concat_hex = '%08X' % int(concat_bin,2) ## print without 0x identifier
    
   length_concat_hex = len(concat_hex)
   length_concat_bin = len(concat_bin)
   leading_zeros     = round(length_concat_bin/4) - length_concat_hex

   remainder = (length_concat_bin % 4)
   #print("remainder = " + str(remainder))

   if (remainder != 0):
      leading_zeros = leading_zeros + 1

   #print("concat_hex before adding leading zeros           = " + str(concat_hex))
   #print("length of concat_hex before adding leading zeros = " + str(length_concat_hex))
   #print("length of length_concat_bin                      = " + str(length_concat_bin))
   #print("number of leading zeros to add                   = " + str(leading_zeros))

   concat_hex = padhexa(concat_hex,(length_concat_hex + leading_zeros)) 

   #print("concat_hex after adding leading zeros            = " + str(concat_hex))
   #print("length of concat_hex after adding leading zeros  = " + str(len(concat_hex)))

## write twice due to bug that skips lines (FIX THISSSSSSSSS!!!!)
   fo.write (concat_hex)
   fo.write ("\r\n")
