#! /bin/bash    

### Stephen Kay, University of Regina
### 03/03/21
### stephen.kay@uregina.ca
### A batch submission script based on an earlier version by Richard Trotta, Catholic University of America

echo "Running as ${USER}"
# SJDK - 28/02/22 - This works for now BUT it should really try and get these from the run list
# Need to change these a little, should check whether arguments are good or not REGARDLESS of whether they're blank
if [[ -z "$1" || ! "$RUNTYPE" =~ Prod|Lumi|HeePSing|HeePCoin|fADC|Optics ]]; then # Check the 2nd argument was provided and that it's one of the valid options
    echo ""
    echo "I need a valid run type"
    while true; do
	echo ""
	read -p "Please type in a run type from - Prod - Lumi - HeePSing - HeePCoin - fADC - Optics - Case sensitive! - or press ctrl-c to exit : " RUNTYPE
	case $RUNTYPE in
	    '');; # If blank, prompt again
	    'Prod'|'Lumi'|'HeePSing'|'HeePCoin'|'Optics'|'fADC') break;; # If a valid option, break the loop and continue
	esac
    done
fi
if [[ -z "$2" || ! "$TARGET" =~ LH2|LD2|Dummy10cm|Carbon0p5|AuFoil|Optics1|Optics2|CarbonHole ]]; then # Check the 3rd argument was provided and that it's one of the valid options
    echo ""
    echo "I need a valid target"
    while true; do	
	echo ""
	read -p "Please type in a target from - LH2 - LD2 - Dummy10cm - Carbon0p5 - AuFoil - Optics1 - Optics2 - CarbonHole - Case sensitive! - or press ctrl-c to exit : " TARGET
	case $TARGET in
	    '');; # If blank, prompt again
	    'LH2'|'LD2'|'Dummy10cm'|'Carbon0p5'|'AuFoil'|'Optics1'|'Optics2'|'CarbonHole') break;; # If a valid option, break the loop and continue
	esac
    done
fi

RunList=$3
if [[ -z "$3" ]]; then
    echo "I need a run list process!"
    echo "Please provide a run list as input"
    exit 2
fi
if [[ $4 -eq "" ]]; then
    MAXEVENTS=-1
else
    MAXEVENTS=$4
fi

# 15/02/22 - SJDK - Added the swif2 workflow as a variable you can specify here
Workflow="LTSep_${USER}" # Change this as desired
# Input run numbers, this just points to a file which is a list of run numbers, one number per line
inputFile="/group/c-pionlt/USERS/${USER}/hallc_replay_lt/UTIL_BATCH/InputRunLists/${RunList}"

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
		##Output batch job file                                                                        
		batch="${USER}_${runNum}_PionLT_Job.txt"
                tape_file=`printf $MSSstub $runNum`
		# Print the size of the raw .dat file (converted to GB) to screen. sed command reads line 3 of the tape stub without the leading size=
	        TapeFileSize=$(($(sed -n '4 s/^[^=]*= *//p' < $tape_file)/1000000000)) # This line gets the SIZE of the file from the tape stub
		if [[ $TapeFileSize == 0 ]];then
		    TapeFileSize=2
                fi
		echo "Raw .dat file is "$TapeFileSize" GB"
                ##Finds number of lines of input file##
                numlines=$(eval "wc -l < ${inputFile}")
                echo "Job $(( $i + 2 ))/$(( $numlines ))"
                echo "Running ${batch} for ${runNum}"
                cp /dev/null ${batch}
                ##Creation of batch script for submission
                echo "MAIL: ${USER}@jlab.org" >> ${batch}
                echo "PROJECT: c-kaonlt" >> ${batch} # Or whatever your project is!
		echo "TRACK: analysis" >> ${batch} ## Use this track for production running
		#echo "TRACK: debug" >> ${batch} ### Use this track for testing, higher priority
                echo "JOBNAME: PionLT_${runNum}" >> ${batch} ## Change to be more specific if you want
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
                echo "COMMAND:/group/c-pionlt/USERS/${USER}/hallc_replay_lt/UTIL_BATCH/Analysis_Scripts/PionLT.sh ${RUNTYPE} ${TARGET} ${runNum} ${MAXEVENTS}"  >> ${batch}
                echo "Submitting ${batch}"
                eval "swif2 add-jsub ${Workflow} -script ${batch} 2>/dev/null"
                echo " "
		sleep 2
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
	    eval 'swif2 run ${Workflow}'
	    break;;
        [Nn]* ) 
	        exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

