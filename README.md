# hcswif
hcswif is a python script for generating JSON files that describe a swif workflow to be run on JLab's ifarm

The json output is one long string, but the following command will display it in a pretty format:
```
python -m json.tool myswifjob.json
```

Visit these links for more details on swif

https://hallcweb.jlab.org/DocDB/0008/000871/001/SWIF%20Intro.pdf

https://scicomp.jlab.org/docs/swif

# Initial setup
You'll need to modify a few files so that hcswif points to the correct hcana, raw data, etc.

The following is a list of files and variables that you may need to modify:
```
1) hcswif.py
    - out_dir
    - raw_dir
2) setup.sh
    - hcana_dir
    - hallc_replay_dir
    - Version of /site/12gev_physics/production.sh
```

# Usage
Note that hcswif must be run with python 3, not python 2

```
usage: hcswif.py [-h] [--mode MODE] [--spectrometer SPECTROMETER]
                 [--run RUN [RUN ...]] [--events EVENTS] [--name NAME]
                 [--replay REPLAY] [--command COMMAND] [--filelist FILELIST]
                 [--project PROJECT] [--disk DISK] [--ram RAM] [--cpu CPU]
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
project      | optional | optional | Project to which the time should be accounted. Default is c-comm2017, but I might remove that to prevent accidental use of that account.
disk         | optional | optional | How much disk space do you need in bytes? Default = 10GB
ram          | optional | optional | How much RAM do you need in bytes? Default = 2.5GB
cpu          | optional | optional | How many cores? Default = 1
shell        | optional | optional | What shell should your jobs use? Default is bash


# Examples
## Replay runs using default hcana scripts
This will replay 50k SHMS events for COIN runs 2187-2212, 2023-2066, and 2049 using the default script SCRIPTS/SHMS/PRODUCTION/replay_production_shms_coin.C
```
$ ./hcswif.py --mode replay --spectrometer SHMS_COIN --run 2187-2212 2023-2066 2049 --events 50000 --name myswifjob --project c-comm2017
Wrote: /some/directory/myswifjob.json
$ swif import -file myswifjob.json
$ swif run myswifjob
```

## Run a shell script or command, which may or may not be hcana-related
This example will submit a job that runs myscript.sh, which presumably does something more complicated than "regular" replay. It uses a filelist text file called "myfiles" that contains one full path file location per line. These files will be added to the 'input' list of the shell script's job. Note that instead of specifying a filelist, you may explicitly put appropriate `jget`s in your shell script to read your raw data from tape.
```
$ ./hcswif.py --mode command --command /some/directory/myscript.sh arg1 arg2 --name myswifjob --project c-comm2017 --filelist myfiles
Wrote: /some/directory/myswifjob.json
$ swif import -file myswifjob.json
$ swif run myswifjob
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
If some parameters aren't specified (e.g. project, events, filelist) you will be warned and possibly asked if you want to use the default value.
```
$ ./hcswif.py --mode shell --command /some/directory/myscript.sh --name myswifjob
./hcswif.py:160: UserWarning: No project specified.
  warnings.warn('No project specified.')
Should I use project=c-comm2017? (y/n): y
Wrote: /some/directory/myswifjob.json
```

## swif errors
These are descriptions of some errors you may see when you run `swif status`. Thank you to [Hall D's wiki](https://halldweb.jlab.org/wiki/index.php/DEPRECATED_Offline_Monitoring_Archived_Data) for this info.

| ERROR | Description | Possible solution |
| ---------- | ----------- | ----------------- |
| AUGER-SUBMIT | SWIF’s attempt to submit jobs to Auger failed. Includes server-side problems as well as user failing to provide valid job parameters (e.g. incorrect project name, too many resources, etc.) | If requested resources are known to be correct, resubmit. Otherwise, modify job resources using `swif modify`.|
| AUGER-FAILED | Auger reports the job FAILED with no specific details. | Verify jobs are valid, then resubmit. |
| AUGER-OUTPUT-FAIL | Failure to copy one or more output files. Can be due to permission problem, quota problem, system error, etc. | Check if output files will exist after job execution and that output directory exists, resubmit jobs. |
| AUGER-INPUT-FAIL | Auger failed to copy one or more of the requested input files, similar to output failures.  Can also happen if tape file is unavailable (e.g. missing/damaged tape) | Verify input file exists, then resubmit jobs. |
| AUGER-TIMEOUT | Job timed out. | If more time is needed for job, add more resources. Also check whether code is hanging. |
| AUGER-OVER_RLIMIT | Not enough resources, either RAM or disk space. | Add more resources for job. |
| SWIF-MISSING-OUTPUT | Output file specified by user was not found. | Check if output file exists at end of job. |
| SWIF-USER-NON-ZERO | User script exited with non-zero status code. | Your script exited with non-zero status. Check the code you are running. |
| SWIF-SYSTEM-ERROR | Job failed owing to a problem with swif (e.g. network connection timeout) | Resubmit jobs. |
