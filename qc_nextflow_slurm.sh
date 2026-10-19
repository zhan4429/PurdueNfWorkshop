#!/bin/bash
#SBATCH -J qc_nextflow_slurm
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=8G
#SBATCH -t 00:30:00
#SBATCH -o qc_nextflow_slurm_%j.out

set -euo pipefail
module load nextflow

# Keep the Nextflow JVM small; the real work happens in child SLURM jobs.
export NXF_OPTS='-Xms1g -Xmx4g'

# Submit from $RCAC_SCRATCH/nextflow_workflow.
nextflow run main.nf -c hpc.config \
    --outdir results/slurm -w work/slurm
