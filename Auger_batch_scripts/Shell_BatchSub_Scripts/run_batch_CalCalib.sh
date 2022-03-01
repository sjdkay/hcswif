#! /bin/bash
##### A batch submission script based on an earlier version by Richard
echo "Running as ${USER}"
SPEC=$1
### Check you have provided the first argument correctly
if [[ ! $1 =~ ^("HMS"|"SHMS")$ ]]; then
    echo "Please specify spectrometer, HMS or SHMS"
    exit 2
fi
RunList=$2
if [[ -z "$2" ]]; then
    echo "I need a run list process!"
    echo "Please provide a run list as input"
    exit 2
fi
### Check if a second argument was provided, if not assume -1, if yes, this is max events
if [[ $3 -eq "" ]]; then
    MAXEVENTS=-1
else
    MAXEVENTS=$3
fi
# 15/02/22 - SJDK - Added the swif2 workflow as a variable you can specify here
Workflow="LTSep_${USER}" # Change this as desired
##Input run numbers##                                                                      
inputFile="/group/c-pionlt/USERS/${USER}/hallc_replay_lt/hcswif/InputRunLists/${RunList}"

while true; do
    read -p "Do you wish to begin a new batch submission? (Please answer yes or no) " yn
    case $yn in
        [Yy]* )
            i=-1
            (
            ##Reads in input file##                                                       
            while IFS='' read -r line || [[ -n "$line" ]]; do
                echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                echo "Run number read from file: $line"
                echo ""
                ##Run number#                                                                           
                runNum=$line
		if [[ $runNum -ge 10000 ]]; then
		    MSSstub='/mss/hallc/c-pionlt/raw/shms_all_%05d.dat'
		elif [[ $runNum -lt 10000 ]]; then
		    MSSstub='/mss/hallc/spring17/raw/coin_all_%05d.dat'
		fi
		##Output batch script##                                           
		batch="${USER}_${runNum}_${SPEC}_CalCalib_Job.txt"
                tape_file=`printf $MSSstub $runNum`
		# Print the size of the raw .dat file (converted to GB) to screen. sed command reads line 3 of the tape stub without the leading size=
	        TapeFileSize=$(($(sed -n '4 s/^[^=]*= *//p' < $tape_file)/1000000000))
		if [[ $TapeFileSize == 0 ]];then
		    TapeFileSize=2
                fi
		echo "Raw .dat file is "$TapeFileSize" GB"
                tmp=tmp
                ##Finds number of lines of input file##                             
                numlines=$(eval "wc -l < ${inputFile}")
                echo "Job $(( $i + 2 ))/$(( $numlines +1 ))"
                echo "Running ${batch} for ${runNum}"
                cp /dev/null ${batch}
                ##Creation of batch script for submission##                                       
		echo "PROJECT: c-kaonlt" >> ${batch} # Or whatever your project is!
		echo "TRACK: analysis" >> ${batch} ## Use this track for production running
                #echo "TRACK: debug" >> ${batch} ### Use this track for testing, higher priority
                echo "JOBNAME: CalCalib_${SPEC}_${runNum}" >> ${batch} ## Change to be more specific if you want
		# Request double the tape file size in space, for trunctuated replays edit down as needed
		# Note, unless this is set typically replays will produce broken root files
		echo "DISK_SPACE: "$(( $TapeFileSize * 2 ))" GB" >> ${batch}
		if [[ $TapeFileSize -le 45 ]]; then # Assign memory based on size of tape file, should keep this as low as possible!
                    echo "MEMORY: 2500 MB" >> ${batch}
                elif [[ $TapeFileSize -ge 45 ]]; then
                    echo "MEMORY: 4000 MB" >> ${batch}
                fi
                echo "CPU: 1" >> ${batch} ### hcana is single core, setting CPU higher will lower priority and gain you nothing!
		echo "INPUT_FILES: ${tape_file}" >> ${batch}
                echo "COMMAND:/group/c-pionlt/USERS/${USER}/hallc_replay_lt/hcswif/Analysis_Scripts/CalCalib_Batch.sh ${runNum} ${SPEC} ${MAXEVENTS}" >> ${batch}
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

