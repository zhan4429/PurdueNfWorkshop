#!/bin/bash
#SBATCH -J qc_nextflow_slurm
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH -t 00:30:00
#SBATCH -o qc_nextflow_slurm_%j.out

set -euo pipefail
module --force purge
module load nextflow

# Keep the Nextflow JVM small; the real work happens in child SLURM jobs.
export NXF_OPTS='-Xms512m -Xmx1g'

# Submit from $RCAC_SCRATCH/PurdueNfWorkshop.
nextflow run main.nf -c hpc.config \
    --outdir results/slurm -w work/slurm
