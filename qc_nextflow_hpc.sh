#!/bin/bash
#SBATCH -J qc_nextflow_slurm
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 1
#SBATCH --mem=4G
#SBATCH -t 04:00:00
#SBATCH -o qc_nextflow_slurm_%j.out

set -euo pipefail
module load biocontainers nextflow

# Submit from $RCAC_SCRATCH/nextflow_workflow.
nextflow run main.nf -c hpc.config \
    --outdir results/slurm -w work/slurm -resume -ansi-log false
