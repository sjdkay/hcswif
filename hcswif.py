#!/usr/bin/env python3
import os
import re
import sys
import copy
import json
import shutil
import getpass
import argparse
import datetime
import warnings
import subprocess # SJDK 28/02/22 - Addded subprocess to run certain commands

################################################################################################################################################
# SJDK - 28/02/22 - Short y/n loop for use later 
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

#------------------------------------------------------------------------------
# Define environment

# Where do you want your job output (json files, stdout, stderr)?
out_dir   = os.path.join('/farm_out/', getpass.getuser() , 'hcswif/output')
json_dir = os.path.join('/home/', getpass.getuser() , 'hcswif/json')
# SJDK 28/02/22 - Added y/n question to create folders if they do not already exist
# Why does the script run at all if these do not exist? This should be a hard exit if they aren't found (and aren't created)
# Surely scripts will not run subsequently if these are missing?
if not os.path.isdir(out_dir):
    warnings.warn('out_dir: ' + out_dir + ' does not exist')
    print("You may not have a Slurm account or may not have run a job before - execute srun hostname")
    while yes_or_no("Do you want to make this directory?"):
        subprocess.call(["mkdir","/farm_out/"+getpass.getuser()+"/hcswif"])
        subprocess.call(["mkdir","/farm_out/"+getpass.getuser()+"/hcswif/output"])
        break
if not os.path.isdir(json_dir):
    warnings.warn('json_dir: ' + json_dir + ' does not exist')
    while yes_or_no("Do you want to make this directory?"):
        subprocess.call(["mkdir","/home/"+getpass.getuser()+"/hcswif"])
        subprocess.call(["mkdir","/home/"+getpass.getuser()+"/hcswif/json"])
        break
# Where is your raw data?
raw_dir = '/mss/hallc/spring17/raw'
if not os.path.isdir(raw_dir):
    warnings.warn('raw_dir: ' + raw_dir + ' does not exist')

# Where is hcswif?
hcswif_dir = os.path.dirname(os.path.realpath(__file__))

# hcswif_prefix is used as prefix for workflow, job names, filenames, etc.
now = datetime.datetime.now()
datestr = now.strftime("%Y%m%d%H%M")
hcswif_prefix = 'hcswif' + datestr

#------------------------------------------------------------------------------
# This is the main body of hcswif
def main():
    # Parse the arguments specified by the user
    parsed_args = parseArgs()

    # Turn those arguments into a swif workflow in json format and
    # generate a filename for the json file to write.
    workflow, outfile = getWorkflow(parsed_args)

    # Write the workflow to disk
    writeWorkflow(workflow, outfile)

#------------------------------------------------------------------------------
def parseArgs():
    parser = argparse.ArgumentParser()

    # Add arguments
    parser.add_argument('--mode', nargs=1, dest='mode',
            help='type of workflow (replay or command)')
    parser.add_argument('--spectrometer', nargs=1, dest='spectrometer',
            help='spectrometer to analyze (HMS_ALL, SHMS_ALL, HMS_PROD, SHMS_PROD, COIN, HMS_COIN, SHMS_COIN, HMS_SCALER, SHMS_SCALER)')
    parser.add_argument('--run', nargs='+', dest='run',
            help='a list of run numbers and ranges; or a file listing run numbers')
    parser.add_argument('--events', nargs=1, dest='events',
            help='number of events to analyze (default=all)')
    parser.add_argument('--name', nargs=1, dest='name',
            help='workflow name')
    parser.add_argument('--replay', nargs=1, dest='replay',
            help='hcana replay script; path relative to hallc_replay')
    parser.add_argument('--command', nargs="+", dest='command',
            help='shell command/script to run; or a file containing scripts to run (command mode only)')
    parser.add_argument('--filelist', nargs=1, dest='filelist',
            help='file containing list of files to get from tape (command mode only)')
    parser.add_argument('--account', nargs=1, dest='account',
            help='name of account')
    parser.add_argument('--disk', nargs=1, dest='disk',
            help='disk space in bytes')
    parser.add_argument('--ram', nargs=1, dest='ram',
            help='ram space in bytes')
    parser.add_argument('--cpu', nargs=1, dest='cpu',
            help='cpu cores')
    parser.add_argument('--time', nargs=1, dest='time',
            help='max run time per job in seconds allowed before killing jobs')
    parser.add_argument('--shell', nargs=1, dest='shell',
            help='Currently a shell cannot be specified in SWIF2')

    # Check if any args specified
    if len(sys.argv) < 2:
        raise RuntimeError(parser.print_help())

    # Return parsed arguments
    return parser.parse_args()

