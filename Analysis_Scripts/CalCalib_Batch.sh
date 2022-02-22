#!/bin/bash

### Stephen Kay --- University of Regina --- 08/04/21 ###
### An updated and improved script for running (via batch or otherwise) the calorimeter calibration
### REQUIRES two arguments, runnumber and spectrometer (HMS or SHMS, the caps are important!)
### If you want to run with LESS than all of the events, provide a third argument with # events

### Note, this script assumes a certain replay is used (which therefore generates a specific ROOTfile name/path)
### It also assumes that the calibration files for the Calorimeter are named in a consistent manner
### E.g. there is a "cuts", "geom" and normal calibration file

RUNNUMBER=$1
OPT=$2
### Check you've provided the first argument
if [[ $1 -eq "" ]]; then
    echo "I need a Run Number!"
    echo "Please provide a run number as input"
    exit 2
fi
### Check you have provided the second argument correctly
if [[ ! $2 =~ ^("HMS"|"SHMS")$ ]]; then
    echo "Please specify spectrometer, HMS or SHMS"
    exit 2
fi
### Check if a third argument was provided, if not assume -1, if yes, this is max events
if [[ $3 -eq "" ]]; then
    MAXEVENTS=-1
else
    MAXEVENTS=$3
fi
if [[ $OPT == "HMS" ]]; then
    spec="hms"
    elif [[ $OPT == "SHMS" ]]; then
    spec="shms"
fi
#if [[ ${USER} = "cdaq" ]]; then
#    echo "Warning, running as cdaq."
#    echo "Please be sure you want to do this."
#    echo "Comment this section out and run again if you're sure."
#    exit 2
#fi        
# Set path depending upon hostname. Change or add more as needed  
if [[ "${HOSTNAME}" = *"farm"* ]]; then  
    REPLAYPATH="/group/c-pionlt/online_analysis/hallc_replay_lt"
    if [[ "${HOSTNAME}" != *"ifarm"* ]]; then
	source /site/12gev_phys/softenv.sh 2.4
	source /apps/root/6.18.04/setroot_CUE.bash
    fi
    cd "/group/c-pionlt/hcana/"
    source "/group/c-pionlt/hcana/setup.sh"
    cd "$REPLAYPATH"
    source "$REPLAYPATH/setup.sh"
elif [[ "${HOSTNAME}" = *"qcd"* ]]; then
    REPLAYPATH="/group/c-pionlt/USERS/${USER}/hallc_replay_lt"
    source /site/12gev_phys/softenv.sh 2.4
    source /apps/root/6.18.04/setroot_CUE.bash
    cd "/group/c-pionlt/hcana/"
    source "/group/c-pionlt/hcana/setup.sh" 
    cd "$REPLAYPATH"
    source "$REPLAYPATH/setup.sh" 
elif [[ "${HOSTNAME}" = *"cdaq"* ]]; then
    REPLAYPATH="/home/cdaq/pionLT-2021/hallc_replay_lt"
elif [[ "${HOSTNAME}" = *"phys.uregina.ca"* ]]; then
    REPLAYPATH="/home/${USER}/work/JLab/hallc_replay_lt"
fi
cd $REPLAYPATH

### Check the extra folders you'll need exist, if they don't then make them
if [ ! -d "$REPLAYPATH/CALIBRATION/shms_cal_calib/Input" ]; then
    mkdir "$REPLAYPATH/CALIBRATION/shms_cal_calib/Input"
fi
if [ ! -d "$REPLAYPATH/CALIBRATION/shms_cal_calib/Output" ]; then
    mkdir "$REPLAYPATH/CALIBRATION/shms_cal_calib/Output"
fi
if [ ! -d "$REPLAYPATH/CALIBRATION/hms_cal_calib/Input" ]; then
    mkdir "$REPLAYPATH/CALIBRATION/hms_cal_calib/Input"
fi
if [ ! -d "$REPLAYPATH/CALIBRATION/hms_cal_calib/Output" ]; then
    mkdir "$REPLAYPATH/CALIBRATION/hms_cal_calib/Output"
fi
### Note, this is a stop gap, the calibration script should really just look for a sym link in the base directory itself
### Check the sym link you'll need exists, if it doesn't, make it!
if [ ! -L "$REPLAYPATH/CALIBRATION/hms_cal_calib/ROOTfiles" ]; then
    ln -s "/volatile/hallc/c-pionlt/online_analysis/ROOTfiles" "$REPLAYPATH/CALIBRATION/hms_cal_calib/ROOTfiles"
fi
if [ ! -L "$REPLAYPATH/CALIBRATION/shms_cal_calib/ROOTfiles" ]; then
    ln -s "/volatile/hallc/c-pionlt/online_analysis/ROOTfiles" "$REPLAYPATH/CALIBRATION/shms_cal_calib/ROOTfiles"
