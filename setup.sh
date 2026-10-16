#!/bin/bash
set -euo pipefail

: "${RCAC_SCRATCH:?RCAC_SCRATCH is not set}"
mkdir -p "$RCAC_SCRATCH/nextflow_workshop/fastq"
cd "$RCAC_SCRATCH/nextflow_workshop/fastq"

# A fixed revision of the nf-core training dataset.
base_url=https://raw.githubusercontent.com/nf-core/test-datasets/cad884e7fbe5617dcd55bdd07d9ddf65b54febe4/testdata/GSE110004

for file in SRR635{7070..7076}_1.fastq.gz SRR635{7070,7071,7072,7076}_2.fastq.gz; do
    if [[ ! -s "$file" ]]; then
        curl -fL --retry 3 "$base_url/$file" -o "$file.part"
        gzip -t "$file.part"
        mv "$file.part" "$file"
    fi
    gzip -t "$file"
done