#------------------------------------------------------------------------------
def getWorkflow(parsed_args):
    # Initialize
    workflow = initializeWorkflow(parsed_args)
    outfile = os.path.join(json_dir, workflow['name'] + '.json')

    # Get jobs
    if parsed_args.mode==None:
        raise RuntimeError('Must specify a mode (replay or command)')
    mode = parsed_args.mode[0].lower()
    if mode == 'replay':
        workflow['jobs'] = getReplayJobs(parsed_args, workflow['name'])
    elif mode == 'command':
        workflow['jobs'] = getCommandJobs(parsed_args, workflow['name'])
    else:
        raise ValueError('Mode must be replay or command')

    # Add account to jobs
    workflow = addCommonJobInfo(workflow, parsed_args)

    return workflow, outfile

#------------------------------------------------------------------------------
def initializeWorkflow(parsed_args):
    workflow = {}
    if parsed_args.name==None:
        workflow['name'] = hcswif_prefix
    else:
        workflow['name'] = parsed_args.name[0]

    return workflow

#------------------------------------------------------------------------------
def getReplayJobs(parsed_args, wf_name):
    # Spectrometer
    spectrometer = parsed_args.spectrometer[0]
    if spectrometer.upper() not in ['HMS_ALL', 'SHMS_ALL', 'HMS_PROD', 'SHMS_PROD', 'COIN', 'HMS_COIN', 'SHMS_COIN', 'HMS_SCALER', 'SHMS_SCALER']:
        raise ValueError('Spectrometer must be HMS_ALL, SHMS_ALL, HMS_PROD, SHMS_PROD, COIN, HMS_COIN, SHMS_COIN, HMS_SCALER, or SHMS_SCALER')

    # Run(s)
    if parsed_args.run==None:
        raise RuntimeError('Must specify run(s) to process')
    else:
        runs = getReplayRuns(parsed_args.run)

    # Replay script to use
    if parsed_args.replay==None:
        # User has not specified a script, so we provide them with default options

        # COIN has two options: hElec_pProt or pElec_hProt depending on
        # the spectrometer configuration
        if spectrometer.upper() == 'COIN':
            print('COIN replay script depends on spectrometer configuration.')
            print('1) HMS=e, SHMS=p (SCRIPTS/COIN/PRODUCTION/replay_production_coin_hElec_pProt.C)')
            print('2) HMS=p, SHMS=e (SCRIPTS/COIN/PRODUCTION/replay_production_coin_pElec_hProt.C)')
            replay_script = input("Enter 1 or 2: ")

            script_dict = { '1' : 'SCRIPTS/COIN/PRODUCTION/replay_production_coin_hElec_pProt.C',
                            '2' : 'SCRIPTS/COIN/PRODUCTION/replay_production_coin_pElec_hProt.C' }
            replay_script = script_dict[replay_script]

        # We have 4 options for singles replay; "real" singles or "coin" singles
        else:
            script_dict = { 'HMS_ALL'     : 'SCRIPTS/HMS/PRODUCTION/replay_production_all_hms.C',
                            'SHMS_ALL'    : 'SCRIPTS/SHMS/PRODUCTION/replay_production_all_shms.C',
                            'HMS_PROD'    : 'SCRIPTS/HMS/PRODUCTION/replay_production_hms.C',
                            'SHMS_PROD'   : 'SCRIPTS/SHMS/PRODUCTION/replay_production_shms.C',
                            'HMS_COIN'    : 'SCRIPTS/HMS/PRODUCTION/replay_production_hms_coin.C',
                            'SHMS_COIN'   : 'SCRIPTS/SHMS/PRODUCTION/replay_production_shms_coin.C',
                            'HMS_SCALER'  : 'SCRIPTS/HMS/SCALERS/replay_hms_scalers.C',
                            'SHMS_SCALER' : 'SCRIPTS/SHMS/SCALERS/replay_shms_scalers.C' }
            replay_script = script_dict[spectrometer.upper()]
    # User specified a script so we use that one
    else:
        replay_script = parsed_args.replay[0]

    # Number of events; default is -1 (i.e. all)
    if parsed_args.events==None:
        warnings.warn('No events specified. Analyzing all events.')
        evts = -1
    else:
        evts = parsed_args.events[0]

    # Which hcswif shell script should we use? bash or csh?
    if parsed_args.shell==None:
        batch = os.path.join(hcswif_dir, 'hcswif.sh')
    elif re.search('bash', parsed_args.shell[0]):
        batch = os.path.join(hcswif_dir, 'hcswif.sh')
    elif re.search('csh', parsed_args.shell[0]):
        batch = os.path.join(hcswif_dir, 'hcswif.csh')

    # Create list of jobs for workflow
    jobs = []
    for run in runs:
        job = {}

        # Assume coda stem looks like shms_all_XXXXX, hms_all_XXXXX, or coin_all_XXXXX
        if 'coin' in spectrometer.lower():
            # shms_coin and hms_coin use same coda files as coin
            coda_stem = 'coin_all_' + str(run).zfill(5)
        elif 'all' in spectrometer.lower():
            # otherwise hms_all_XXXXX or shms_all_XXXXX
            all_spec  = spectrometer.replace('_ALL', '')
            coda_stem = all_spec.lower() + '_all_' + str(run).zfill(5)
        elif 'prod' in spectrometer.lower():
            # otherwise hms_all_XXXXX or shms_all_XXXXX
            prod_spec = spectrometer.replace('_PROD', '')
            coda_stem = prod_spec.lower() + '_all_' + str(run).zfill(5)
        elif 'scaler' in spectrometer.lower():
            # otherwise hms_all_XXXXX or shms_all_XXXXX
            scaler_spec = spectrometer.replace('_SCALER', '')
            coda_stem   = scaler_spec.lower() + '_all_' + str(run).zfill(5)
        else:
            # otherwise hms_all_XXXXX or shms_all_XXXXX
            coda_stem = spectrometer.lower() + '_all_' + str(run).zfill(5)

        coda = os.path.join(raw_dir, coda_stem + '.dat')

        # Check if raw data file exist
        if not os.path.isfile(coda):
            warnings.warn('RAW DATA: ' + coda + ' does not exist. Skipping this job.')
            continue

        job['name'] =  wf_name + '_' + coda_stem
        job['inputs'] = [{}]
        job['inputs'][0]['local'] = os.path.basename(coda)
        job['inputs'][0]['remote'] = coda

        # command for job is `/hcswifdir/hcswif.sh REPLAY RUN NUMEVENTS`
        job['command'] = [" ".join([batch, replay_script, str(run), str(evts)])]

        jobs.append(copy.deepcopy(job))

    return jobs

