# hcswif
hcswif is a python script for generating JSON files that describe a swif2 workflow to be run on JLab's ifarm

The json output from `swif2 export <workflow>` is one long string, but the following command will display it in a pretty format:
```
swif2 export <workflow> | python -m json.tool > myswifjob_export.json
```

Visit these links for more details on swif2

https://scicomp.jlab.org/docs/swif2
https://scicomp.jlab.org/cli/swif.html
https://scicomp.jlab.org/cli/data.html

# Initial setup
You'll need to modify a few files so that hcswif points to the correct hcana, raw data, etc.

The following is a list of files and variables that you may need to modify:
```
1) hcswif.py
    - out_dir
    -json_dir
    - raw_dir
2) setup.sh
    - hcana_dir
    - hallc_replay_dir
    - Version of /site/12gev_physics/production.sh
```
out_dir must be somewhere to your  /farm_out/$USER/ directory.  Files with high read/write should not be sent to /volatile/ or /work.  You must be on an ifarm machine to access the /farm_out/ directories.  Failure to use the /farm_out/$USER directory will result in your jobs being cancelled followed by an email from CST.  If you do not have a /farm_out/ directory ensure you have a Slurm account.  If you have a Slurm account and no /farm_out/ directory run srun hostname to generate one.  
You must have a symbolic link to hcana in your hallc_replay_dir in order for the setup.sh and setup.csh scripts to work.  

# Usage
Note that hcswif must be run with python 3, not python 2.  On an ifarm computer, python3 executable paths and dependencies can be loaded with source /site/12gev_phys/softenv.sh 2.4.  The softenv number may increase as the farm gets upgraded.  You can only run swif2 on the ifarm computers.  Access to the /farm_out/ out_dir location is only available on an ifarm computer.  

```
usage: hcswif.py [-h] [--mode MODE] [--spectrometer SPECTROMETER]
                 [--run RUN [RUN ...]] [--events EVENTS] [--name NAME]
                 [--replay REPLAY] [--command COMMAND] [--filelist FILELIST]
                 [--account ACCOUNT] [--disk DISK] [--ram RAM] [--cpu CPU]
                 [--time TIME] [--shell SHELL]
```
Some parameters are optional, and some are only relevant for one mode. Optional parameters are assigned default values. Parameters may be specified in any order on the command line.

Parameter    | replay?  | command? | Description
------------ | -------- | -------- | ------------------------------------------------
mode         | -        | -        | Are we replaying runs or running a shell script?
spectrometer | required | -        | Which spectrometer? This specifies a replay script and what raw .dat is used
run          | required | -        | Either (1) a space-separated list of runs or ranges of runs or (2) `file runs.txt` where runs.txt contains one run number per line
events       | optional | -        | Number of events to use. Default is all events (i.e. -1)
replay       | optional | -        | Replay script to be used; path is relative to your hallc_replay directory. Defaults exist for each spectrometer.
command      | -        | required | Full path location of the shell script to be run
filelist     | -        | optional | List of files needed for your shell script
name         | optional | optional | Name of workflow. Default is hcswifXXXXXXXX, with a timestamp suffix
account      | optional | optional | Account to which the time should be accounted. 
disk         | optional | optional | How much disk space do you need in bytes? Default = 10GB
ram          | optional | optional | How much RAM do you need in bytes? Default = 2.5GB
cpu          | optional | optional | How many cores? Default = 1

# Examples
## Replay runs using default hcana scripts
This will replay 50k SHMS events for COIN runs 2187-2212, 2023-2066, and 2049 using the default script SCRIPTS/SHMS/PRODUCTION/replay_production_shms_coin.C
```
$ ./hcswif.py --mode replay --spectrometer SHMS_COIN --run 2187-2212 2023-2066 2049 --events 50000 --name myswifjob --account hallc
Wrote: /some/directory/myswifjob.json
$ swif2 import -file myswifjob.json
$ swif2 run myswifjob
```

## Replay runs using default hcana scripts
This will replay all HMS events for ALL runs using a file some_runs.dat that contains one full path file location per line.  The default HMS_ALL script SCRIPTS/HMS/PRODUCTION/replay_production_all_hms.C is used.  The disk space has been increased since the file size may be large for a HMS_ALL replay.
```
$ ./hcswif.py --mode replay --spectrometer HMS_ALL --run file /home/runlists/some_runs.dat --name myswifjob --disk 15000000000
Wrote: /some/directory/myswifjob.json
$ swif2 import -file myswifjob.json
$ swif2 run myswifjob
```

## Run a shell script or command, which may or may not be hcana-related
This example will submit a job that runs myscript.sh, which presumably does something more complicated than "regular" replay. It uses a filelist text file called "myfiles" that contains one full path file location per line. These files will be added to the 'input' list of the shell script's job. Note that instead of specifying a filelist, you may explicitly put appropriate `jget`s in your shell script to read your raw data from tape.
```
$ ./hcswif.py --mode command --command /some/directory/myscript.sh arg1 arg2 --name myswifjob --account hallc --filelist myfiles
Wrote: /some/directory/myswifjob.json
$ swif2 import -file myswifjob.json
$ swif2 run myswifjob
```

