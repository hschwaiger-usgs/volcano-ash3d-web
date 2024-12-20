Ash3d_web
==========

This repository contains a collection of tools and data files useful for automatic Ash3d runs
using GFS forecast data or NCEP 50-year reanalysis data.  

To build the tools and install to the expected location (`/opt/USGS/Ash3d/`), type, from
`volcano-ash3d-web/src`:  

`make all`  

`sudo make install`  

To remove the installation, type `make uninstall`


Usage
-----

The run script `runAsh3d.sh` can
be called with a couple of command-line arguments specifying the run directory and an
output zipfile name. The script then searches for the file `ash3d_input.inp` in the run
directory, runs the model and then runs post-processing scripts to produce output maps.

Alternatively, simplified runs can be automatically started using the run scripts,
`runAsh3d_ac.sh` for ash cloud cases or `runAsh3d_dp.sh` for deposit cases. These have the
same command-line argument format as `runAsh3d.sh`, but instead search for simplified
input files `ash3d_input_ac.inp` and `ash3d_input_dp.inp` respectively. Examples are given
in the `volcano-ash3d-web/examples` folder. For these simplified cases, tools from the
`src` folder are used to create full input files for the cloud and the deposit cases. An
initial coarse grid case is run with the coarse model output determining the domain of the
grid of the full resolution model run.

Within these scripts, once the full Ash3d job is completed, one or more post-processing
scripts are run to generate output maps and animated gifs.  

1. `GFSVolc_to_gif_ac_traj.sh`: This script is used for post-processing cloud runs and expects
the trajectory code to have also been run. Static maps are created with Generic Mapping Tools (GMT)
with time-series output bundled into an animated gif.
2. `GFSVolc_to_gif_dp.sh`: This script is used for post-processing deposit runs, producing
output in English units consistent with levels used the the National Weather Service.
3. `GFSVolc_to_gif_dp_mm.sh`: Script similar to `GFSVolc_to_gif_dp.sh` but produces maps in metric
units.
4. `GFSVolc_to_gif_tvar.sh`: This is a generalized script the can produce iGMT maps (and animated gifs)
as with the above scripts.
5. `GMT_Ash3d_to_gif.sh`: Tool to build GMT maps of Ash3d output without requiring trajectory
files.
6. `PP_Ash3d_to_gif.sh`: This is a further generalization of the post-processing scripts
which uses the tool Ash3d_PostProc.

Many auxillary tools are built that are used to selecting which cities are in the domain,
where legends should be placed so as not to overprint data. Note that some of this functionality
has been included in `volcano-ash3d` through `Ash3d_PostProc`, such as placing cities. The
shared files `world_cities.txt` and `GlobalAirports_ewert.txt` are in both repositories and both
are copied to the same shared location (`/opt/USGS/Ash3d/share/post_proc/world_cities.txt`).

Also in the `scripts` folder are ansible scripts that can be used for setting up new computers
with all the tools needed for building Ash3d, downloading NWP files, and gennerating output.

Authors
-------

Hans F. Schwaiger <hschwaiger@usgs.gov>  
Larry G. Mastin <lgmastin@usgs.gov>  