#------------------------------------------------------------------------------
def getReplayRuns(run_args):
    runs = []
    # User specified a file containing runs
    if (run_args[0]=='file'):
        filelist = run_args[1]
        f = open(filelist,'r')
        lines = f.readlines()

        # We assume user has been smart enough to only specify valid run numbers
        # or, at worst, lines only containing a \n
        for line in lines:
            run = line.strip('\n')
            if len(run)>0:
                runs.append(int(run))

    # Arguments are either individual runs or ranges of runs. We check with a regex
    else:
        for arg in run_args:
            # Is it a range? e.g. 2040-2055
            if re.match('^\d+-\d+$', arg):
                limits = re.split(r'-', arg)
                first = int(limits[0])
                last = int(limits[1]) + 1 # range(n,m) stops at m-1

                for run in range(first, last):
                    runs.append(run)

            # Is it a single run? e.g. 2049
            elif re.match('^\d+$', arg):
                runs.append(int(arg))

            # Else, invalid argument so we warn and skip it
            else:
                warnings.warn('Invalid run argument: ' + arg)

    return runs

#------------------------------------------------------------------------------
def getCommandJobs(parsed_args, wf_name):

    # command for job should have been specified by user
    if parsed_args.command==None:
        raise RuntimeError('Must specify command for batch job')

    jobs = []
    commands = []

    # User specified a text file containing commands
    if (parsed_args.command[0]=='file'):
        filelist = parsed_args.command[1]
        f = open(filelist,'r')
        lines = f.readlines()

        # We assume user has been smart enough to only specify valid commands
        # or, at worst, lines only containing a \n
        for line in lines:
            cmd = line.strip('\n')
            if len(cmd)>0:
                commands.append(cmd)

    # Otherwise user only specified one command, which may or may not have arguments.
    # join() works in either case.
    else:
        cmd = ' '.join(str(element) for element in parsed_args.command)
        commands.append(cmd)

    for cmd in commands:
        job = {}
        job['name'] = wf_name + '_job' + str(len(jobs))

        job['command'] = cmd

        # Add any necessary files from tape
        if parsed_args.filelist==None:
            warnings.warn('No file list specified. Assuming your shell script has any necessary jgets')
        else:
            filelist = parsed_args.filelist[0]
            f = open(filelist,'r')
            lines = f.readlines()

            # We assume user has been smart enough to only specify valid files
            # or, at worst, lines only containing a \n
            job['inputs'] = []
            for line in lines:
                filename = line.strip('\n')
                if len(filename)>0:
                    if not os.path.isfile(filename):
                        warnings.warn('RAW DATA: ' + filename + ' does not exist')
                    inp={}
                    inp['local'] = os.path.basename(filename)
                    inp['remote'] = filename
                    job['inputs'].append(inp)

        jobs.append(copy.deepcopy(job))

    return jobs

