# Purdue Nextflow workshop

Compare a Bash loop with a Nextflow workflow: **fastp → FastQC → MultiQC**.
The scripts use Slurm and the `biocontainers` and `nextflow` modules.
Input/output parameters and task resources are defined in `main.nf`.
`nextflow.config` loads and exports RCAC's tool functions for task shells;
`hpc.config` adds Slurm scheduling settings. Nextflow reads `nextflow.config`
automatically for both routes; only the Slurm launcher adds `-c hpc.config`.
Keep both configuration files beside `main.nf`.

The module fixes in [PR #1](https://github.com/zhan4429/PurdueNfWorkshop/pull/1)
were tested on Gautschi by Arun Seetharam: all three routes and local resume
passed, including 23 Slurm child jobs. Each launcher purges preloaded modules
to avoid XALT/biocontainer conflicts.

## Setup

```bash
git clone https://github.com/zhan4429/PurdueNfWorkshop.git "$RCAC_SCRATCH/PurdueNfWorkshop"
cd "$RCAC_SCRATCH/PurdueNfWorkshop"
bash setup.sh
```

Scripts run from `$RCAC_SCRATCH/PurdueNfWorkshop`. FASTQ files are stored
separately in `$RCAC_SCRATCH/nextflow_workshop/fastq`. Existing checkouts can
stay where they are; submit jobs from their repository directory.

## Run

Submit from `$RCAC_SCRATCH/PurdueNfWorkshop`, which contains the scripts. Replace `YOUR_ACCOUNT` and `YOUR_PARTITION`
with your Slurm allocation and partition. Run `slist` to find your accounts.
For the Slurm example, `hpc.config` inherits the account from the head job's
`SLURM_JOB_ACCOUNT`. Its `queue = 'cpu'` selects the task partition; change it
if needed. Run each example in turn:

```bash
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_forloop.sh
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_local.sh
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_slurm.sh
squeue -u "$USER"
```

- **Bash loop:** processes one file at a time; starts over when resubmitted.
- **Nextflow local:** runs parallel tasks within one compute allocation.
- **Nextflow HPC:** submits each task as a separate Slurm job.

The local launcher includes `-resume`. The Slurm launcher deliberately omits it
so the first Slurm demonstration submits new tasks rather than reusing the local
cache. Separate work folders do not isolate run history or cached tasks.
The collaborator observed about six minutes for the Slurm route with an empty queue.

The `sbatch` options configure the job running Nextflow. `hpc.config` configures
the separate HPC task jobs; their account comes from the head job, and their
partition is set by `queue`.
The local launcher uses Nextflow’s default local executor. Set the job’s
allocation with its `#SBATCH` directives. The launchers request CPUs without
explicit memory requests; memory follows the partition’s default allocation
per core. The Slurm head job limits the Nextflow JVM heap to 1 GB.

## Results and resume

Reports are in `results/forloop`, `results/local`, and `results/slurm`.
Open `<results folder>/multiqc/multiqc_report.html` for the combined QC report.

Resubmit the local launcher to resume. For Slurm resume, add `-resume RUN_NAME`
to the `nextflow run` command in `qc_nextflow_slurm.sh`, using the Slurm run name
from `nextflow log`, then resubmit. Keep `.nextflow/` and `work/`. Run one
Nextflow example at a time.

This teaching example processes each FASTQ independently in single-end mode.
The 11 files create 11 FASTP tasks, 11 FASTQC tasks, and one MultiQC task.
The outputs are not synchronized paired-end reads.

Run the examples on compute nodes through `sbatch`. Save important results to
persistent storage before scratch cleanup.

[Printable field guide](https://zhan4429.github.io/PurdueNfWorkshop/field-guide.html)
uses the same lesson and scripts as the website. Choose **Print / Save as PDF**
to save a current copy.

## Workshop website

[Read the online guide](https://zhan4429.github.io/PurdueNfWorkshop/) for the
lessons and copyable code. Edit `index.md` to update the text; script examples
are included directly from the original files. See [PAGES.md](PAGES.md) for
website editing details.
