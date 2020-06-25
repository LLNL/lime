#-------------------------------------------------------------------------------
# Lawrence Livermore National Laboratory
# axi_id_check.py
# This program checks axi_id ordering of a simulation output file. The in put file needs to be in this
# format:
#
#   event_type, axi_data, axi_addr, axi_id, cyc_count
#
# where event type is either FR, MR, LR, or FW, MW, LW (first, middle, and last read or write)
# and count is the clock cycle number that the event was on the bus, where simulation starts at
# count = 0
#-------------------------------------------------------------------------------

import os
import csv
import sys

input_file  = "data_out/maxi_out.txt"          ## simulation output file
output_file = "data_out/axi_id_analysis.txt"  ## contains analysis results
check_file  = "data_out/checkfile.csv"        ## duplicates input_file

CHANNEL = "READ" ## READ or WRITE response
DBG_MSG = 0

#-------------------------------------------------------------------------------
# Intro message
#-------------------------------------------------------------------------------
print("")
print("")
print("***************************************************************")
print("This script will check simulation output files for common errors such as axi_id ordering,")
print("and missing events")
print("***************************************************************")
print("")

#-------------------------------------------------------------------------------
# Load command line arguments
#-------------------------------------------------------------------------------
for i in range(0,len(sys.argv)):
   ## over-write input file name/path if -fin found in command line
   if sys.argv[i] == "-fin":                      
      input_file = sys.argv[i+1]
   elif sys.argv[i] == "-fout":  
      output_file     = sys.argv[i+1]
      
print ("input file:  ", input_file)
print ("output file: ", output_file)
      
#-------------------------------------------------------------------------------
# Read simulation file, import into arrays
#-------------------------------------------------------------------------------

print ("------------------------------------------------\r\n")
print ("Importing", input_file)

with open (input_file, 'rt') as csvfile:

   event_type = []
   axi_data   = []
   axi_addr   = []
   axi_id     = []
   cyc_count  = []
   
   j             = 0  ## counts lines of output file (i.e. i minus comment lines)
   
   simulation_output = csv.reader(csvfile, delimiter=',', quotechar='|')
   for row in simulation_output:
      event_type.append(j)
      axi_data.append(j)
      axi_addr.append(j)
      axi_id.append(j)
      cyc_count.append(j)

      event_type[j] = row[0]
      axi_data[j]   = row[1]
      axi_addr[j]   = row[2]
      axi_id[j]     = row[3]
      cyc_count[j]  = row[4]
         
      if (DBG_MSG == 1):
         print("event_type[" + str(j) + "] = " + event_type[j]) 
         print("axi_data[" + str(j) + "]   = " + axi_data[j])    
         print("axi_addr[" + str(j) + "]   = " + axi_addr[j]) 
         print("axi_id[" + str(j) + "]     = " + axi_id[j]) 
         print("cyc_count[" + str(j) + "]  = " + cyc_count[j]) 

      j = j + 1

   num_events = j
      
   print("")
   print("There are " + str(num_events) + " events in " + input_file)
   print("The input file has been loaded into arrays for event_type, axi_data, axi_addr, axi_id, and cyc_count")
      
#-------------------------------------------------------------------------------
# Check file - generate for debug only
#-------------------------------------------------------------------------------

if(DBG_MSG == 1):
   file = open(check_file, 'wt') 
   
   for k in range(0,num_events):
      file.write (event_type[k] + "," + str(axi_data[k]) + "," + str(axi_addr[k]) + "," + str(axi_id[k]) + "," + str(cyc_count[k]))
      file.write ("\r\n")
   
   file.close() 

#-------------------------------------------------------------------------------
# Find all axi_ids in the file
#-------------------------------------------------------------------------------

axi_id_list = []

for m in range (0,num_events):
   axi_id_temp = axi_id[m]   # load current axi_id into axi_id_temp
   
   if not(axi_id_temp in axi_id_list): # compare against current list
      axi_id_list.append(axi_id_temp)
      
#-------------------------------------------------------------------------------
# Sort by axi_id found in axi_id_list[]
#-------------------------------------------------------------------------------
num_axi_id = len(axi_id_list)

print("Transactions from these " + str(num_axi_id) + " AXI IDs were found in this trace = " + str(axi_id_list))

event_type_srt = []
axi_data_srt   = []
axi_addr_srt   = []
axi_id_srt     = []
cyc_count_srt  = []

