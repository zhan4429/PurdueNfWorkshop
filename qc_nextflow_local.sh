#!/bin/bash
#SBATCH -J qc_nextflow_local
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=12G
#SBATCH -t 04:00:00
#SBATCH -o qc_nextflow_local_%j.out

set -euo pipefail
module load biocontainers nextflow

# Submit from $RCAC_SCRATCH/nextflow_workflow.
nextflow run main.nf \
    --outdir results/local -w work/local -resume -ansi-log false
