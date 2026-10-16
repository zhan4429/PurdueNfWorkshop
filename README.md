# Purdue Nextflow workshop

Compare a Bash loop with a Nextflow workflow: **fastp → FastQC → MultiQC**.
The scripts use Slurm and the `biocontainers` and `nextflow` modules.
Input/output parameters and task resources are defined in `main.nf`.

## Setup

```bash
git clone https://github.com/zhan4429/PurdueNfWorkshop.git "$RCAC_SCRATCH/nextflow_workflow"
cd "$RCAC_SCRATCH/nextflow_workflow"
bash setup.sh
```

Scripts run from `$RCAC_SCRATCH/nextflow_workflow`. FASTQ files are stored
separately in `$RCAC_SCRATCH/nextflow_workshop/fastq`.

## Run

Submit from `$RCAC_SCRATCH/nextflow_workflow`, which contains the scripts. Replace `YOUR_ACCOUNT` and `YOUR_PARTITION`
with your Slurm allocation and partition. Before the HPC example, also replace
`YOUR_ACCOUNT` in `hpc.config`. Its `queue = 'cpu'` selects the task partition;
change it if needed. Run each example in turn:

```bash
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_forloop.sh
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_local.sh
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_hpc.sh
squeue -u "$USER"
```

- **Bash loop:** processes one file at a time; starts over when resubmitted.
- **Nextflow local:** runs parallel tasks within one compute allocation.
- **Nextflow HPC:** submits each task as a separate Slurm job.

The `sbatch` options configure the job running Nextflow. `hpc.config` configures
the separate HPC task jobs; its account and partition are set explicitly.
The local launcher uses Nextflow’s default local executor. Set the job’s
allocation with its `#SBATCH` directives.

## Results and resume

Reports are in `results/forloop`, `results/local`, and `results/slurm`.
Open `<results folder>/multiqc/multiqc_report.html` for the combined QC report.

Both Nextflow scripts include `-resume`: resubmit the same script to reuse
completed tasks. Keep `.nextflow/` and `work/`. Run one Nextflow example at a
time. To resume an older run after switching examples, use `-resume RUN_NAME`
with a run name from `nextflow log`.

This teaching example processes each FASTQ independently in single-end mode.
The 11 files create 11 FASTP tasks, 11 FASTQC tasks, and one MultiQC task.
The outputs are not synchronized paired-end reads.

Run the examples on compute nodes through `sbatch`. Save important results to
persistent storage before scratch cleanup.

[Four-page field guide](Nextflow_Purdue_HPC_4page_Flyer_Revised.html)

## Workshop website

[Read the online guide](https://zhan4429.github.io/PurdueNfWorkshop/) for the
lessons and copyable code. Edit `index.md` to update the text; script examples
are included directly from the original files. See [PAGES.md](PAGES.md) for
website editing details.
