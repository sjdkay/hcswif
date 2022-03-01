#! /bin/bash

### Stephen Kay, University of Regina
### 03/03/21
### stephen.kay@uregina.ca
### A batch submission script based on an earlier version by Richard Trotta, Catholic University of America
              
##### Modify required resources as needed!                                                                                                                                   
##### This version is modified to use the batch queueing system on Lark
echo "Running as ${USER}" # Checks who you're running this as'
RunList=$1
if [[ -z "$1" ]]; then
    echo "I need a run list process!"
    echo "Please provide a run list as input"
    exit 2
fi
##Output history file##
historyfile=hist.$( date "+%Y-%m-%d_%H-%M-%S" ).log # Creates a log file
##Output batch script##
batch="${USER}_Job.txt" # The name of the job submission script it'll create each time
##Input run numbers##
inputFile="/home/${USER}/work/JLab/hallc_replay_lt/hcswif/InputRunLists/${RunList}"


while true; do
    read -p "Do you wish to begin a new batch submission? (Please answer yes or no) " yn # Check you actually want to do this
    case $yn in
        [Yy]* )
            i=-1
            (
            ##Reads in input file##
            while IFS='' read -r line || [[ -n "$line" ]]; do # Reads each line in the file one by one
                echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                echo "Run number read from file: $line" # Grabs the run number
                echo ""
                ##Run number#
                runNum=$line
                tmp=tmp
                ##Finds number of lines of input file##
                numlines=$(eval "wc -l < ${inputFile}")
                echo "Job $(( $i + 2 ))/$(( $numlines +1 ))"
                echo "Running ${batch} for ${runNum}"
                cp /dev/null ${batch}
                ##Creation of batch script for submission##                                    
                echo "#!/bin/csh" >> ${batch} # Tells your job which shell to run in
		echo "#PBS -N PionLT_${runNum}" >> ${batch} # Name your job                                                                           
		echo "#PBS -m abe" >> ${batch} # Email you on job start, end or error
		echo "#PBS -M ${USER}@jlab.org" >>${batch} # Your email address, change it to be what you like
		echo "#PBS -r n" >> ${batch} # Don't re-run if it crashes
		echo "#PBS -o  /home/${USER}/trq_output/${runNum}.out" >> ${batch} # Output directory and file name, set to what you like
		echo "#PBS -e  /home/${USER}/trq_output/${runNum}.err" >> ${batch} # Error output directory and file name
		echo "date" >> ${batch} 
		echo "./home/${USER}/work/JLab/hallc_replay_lt/hcswif/Analysis_Scripts/Full_Replay_Lark.csh ${runNum}" >> ${batch} # Run your script, change this to what you like
		echo "date">>${batch}
		echo "exit">>${batch} # End of your job script
		echo "Submitting batch"
                eval "qsub ${batch} 2>/dev/null" # Use qsub to actually submit your job
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
	    done < "$inputFile" # Keeps going till it hits the end of the input file
	    )
	    break;;
        [Nn]* ) 
	    exit;;
        * ) echo "Please answer yes or no.";; # What happens if you enter anything but yes or no
    esac
done
