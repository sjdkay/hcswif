#! /usr/bin/python

### Stephen Kay, University of Regina
### 11/01/22
### stephen.kay@uregina.ca
### A new version of the batch submission script that uses python to create the batch file and submit it
### This SHOULD be more flexible in terms of pathing - it will grab paths using the ltsep package
### Requires the ltsep package which is available in UTIL_PION!

# Execute with python3 run_batch_Template.py RUNLIST MAXEVENTS(optional)

# Import relevant packages
import sys, math, os, subprocess, time

sys.path.insert(0, 'python/')
# Template version expects run list as minimum, can specify max events too. Complains if not 1/2 args given
if len(sys.argv)-1==1:
    RunList=sys.argv[1]
    MAXEVENTS=-1
elif len(sys.argv)-1==2:
    RunList=sys.argv[1]
    MAXEVENTS=sys.argv[2]
else:
    print("!!!!! ERROR !!!!!\n Expected AT LEAST 1 argument \n Usage is with Runlist and MaxEvents (optional)\n !!!!! ERROR !!!!!")
    sys.exit(1)

################################################################################################################################################

# Short yes/no question loop for use later
def yes_or_no(question):
    answer = input(question + "(y/n): ").lower().strip()
    print("")
    while not(answer == "y" or answer == "yes" or \
    answer == "n" or answer == "no"):
        print("Input yes or no")
        answer = input(question + "(y/n):").lower().strip()
        print("")
    if answer[0] == "y":
        return True
    else:
        return False

################################################################################################################################################

'''
ltsep package import and pathing definitions - Need to get this from UTIL_PION for this script to work, needs to be copied to correct location
'''

# Import package for cuts
import ltsep as lt 

# Add this to all files for more dynamic pathing
USER =  lt.SetPath(os.path.realpath(__file__)).getPath("USER") # Grab user info for file finding
HOST = lt.SetPath(os.path.realpath(__file__)).getPath("HOST")
REPLAYPATH = lt.SetPath(os.path.realpath(__file__)).getPath("REPLAYPATH")
BATCHPATH = REPLAYPATH+"/hcswif" # Crappy way of doing this for now, add it to ltsep?
inputFilePath = BATCHPATH+"/InputRunLists/"+RunList

print("Running as %s on %s, hallc_replay_lt path assumed as %s" % (USER, HOST, REPLAYPATH))

# 15/02/22 - SJDK - Added the swif2 workflow as a variable you can specify here
Workflow = "LTSep_"+USER # Change this as desired, could be changed to an input argument if you really want

################################################################################################################################################

if os.path.isfile(inputFilePath) == False :
    print("!!!!! ERROR !!!!!\n "+inputFilePath+" not found, check the file exists and try again\n!!!!! ERROR !!!!!")
    sys.exit(2)
    
inputFile = open(inputFilePath)
MaxLine=len(inputFile.readlines()) # Counter to determine number of lines in the file
inputFile.seek(0, 0) # Go back to start of file

LineNum=0
# Prompt yes/no, create batch job scripts and process each if yes, exit if no - could be improved, works for now
while yes_or_no("Do you wish to begin a new batch submission?"):
    for line in inputFile:
        LineNum+=1
        runNum= int(line)
        # .dat file naming, this is valid for the LT-separation data, change as needed
        if runNum >= 10000 :
            MSSstub=('/mss/hallc/c-pionlt/raw/shms_all_%05d.dat' % float(runNum))
        elif runNum < 10000 :
            MSSstub=('/mss/hallc/spring17/raw/coin_all_%05d.dat' % float(runNum))
        # Output batch job text file, this is the script that is submitted as part of the job, change the name of this as you want. Preferably, you should have different script name for each job so that you don't get any overwriting weirdness
        batch = USER+"_"+str(runNum)+"_Job.txt"
        # Print the size of the raw .dat file (converted to GB) to screen. sed command reads line 3 of the tape stub without the leading size=
        TapeFileSize = round((float(subprocess.check_output(["sed", "-n", '4 s/^[^=]*= *//p', MSSstub]))/1000000000), 3)
        if TapeFileSize == 0:
            TapeFileSize = 2
        # Creation of batch script for submission, the script is just a series of commands
        # We add these to the file (batch) via a series of write commands)
        batchfile=open(batch,'w')
        batchfile.write("MAIL: "+USER+"@jlab.org\n") # Set user email automatically
        batchfile.write("PROJECT: c-kaonlt\n") # Set the project to whatever you want, c-kaonlt exists but c-pionlt does not
        batchfile.write("TRACK: analysis\n") # Set the track as desired
        JobName = "PionLT_%05d" % float(runNum)
        print("Creating job "+batch+" as "+JobName+" for run "+str(runNum))
        print("Raw .dat file for run "+str(runNum)+" is "+str(TapeFileSize)+" GB")
        batchfile.write("JOBNAME: "+JobName+"\n")
        # Request double the tape file size in space, for trunctuated replays edit down as needed
        # Note, unless this is set typically replays will produce broken root files
        batchfile.write("DISK_SPACE: %i GB\n" % (TapeFileSize*2))
        if TapeFileSize < 45 :
            batchfile.write("MEMORY: 3000 MB\n")
        elif TapeFileSize >=45 :
            batchfile.write("MEMORY: 4000 MB\n")
        batchfile.write("CPU: 1\n") # hcana is single core, requesting more CPU's will lower priority but won't speed up your job
        batchfile.write("INPUT_FILES: "+MSSstub+"\n")
        batchfile.write("COMMAND:"+BATCHPATH+"/Analysis_Scripts/Batch_Template.sh "+str(runNum)+" "+str(MAXEVENTS)+"\n") # Insert your script and relevant arguments at the end
        batchfile.close()
        print("Submitting job "+str(LineNum)+"/"+str(MaxLine)+" - "+JobName)
        # Submit the job file to the swif2 workflow
        subprocess.call(["swif2", "add-jsub", Workflow, "-script", batch])
        time.sleep(2)
        if os.path.exists(batch):
            os.remove(batch)
    print("###############################################################################################################")
    print("############################################ END OF JOB SUBMISSIONS ###########################################")
    print("###############################################################################################################")
    print("\n")
    # Run the workflow
    subprocess.call(["swif2", "run", Workflow])
    break
    sys.exit(3)
