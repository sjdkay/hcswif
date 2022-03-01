#! /bin/bash

### Stephen Kay, University of Regina
### 03/03/21
### stephen.kay@uregina.ca
### A batch submission script based on an earlier version by Richard Trotta, Catholic University of America
### SJDK - 06/01/22 - Updated to use swif2 system, also cleaned up the script and added some more comments
### SJDK - 01/03/22 - Updated to have a lot of the required arguments at the top so they're easy to adjust and tweak as desired

echo "Running as ${USER}"
# Script reads in run list as an argument, this run list should be located in hcswif/InputRunLists (see below), each line should simply be a run number in this file. The script iterates over the list.
RunList=$1
if [[ -z "$1" ]]; then
    echo "I need a run list process!"
    echo "Please provide a run list as input"
    exit 2
fi
# Check if an argument was provided, if not assume -1, if yes, this is max events
if [[ $2 -eq "" ]]; then
    MAXEVENTS=-1
else
    MAXEVENTS=$2
fi

hcswifLoc="/group/c-pionlt/USERS/${USER}/hallc_replay_lt/hcswif" # Set this to wherever you have hcswif located
Script="${hcswifLoc}/Auger_batch_scripts/Analysis_Scrpts/Batch_Template.sh" # Point this to whatever shell script you want to execute
# Input run numbers, this just points to a file which is a list of run numbers, one number per line
inputFile="/group/c-pionlt/USERS/${USER}/hallc_replay_lt/hcswif/Auger_batch_scripts/InputRunLists/${RunList}" # Set this as required
# 15/02/22 - SJDK - Added the swif2 workflow as a variable you can specify here
Workflow="LTSep_${USER}" # Change this as desired

# This script works by iterating over the list of files you've provided, it grabs the run number from each line and executes the script you've provided with this run number as the first argument
# It also provides the max events as an argument, you could add whatever extra arguments your script needs here
# This script will create and submit the job, so it prompts to check you want to run it
while true; do
    read -p "Do you wish to begin a new batch submission? (Please answer yes or no) " yn
    case $yn in
        [Yy]* )
            i=-1
            (
            # Reads in input file, line by line                                                       
            while IFS='' read -r line || [[ -n "$line" ]]; do
                echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                echo "Run number read from file: $line"
                echo ""
                # Each line is just a run number, set the variable to be the content of the line
                runNum=$line
		# Tape stub, you can point directly to a taped file and the farm job will do the jgetting for you, don't call it in your script! The stub is chosen based upon run number. This is very rough, bit generally correct
		# The tape stub is used as an input file, but it will also check the size of the raw .dat file to allocate memory/disk space usage
		# This is valid for the Kaon/PionLT runs, set this as needed
		if [[ $runNum -ge 10000 ]]; then
		    MSSstub='/mss/hallc/c-pionlt/raw/shms_all_%05d.dat'
		elif [[ $runNum -lt 10000 ]]; then
		    MSSstub='/mss/hallc/spring17/raw/coin_all_%05d.dat'
		fi
		# Output batch job text file, this is the script that is submitted as part of the job, change the name of this as you want. Preferably, you should have different script name for each job so that you don't get any overwriting weirdness
		batch="${USER}_${runNum}_Job.txt"
                tape_file=`printf $MSSstub $runNum`
		# Print the size of the raw .dat file (converted to GB) to screen. sed command reads line 3 of the tape stub without the leading size=
	        TapeFileSize=$(($(sed -n '4 s/^[^=]*= *//p' < $tape_file)/1000000000))
		if [[ $TapeFileSize == 0 ]];then
		    TapeFileSize=2
                fi
		echo "Raw .dat file is "$TapeFileSize" GB"
                # Finds number of lines of input file##   
                numlines=$(eval "wc -l < ${inputFile}")
                echo "Job $(( $i + 2 ))/$(( $numlines +1 ))"
                echo "Running ${batch} for ${runNum}"
                cp /dev/null ${batch}
                # Creation of batch script for submission, the script is just a series of commands
		# We add these to the file (${batch}) via a series of piped echo commands
                echo "PROJECT: c-kaonlt" >> ${batch} # Or whatever your project is!
                echo "TRACK: analysis" >> ${batch} ## Use this track for production running
		#echo "TRACK: debug" >> ${batch} ### Use this track for testing, higher priority
                echo "JOBNAME: KaonLT_${runNum}" >> ${batch} ## Change to be more specific if you want
		# Request double the tape file size in space, for trunctuated replays edit down as needed
		# Note, unless this is set typically replays will produce broken root files
		echo "DISK_SPACE: "$(( $TapeFileSize * 2 ))" GB" >> ${batch}
		if [[ $TapeFileSize -le 45 ]]; then # Assign memory based on size of tape file, should keep this as low as possible!
                    echo "MEMORY: 3000 MB" >> ${batch}
                elif [[ $TapeFileSize -ge 45 ]]; then
                    echo "MEMORY: 4000 MB" >> ${batch}
                fi
		echo "CPU: 1" >> ${batch} ### hcana is single core, setting CPU higher will lower priority and gain you nothing!
		echo "INPUT_FILES: ${tape_file}" >> ${batch}
                echo "COMMAND:${Script} ${runNum} ${MAXEVENTs}"  >> ${batch} ### Configure the script you want to run at the top, add/remove arguments as needed
		# You should check that your shell script works interactively on the farm before submitting it as a job!
                echo "MAIL: ${USER}@jlab.org" >> ${batch}
                echo "Submitting batch"
                eval "swif2 add-jsub ${Workflow} -script ${batch} 2>/dev/null" # Swif2 job submission, uses old jsub scripts
                echo " "
		sleep 2
		# Delete the script we just submitted as a batch job, this stops this folder getting clogged
		# COMMENT out the line below if you want to check what the job submission file looks like
		rm ${batch}
                i=$(( $i + 1 ))
		if [ $i == $numlines ]; then
		    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		    echo " "
		    echo "###############################################################################################################"
		    echo "############################################ END OF JOB SUBMISSIONS ###########################################"
		    echo "###############################################################################################################"
		    echo " "	
		fi
		done < "$inputFile"
	    )
	    # Run the workflow
	    eval 'swif2 run ${Workflow}'
	    break;;
        [Nn]* ) 
	        exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
