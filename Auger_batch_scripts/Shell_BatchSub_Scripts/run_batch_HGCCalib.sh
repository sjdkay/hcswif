#! /bin/bash

### Stephen Kay, University of Regina
### 13/01/21
### stephen.kay@uregina.ca
### A batch submission script based on an earlier version by Richard Trotta, Catholic University of America

echo "Running as ${USER}"
RunList=$1
if [[ -z "$1" ]]; then
    echo "I need a run list process!"
    echo "Please provide a run list as input"
    exit 2
fi
if [[ $2 -eq "" ]]; then
    MAXEVENTS=-1
else
    MAXEVENTS=$2
fi

# 15/02/22 - SJDK - Added the swif2 workflow as a variable you can specify here
Workflow="LTSep_${USER}" # Change this as desired
# Input run numbers, this just points to a file which is a list of run numbers, one number per line
inputFile="/group/c-pionlt/USERS/${USER}/hallc_replay_lt/hcswif/InputRunLists/${RunList}"

echo "Note, this script only processes calibration for a single run at a time, you may need to manually run the HGC script with a set of run numbers for better results"
echo "See hallc_replay_lt/CALIBRATION/shms_hgcer_calib/README.md for instructions on how to chain runs together with the calibration script"

while true; do
    read -p "Do you wish to begin a new batch submission? (Please answer yes or no) " yn
    case $yn in
        [Yy]* )
            i=-1
            (
            ## Reads in input file ##
            while IFS='' read -r line || [[ -n "$line" ]]; do
                echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                echo "Run number read from file: $line"
                echo ""
                ## Run number ##
                runNum=$line
		# Tape stub, you can point directly to a taped file and the farm job will do the jgetting for you, don't call it in your script! The stub is chosen based upon run number. This is very rough, bit generally correct
		if [[ $runNum -ge 10000 ]]; then
		    MSSstub='/mss/hallc/c-pionlt/raw/shms_all_%05d.dat'
		elif [[ $runNum -lt 10000 ]]; then
		    MSSstub='/mss/hallc/spring17/raw/coin_all_%05d.dat'
		fi
		batch="${USER}_${runNum}_HGCCalib_Job.txt"
                tape_file=`printf $MSSstub $runNum`
		TapeFileSize=$(($(sed -n '4 s/^[^=]*= *//p' < $tape_file)/1000000000))
		if [[ $TapeFileSize == 0 ]];then
                    TapeFileSize=1
                fi
		echo "Raw .dat file is "$TapeFileSize" GB"
		tmp=tmp
                ##Finds number of lines of input file##
                numlines=$(eval "wc -l < ${inputFile}")
                echo "Job $(( $i + 2 ))/$(( $numlines +1 ))"
                echo "Running ${batch} for ${runNum}"
                cp /dev/null ${batch}
                ##Creation of batch script for submission##
                echo "PROJECT: c-kaonlt" >> ${batch}
                echo "TRACK: analysis" >> ${batch}
                echo "JOBNAME: HGCCalib_${runNum}" >> ${batch}
                # Request disk space depending upon raw file size
                echo "DISK_SPACE: "$(( $TapeFileSize * 3 ))" GB" >> ${batch}
		if [[ $TapeFileSize -le 45 ]]; then
		    echo "MEMORY: 4000 MB" >> ${batch}
		elif [[ $TapeFileSize -ge 45 ]]; then
		    echo "MEMORY: 6000 MB" >> ${batch}
		fi
		#echo "OS: centos7" >> ${batch}
                echo "CPU: 1" >> ${batch} ### hcana single core, setting CPU higher will lower priority!
		echo "INPUT_FILES: ${tape_file}" >> ${batch}
		#echo "TIME: 1" >> ${batch} 
		echo "COMMAND:/group/c-pionlt/USERS/${USER}/hallc_replay_lt/hcswif/Analysis_Scripts/HGCCalib_Batch.sh ${runNum}" >> ${batch}
		echo "MAIL: ${USER}@jlab.org" >> ${batch}
                echo "Submitting batch"
                eval "swif2 add-jsub ${Workflow} -script ${batch} 2>/dev/null"
                echo " "
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
	    eval 'swif2 run ${Workflow}'
	    break;;
        [Nn]* ) 
	    exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
