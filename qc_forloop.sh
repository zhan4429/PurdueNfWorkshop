#!/bin/bash
#SBATCH -J qc_forloop
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -c 2
#SBATCH -t 00:30:00
#SBATCH -o qc_forloop_%j.out

# Supply -A ACCOUNT -p PARTITION to sbatch (see README.md).
# One FASTQ at a time in single-end mode. Resubmission starts over.
set -euo pipefail
module --force purge
module load biocontainers fastp fastqc multiqc

FASTQ_DIR="$RCAC_SCRATCH/nextflow_workshop/fastq"
OUTDIR=results/forloop
mkdir -p "$OUTDIR/fastp" "$OUTDIR/fastqc" "$OUTDIR/multiqc"
for fq in "$FASTQ_DIR"/*.fastq.gz; do
    if [ ! -f "$fq" ]; then
        echo "No FASTQ files found. Run bash setup.sh first."
        exit 1
    fi
    sample=$(basename "$fq" .fastq.gz)
    printf 'Processing %s\n' "$sample"
    fastp -w 2 -i "$fq" \
        -o "$OUTDIR/fastp/${sample}.trimmed.fastq.gz" \
        -j "$OUTDIR/fastp/${sample}.fastp.json" \
        -h "$OUTDIR/fastp/${sample}.fastp.html"
    fastqc -t 2 -o "$OUTDIR/fastqc" "$OUTDIR/fastp/${sample}.trimmed.fastq.gz"
done
# Explicitly overwrite the previous report on resubmission.
multiqc --force -o "$OUTDIR/multiqc" "$OUTDIR/fastp" "$OUTDIR/fastqc"
