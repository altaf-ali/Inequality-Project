#!/bin/bash -l
# Batch script to run an OpenMP threaded job on Legion with the upgraded
# software stack under SGE.

# command to run
COMMAND=$*

# Your work *must* be done in $TMPDIR
cd $TMPDIR

# Load modules
module unload compilers
module unload mpi
module load r/recommended

# Parse parameter file to get variables.
task_id=$SGE_TASK_ID

# Run the application.
$COMMAND --task-id $task_id 
