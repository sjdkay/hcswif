# Auger_batch_scripts

22/02/22  
Stephen JD Kay  
University of Regina  

- This directory contains a template for creating a swif2 job submission script. It utilises the add-jsub functionality of swif2 to make simple, readable auger style jobs that are submitted to a swif2 workflow.

- There is a python based script (which requires the ltsep package from UTIL_PION) and a shell script based version.

- To get ltsep from UTIL_PION
  - Grab the latest branch/version - LTSep_Analysis_2022 - https://github.com/JeffersonLab/UTIL_PION/tree/LTSep_Analysis_2022
  - Clone this somewhere and switch to the correct branch
  - cp -r bin/python/ltsep ~/.local/lib/python3.4/site-packages/
    - OR whatever version of python you're using if you aren't using 3.4

- There are examples of older shell scripts in a sub directory here.
  - Shell_Scripts/
- These work in the same way, simply creating the auger job using shell commands rather than python.