## Turn a text file list of shell scripts into a workflow with multiple jobs
hcswif will generate a workflow with one job per line in the text file myjobs.txt. Note that `--command`'s first argument `file` tells hcswif that this is a file to read, and not a shell script as in the previous example.
```
$ cat myjobs.txt
/some/where/myscript.sh arg1 arg2
/some/where/myscript.sh arg3 arg4
/some/where/myotherscript.sh

$ ./hcswif.py --mode command --command file /some/where/myjobs.txt --name test2
Wrote: /home/jmatter/hcswif/output/test2.json
```

## Warnings
If some parameters aren't specified (e.g. account, events, filelist) you will be warned and possibly asked if you want to use the default value.
```
$ ./hcswif.py --mode shell --command /some/directory/myscript.sh --name myswifjob
./hcswif.py:160: UserWarning: No account specified.
  warnings.warn('No account specified.')
Should I use account=hallc? (y/n): y
Wrote: /some/directory/myswifjob.json
```

## Swif errors
These are descriptions of some errors you may see when you run `swif2 status`. Thank you to [Hall D's wiki](https://halldweb.jlab.org/wiki/index.php/DEPRECATED_Offline_Monitoring_Archived_Data) for this info.

| ERROR | Description | Possible solution |
| ---------- | ----------- | ----------------- |
| SITE_PREP_FAIL | SWIF’s attempt to submit jobs to Slurm failed. Includes server-side problems as well as user failing to provide valid job parameters (e.g. incorrect account name, too many resources, etc.) | If requested resources are known to be correct, resubmit. Otherwise, modify job resources using `swif2 modify-job`.|
| SLURM_FAILED | Slurm reports the job FAILED with no specific details. | Verify jobs are valid, then resubmit. This can happen if the /raw/ directory is not set appropriately in hallc_replay.  |
| SWIF_OUTPUT_FAIL | Failure to copy one or more output files. Can be due to permission problem, quota problem, system error, etc. | Check if output files will exist after job execution and that output directory exists, resubmit jobs. |
| SWIF_INPUT_FAIL | SWIF failed to copy one or more of the requested input files, similar to output failures.  Can also happen if tape file is unavailable (e.g. missing/damaged tape) | Verify input file exists, then resubmit jobs. |
| SLURM_TIMEOUT | Job timed out. | If more time is needed for job, add more resources. Also check whether code is hanging. |
| SLURM_OUT_OF_MEMORY | Not enough resources, either RAM or disk space. | Add more resources for job. |
| SWIF_MISSING_OUTPUT | Output file specified by user was not found. | Check if output file exists at end of job. |
| SWIF_USER_NON_ZERO | User script exited with non-zero status code. | Your script exited with non-zero status. Check the code you are running. |
| SWIF_SYSTEM_ERROR | Job failed owing to a problem with swif2 (e.g. network connection timeout) | Resubmit jobs. |

## Debugging 
If recieving a SWIF_USER_NON_ZERO error or similar error which points to the script failing to run once resources are allocated, look at the out_dir/*.err files to identify problems.  If the script never runs, try copying the command line fo the output JSON file and run it on an interactive farm (ifarm) node.  Ensure all the output directories exist for hallc_replay including ROOTfiles and REPORT_OUTPUT.  Make sure these are symlinks to /volatile/ or /work/ or /cache/.  Large files should not be saved to /group/ or /home/.

SJDK - 22/02/22 - Merged in some material from UTIL_BATCH

### Comments

In principle, I see no issue with deleting the Auger_batch_scripts and just using the hscswif script to submit workflows, some comments on this
   - hcswif needs to incorporate setting of memory/disk allocation dynamically depending upon raw .dat file
     - This was a big issue I've run into previously, some files just fail entirely without setting an adequate disk space
   - hcswif needs to be tested with scripts from the Analysis_Scripts directory, some of these do a fairly large sequence of tasks
   - Need to edit/modify input run lists to work with hcswif (possibly), needs testing at least anyway
   - In some ways, I'd also just prefer it if running hcswif created AND submitted the workflow (as I've done in the Auger ones). I don't really see why this needs to be done as a separate command (how about just adding it as a y/n case to submit after creation?)

- I have some scripts which set up sym links, we could move these in since this is a common issue people run into (not having sym links setup in all of the places they're needed)

### Auger_batch_scripts

- Scripts for creating Auger style jobs and submitting them as part of a swif2 workflow
- Two templates included, .py and .sh versions. .py script ***REQUIRES*** UTIL_PION ltsep module
- Shell_Scripts
  - Subdirectory, include some examples of .sh scripts for job creation and submission

### Analysis_Scripts

- Some example shell scripts to do specific tasks such as detector calibrations, analysis and so on

### InputRunLists

- A selection of run lists for the Kaon/PionLT data. Could be added to with different user lists as needed