#!/bin/bash
#SBATCH -J qc_nextflow_local
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 4
#SBATCH -t 00:30:00
#SBATCH -o qc_nextflow_local_%j.out

set -euo pipefail
module --force purge
module load nextflow

# Submit from $RCAC_SCRATCH/PurdueNfWorkshop.
nextflow run main.nf \
    --outdir results/local -w work/local -resume -ansi-log false