fi

### Run the first replay script, then, run the calibration macro
ROOTFILE="$REPLAYPATH/ROOTfiles/Calib/Cal/"$OPT"_Cal_Calib_"$RUNNUMBER"_"$MAXEVENTS".root"
if [ -f "${ROOTFILE}" ]; then
    read -p "${ROOTFILE} already found, process again anyway?" prompt
    if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]]; then
	eval "$REPLAYPATH/hcana -l -q \"SCRIPTS/COIN/CALIBRATION/"$OPT"Cal_Calib_Coin.C($RUNNUMBER,$MAXEVENTS)\""
    else
	echo "Not replaying file again, continuing"
    fi
elif [ ! -f "${ROOTFILE}" ]; then
    eval "$REPLAYPATH/hcana -l -q \"SCRIPTS/COIN/CALIBRATION/"$OPT"Cal_Calib_Coin.C($RUNNUMBER,$MAXEVENTS)\""
fi

### Need to determine the database file used by the replay script
REPLAYSCRIPT="${REPLAYPATH}/SCRIPTS/COIN/CALIBRATION/${OPT}Cal_Calib_Coin.C"
while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ "//" ]]; then continue;
    elif [[ $line =~ "gHcParms->AddString(\"g_ctp_database_filename\"," ]]; then
	tmpstring=$(echo $line| cut -d "," -f2) # This is the path to the DBase file but with some junk in the string
	tmpstring2=$(echo $tmpstring | sed 's/[");]//g') # Sed command to strip junk (", ) or ; ) from the string
	DBASEFILE="${REPLAYPATH}/${tmpstring2}"
    fi
done < "$REPLAYSCRIPT"

### Now, we need to grab the correct parameter file
# This could probably be simplified slightly, but basically it finds the right "block" and sets a flag to pick up the NEXT param file listed
TestingVar=$((0))
while IFS='' read -r line || [[ -n "$line" ]]; do
    # If the line in the file is blank, contains a hash or has g_ctp in it, skip it, only leaves the lines which contain the run numbe ranges
    if [ -z "$line" ] ; then continue;
    elif [[ $line =~ "#" ]]; then continue;
    elif [[ $line =~ "g_ctp_kin" ]]; then continue;
    elif [[ $line != *"g_ctp_par"* ]]; then #If line is NOT the one specifying the param file, then get the run numbers
	# Starting run number is just the field before the - delimiter (f1), ending run number is the one after (f2)
	# -d specifies the delimiter which is the term in speech marks
	RunStart=$(echo $line| cut -d "-" -f1)
	RunEnd=$(echo $line| cut -d "-" -f2)
	if [ "$RUNNUMBER" -ge "$RunStart" -a "$RUNNUMBER" -le "$RunEnd" ]; then
	    TestingVar=$((1)) # If run number in range, set testing var to 1
	else TestingVar=$((0)) # If not in range, set var to 0
	fi
    elif [[ $line =~ "g_ctp_par" ]]; then
	if [ $TestingVar == 1 ]; then
	    tmpstring3=$(echo $line| cut -d "=" -f2) # tmpstrings could almost certainly be combined into one expr
	    BASE_PARAMFILE=$(echo $tmpstring3 | sed 's/["]//g')
	    BASE_PARAMFILE_PATH="${REPLAYPATH}/${BASE_PARAMFILE}"
	    # Now we have the param file, grab the relevant parameter file from it depending upon spectrometer
	    while IFS='' read -r line || [[ -n "$line" ]]; do
		# Grab the relevant calorimeter param file
		if [ $OPT == "HMS" ]; then
		    if [[ $line =~ "PARAM/HMS/CAL/" ]]; then # Grab lines relating to HMS calorimeter param files
			if [[ $line != *"cuts"* && $line != *"geom"* ]]; then # If it's NOT the line specifying the cuts or geomtry, grab the file path
			    tmpstring=$(echo $line| cut -d '"' -f2)
			    CALIB_PARAMPATH="${REPLAYPATH}/${tmpstring}"
			fi
		    fi
		elif [ $OPT == "SHMS" ]; then
		    if [[ $line =~ "PARAM/SHMS/CAL/" ]]; then # Grab lines relating to SHMS calorimeter param files
			if [[ $line != *"cuts"* && $line != *"geom"* ]]; then # If it's NOT the line specifying the cuts or geometry, grab the file path
			    tmpstring=$(echo $line| cut -d '"' -f2)
			    echo "$tmpstring"
			    CALIB_PARAMPATH="${REPLAYPATH}/${tmpstring}"
			fi
		    fi
		fi
	    done < "$BASE_PARAMFILE_PATH"
	else continue
	fi
    fi
