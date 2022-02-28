# Analysis_Scripts

22/02/22  
Stephen JD Kay  
University of Regina  

- A collection of shell scripts that can be called in a batch job to run some commands.
  - These are intended for use with the Auger_batch_scripts, you could modify them for usage with hcswif though
  - Note that these typically require a run number as an input *each time they are executed*
  - This does not look to me like it would work with hcswif as it currently is
- These scripts were for use in Kaon/PionLT, the pathing is set accordingly. However, changing this is usually as simple as adjusting REPLAYPATH/UTILPATH e.t.c.
- These require the setup of some sym links for data input/output.
  - See SymLinkSetup_iFarm.sh for the folders/links that are needed, with minimal adjustment
    - Edit the paths in block 7-30 and adjust hallc_replay_lt to hallc_replay and so on as required