for p in range (0, num_axi_id):

   event_type_srt.clear()
   axi_data_srt.clear()
   axi_addr_srt.clear()
   axi_id_srt.clear()
   cyc_count_srt.clear()
   error_count = 0

   # Create a list of events for each of the found axi_ids
   for n in range (0,num_events):
      if (axi_id[n] == axi_id_list[p]):
         # append the row with the matchine ID to the _srt lists for analysis
         event_type_srt.append(event_type[n])
         axi_data_srt.append(axi_data[n])
         axi_addr_srt.append(axi_addr[n])
         axi_id_srt.append(axi_id[n])
         cyc_count_srt.append(cyc_count[n])
         
   num_axi_id_events = len(event_type_srt)

   print("")
   print("------------------------------------------------")
   print("Found " + str(num_axi_id_events) + " events for axi_id = " + str(axi_id_list[p]))   
   
   ##---------------------------------------------
   ## Look for axi_id order errors
   ##---------------------------------------------
   print("Checking that all events are in order for axi_id = " + str(axi_id_list[p]))
   for q in range (0,num_axi_id_events-1):  ## "-1" to prevent overflow at end of file
      # look for axi_id ordering error
      if (int(axi_addr_srt[q],16) > int(axi_addr_srt[q+1],16)):
         
         error_count = error_count + 1
         print("*** ERROR ***: axi_id order error found at cycle_count = " + str(cyc_count_srt[q+1]))
   
   if (error_count > 0):
      print("   ***** TEST FAILED *****: A total of " + str(error_count) + " axi_id ordering errors were found on axi_id = " + str(axi_id_list[p]))
      print("")
   else:
      print("   TEST PASSED: No axi_id ordering errors were found")
      print("")
   
   
   ##---------------------------------------------
   ## Look for missing event types
   ##---------------------------------------------

   error_count      = 0
   pkt_count        = 0
   single_event_pkt = 0
   pkt_2_event      = 0
   pkt_4_event      = 0
   r                = 0
   
   # event types
   FIRST_LAST = 'FLR'
   FIRST      = 'FR'
   MIDDLE     = 'MR'
   LAST       = 'LR'
   
   if CHANNEL == "WRITE":
      FIRST_LAST = 'FLW'
      FIRST      = 'FW'
      MIDDLE     = 'MW'
      LAST       = 'LW'
   
   print("Checking that no events are missing or out of order from each packet for axi_id = " + str(axi_id_list[p]))
   while r < num_axi_id_events:

      ## Decode Read transactions
      if (event_type_srt[r] == FIRST_LAST):
         single_event_pkt = single_event_pkt + 1
         pkt_count        = pkt_count + 1
         r                = r + 1
      elif (event_type_srt[r] == FIRST):  ## first event in packet found; look for succeeding events
         if (event_type_srt[r + 1] == 'LR'):
            if (axi_addr_srt[r] != axi_addr_srt[r+1]):
               print("   *** ERROR ***: A complete packet was found, but with mismatched addresses at cycle_count = " + str(cyc_count_srt[r]))
               error_count = error_count + 1
            pkt_2_event = pkt_2_event + 1
            pkt_count   = pkt_count + 1
            r = r + 2
         elif (event_type_srt[r + 1] == MIDDLE and event_type_srt[r + 2] == MIDDLE and event_type_srt[r + 3] == LAST):
            if (axi_addr_srt[r] != axi_addr_srt[r+1]) or (axi_addr_srt[r] != axi_addr_srt[r+2]) or (axi_addr_srt[r] != axi_addr_srt[r+3]):
               print("   *** ERROR ***: A complete packet was found, but with mismatched addresses at cycle_count = " + str(cyc_count_srt[r]))
               error_count = error_count + 1
            pkt_4_event = pkt_4_event + 1
            pkt_count   = pkt_count + 1
            r = r + 4
         else:
            print("   *** ERROR ***: An incomplete packet or undecoded packet format was found at cycle_count = " + str(cyc_count_srt[r]))
            print("   This *may* be due to the presence of a valid packet of a size that is not decoded")
            print("   Only single-even packets, 2- and 4- event packets are decoded")
            error_count = error_count + 1
            r = r + 1      
      elif (event_type_srt[r] == MIDDLE):
         print("   *** ERROR ***: an unattached MR event was found at cycle_count = " + str(cyc_count_srt[r]))
         error_count = error_count + 1
         r           = r + 1
      elif (event_type_srt[r] == LAST):
         print("   *** ERROR ***: an unattached LR event was found at cycle_count = " + str(cyc_count_srt[r]))
         error_count = error_count + 1
         r           = r + 1

   print("   A total of " + str(pkt_count) + " packets were found for axi_id " + str(axi_id_list[p]) + ":") 
   print("      Single-event packets = " + str(single_event_pkt))
   print("      Two-event packets    = " + str(pkt_2_event))
   print("      Four-event packets   = " + str(pkt_4_event))
   if (error_count > 0):
      print("   ***** TEST FAILED *****: A total of " + str(error_count) + " event_type errors were found on axi_id = " + str(axi_id_list[p]))
      print("")
   else:
      print("   TEST PASSED: No event type errors were found")
  
   
         