#------------------------------------------------------------------------------
def addCommonJobInfo(workflow, parsed_args):
    # Account
    # TODO: Remove default?
    if parsed_args.account==None:
        warnings.warn('No account specified.')

        account_prompt = 'x'
        while account_prompt.lower() not in ['y', 'n', 'yes', 'no']:
            account_prompt = input('Should I use account=hallc? (y/n): ')

        if account_prompt.lower() in ['y', 'yes']:
            account = 'hallc'
        else:
            raise RuntimeError('Please specify account as argument')
    else:
        account = parsed_args.account[0]

    # Disk space in bytes
    if parsed_args.disk==None:
        disk_bytes = 10000000000
    else:
        disk_bytes = int(parsed_args.disk[0])

    # RAM in bytes
    if parsed_args.ram==None:
        ram_bytes = 2500000000
    else:
        ram_bytes = int(parsed_args.ram[0])

    # CPUs
    if parsed_args.cpu==None:
        cpu = 1
    else:
        cpu = int(parsed_args.cpu[0])

    # Max time in seconds before killing jobs
    if parsed_args.time==None:
        time = 14400
    else:
        time = int(parsed_args.time[0])

    # Shell
    if parsed_args.shell==None:
        shell = shutil.which('bash')
    else:
        shell = shutil.which(parsed_args.shell[0])

    # Loop over jobs and add info
    for n in range(0, len(workflow['jobs'])):
        job = copy.deepcopy(workflow['jobs'][n])

        job['account'] = account

        job['stdout'] = os.path.join(out_dir, job['name'] + '.out')
        job['stderr'] = os.path.join(out_dir, job['name'] + '.err')

        # TODO: Allow user to specify all of these parameters
        job['constraint'] = 'centos79'
        job['partition'] = 'production'
        job['disk_bytes'] = disk_bytes
        job['ram_bytes'] = ram_bytes
        job['cpu_cores'] = cpu
        job['time_secs'] = time

        workflow['jobs'][n] = copy.deepcopy(job)
        job.clear()

    return workflow

#------------------------------------------------------------------------------
def writeWorkflow(workflow, outfile):
    with open(outfile, 'w') as f:
        json.dump(workflow, f, sort_keys=True, indent=2, separators=(',', ': '))

    print('Wrote: ' + outfile)
    return

#------------------------------------------------------------------------------
if __name__ == "__main__":
    main()
