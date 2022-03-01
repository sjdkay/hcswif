# Auger_batch_scripts

22/02/22  
Stephen JD Kay  
University of Regina  

- This directory contains a template for creating a swif2 job submission script. It utilises the add-jsub functionality of swif2 to make simple, readable auger style jobs that are submitted to a swif2 workflow.
  - By default, the templates create the job, submit it and then delete it (to prevent directory clogging due to loads of small text files floating about)
- There is a python based script and a shell script based version.

- There are examples of older shell scripts in a sub directory here.
  - Shell_BatchSub_Scripts/
- These work in the same way, simply creating the auger job using shell commands rather than python.

- There are example analysis scripts in the sub directory here too
  - Analysis_Scripts

- Input run lists to provide as an argument to the batch submission script are also included in a sub directory
  -InputRunLists