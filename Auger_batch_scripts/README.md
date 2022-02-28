# Auger_batch_scripts

22/02/22  
Stephen JD Kay  
University of Regina  

- This directory contains a template for creating a swif2 job submission script. It utilises the add-jsub functionality of swif2 to make simple, readable auger style jobs that are submitted to a swif2 workflow.

- There is a python based script (which requires the ltsep package from UTIL_PION) and a shell script based version.
  - I have included the ltsep package in this folder
  - cp -r ltsep ~/.local/lib/python3.4/site-packages/
    - OR whatever version of python you're using if you aren't using 3.4
  - If you are not using /group/c-kaonlt or /group/c-pionlt, you will need to add a path file to ltsep/PATH_TO_DIR
    - Use pionlt_user_farm.path as a base, adjust the paths in here to suit your needs   

- There are examples of older shell scripts in a sub directory here.
  - Shell_Scripts/
- These work in the same way, simply creating the auger job using shell commands rather than python.