done < "$DBASEFILE"

if [ ! -f "${CALIB_PARAMPATH}" ]; then
    echo "Script thinks that the relevant Calorimeter param file used in the replay is -"
    echo "${CALIB_PARAMPATH}"
    echo "But this file does not exist! Check it exists or modify the section of this script that searches for the file accordingly and re-run!"
    exit 1
fi

if [ ! -f "${ROOTFILE}" ]; then
    echo "Script thinks that the calibration rootfile is -"
    echo "${ROOTFILE}"
    echo "But this file doesn't exist! Check it replayed correctly and re-run!"
    exit 2
fi

echo "Replayed using ${OPT} Calorimeter parameters in ${CALIB_PARAMPATH}"
echo "Using this to calibrate ${OPT} Calorimeter"
cd "$REPLAYPATH/CALIBRATION/"$spec"_cal_calib/"

# # Copy the input file with a one specific to this run
 cp "input.dat" "Input/input_"$RUNNUMBER".dat"
# # Snip off the parameters in the input file leaving only the setup conditions and add a new line to the file (which is CRUCIAL!)
if [ $OPT == "HMS" ]; then
     sed -i '9, $d' "Input/input_"$RUNNUMBER".dat"
     echo $'\n' >> "Input/input_"$RUNNUMBER".dat"
elif [ $OPT == "SHMS" ]; then
     sed -i '10, $d' "Input/input_"$RUNNUMBER".dat"
fi
# # We now need to copy in the relevant parameters that were used in the replay
# # Copies block of parameters and appends them to our input file, expects block of params to be in first 21 lines!
 sed -n '1, 21p' ${CALIB_PARAMPATH} | tee -a "Input/input_"$RUNNUMBER".dat"
# The input is now setup so process the calibration script on the corresponding detector
# Note, the PREFIX argument to the hcana script will need to be changed according to the replay script
 if [ $OPT == "HMS" ]; then
     eval "${REPLAYPATH}/hcana -l -q -b 'hcal_calib.cpp+(\"HMS_Cal_Calib\", $RUNNUMBER, $MAXEVENTS)'"
     sleep 2
     if [ -f "HMS_Cal_Calib_${RUNNUMBER}_${MAXEVENTS}.pdf" ]; then
	 mv "HMS_Cal_Calib_"$RUNNUMBER"_"$MAXEVENTS".pdf" "Output/HMS_Cal_Calib_"$RUNNUMBER"_"$MAXEVENTS".pdf"
     elif [ ! -f "HMS_Cal_Calib_${RUNNUMBER}_${MAXEVENTS}.pdf" ]; then 
	 echo "Calibration output pdf not found! Calibration may have failed!"
     fi
     if [ -f "hcal.param.HMS_Cal_Calib_${RUNNUMBER}_${MAXEVENTS}" ]; then
	 mv "hcal.param.HMS_Cal_Calib_"$RUNNUMBER"_"$MAXEVENTS "Output/hcal.param.HMS_Cal_Calib_"$RUNNUMBER"_"$MAXEVENTS
     elif [ ! -f "hcal.param.HMS_Cal_Calib_${RUNNUMBER}_${MAXEVENTS}" ]; then
	 echo "Calibration output param file not found! Calibration may have failed!"
     fi
 fi
 if [ $OPT == "SHMS" ]; then
     eval "${REPLAYPATH}/hcana -l -q -b 'pcal_calib.cpp+(\"SHMS_Cal_Calib\", $RUNNUMBER, $MAXEVENTS)'"
     sleep 2
     if [ -f "SHMS_Cal_Calib_${RUNNUMBER}_${MAXEVENTS}.pdf" ]; then
	 mv "SHMS_Cal_Calib_"$RUNNUMBER"_"$MAXEVENTS".pdf" "Output/SHMS_Cal_Calib_"$RUNNUMBER"_"$MAXEVENTS".pdf"
     elif [ ! -f "SHMS_Cal_Calib_${RUNNUMBER}_${MAXEVENTS}.pdf" ]; then 
	 echo "Calibration output pdf not found! Calibration may have failed!"
     fi
     if [ -f "pcal.param.SHMS_Cal_Calib_${RUNNUMBER}_${MAXEVENTS}" ]; then
	 mv "pcal.param.SHMS_Cal_Calib_"$RUNNUMBER"_"$MAXEVENTS "Output/pcal.param.SHMS_Cal_Calib_"$RUNNUMBER"_"$MAXEVENTS
     elif [ ! -f "pcal.param.SHMS_Cal_Calib_${RUNNUMBER}_${MAXEVENTS}" ]; then
	 echo "Calibration output param file not found! Calibration may have failed!"
     fi
 fi
exit 0
