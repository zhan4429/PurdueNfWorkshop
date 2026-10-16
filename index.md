---
layout: guide
---

## Start with the big picture

You already know how to run a tool. A workflow manager helps you connect tools, track their inputs and outputs, and pick up where you left off.

In this workshop, we'll run the same analysis three ways: a **Bash loop**, **Nextflow inside one allocation**, and **Nextflow submitting Slurm jobs**. The tools and input data stay the same.

| Step | What it does | What comes out |
| --- | --- | --- |
| **fastp** | Trim and filter reads | Trimmed FASTQ files, JSON and HTML reports |
| **FastQC** | Check the trimmed reads | ZIP and HTML quality reports |
| **MultiQC** | Combine the QC reports | One HTML summary |

Nextflow describes this as a **dataflow**: FastQC starts when its trimmed reads are ready. MultiQC waits for all the reports, including the JSON files from fastp.

### Five words you'll meet

| Word | Meaning in this example |
| --- | --- |
| **Process** | A tool step, such as `FASTP` or `FASTQC` |
| **Task** | One execution of a process for its input |
| **Channel** | A stream of files or values connecting steps |
| **Workflow** | The block that connects processes and channels |
| **Executor** | Where tasks run: locally inside an allocation, or as Slurm jobs |

**Nextflow and Snakemake** both support HPC workflows and containers. Nextflow connects processes through channels using a Groovy-based language; Snakemake connects rules through input and output files using Python-based syntax. Here, we'll focus on Nextflow.

## Prepare your workspace

You'll need HPC access, a Slurm allocation, and the `biocontainers` and `nextflow` modules. Submit the examples through `sbatch` so the work runs on compute nodes.

Clone the workshop into scratch:

```bash
git clone https://github.com/zhan4429/PurdueNfWorkshop.git "$RCAC_SCRATCH/nextflow_workflow"
cd "$RCAC_SCRATCH/nextflow_workflow"
bash setup.sh
```

**Working directory:** `$RCAC_SCRATCH/nextflow_workflow` contains the scripts. **Input directory:** `$RCAC_SCRATCH/nextflow_workshop/fastq` contains the downloaded FASTQ files. These are two separate directories.

If you already have the repository, enter it and run `bash setup.sh`. The script keeps valid existing files and stops if a download or compressed-file check fails.

### The setup script

This code is included directly from [setup.sh]({{ '/setup.sh' | relative_url }}). Edit that file to change the downloads.

```bash
{% include_relative setup.sh %}
```

> **A teaching example, one file at a time.** The download contains seven R1 files and four R2 files: 11 files, not 11 biological samples. We process each independently in single-end mode. These outputs are **not synchronized paired-end reads**. For paired-end analysis, group mates and run fastp with `-i/-I/-o/-O` together.

## Begin with a Bash loop

The familiar version processes one FASTQ file at a time: trim, check quality, move to the next file, then combine the reports. If the job stops, submitting it again starts from the first file.

[qc_forloop.sh]({{ '/qc_forloop.sh' | relative_url }}) requests two CPUs and 4 GB of memory. It stops on tool failures and overwrites the combined MultiQC report when you run it again.

```bash
{% include_relative qc_forloop.sh %}
```

Notice how the loop handles filenames and tool order explicitly. Nextflow will describe those dependencies through inputs, outputs, and channels.

## Connect the steps with Nextflow

The same three steps become three processes in [main.nf]({{ '/main.nf' | relative_url }}). The parameters at the top define the input folder and default output folder. Each process declares its tool, resources, inputs, outputs, and command.

- `path` stages a file into a task's own work directory.
- `emit` gives an output channel a name.
- `publishDir` copies the declared outputs into the results folder.
- `${task.cpus}` passes the process's CPU count to the tool.

### The complete workflow

```groovy
{% include_relative main.nf %}
```

The last block is the connection map. `FASTP.out.trimmed` feeds FastQC; fastp's JSON reports and FastQC's ZIP reports feed MultiQC. `mix()` combines those streams, and `collect(sort: true)` waits for every report and puts them in a stable order.

Downstream processes consume the output channels directly. They don't wait for files to appear in the published results folder.

> **Try it:** Which process runs only once? **MultiQC.** With 11 input files, you get 11 FASTP tasks, 11 FASTQC tasks, and one MultiQC task: **23 tasks** in total.

## Choose where tasks run

The pipeline stays the same. The executor changes where its tasks run.

### Local: inside one compute allocation

“Local” means inside the compute allocation running Nextflow. It is Nextflow's default executor. The launcher requests eight CPUs and 24 GB through its `#SBATCH` directives.

[qc_nextflow_local.sh]({{ '/qc_nextflow_local.sh' | relative_url }}) runs directly from the workshop working directory:

```bash
{% include_relative qc_nextflow_local.sh %}
```

### Slurm: a separate job for each task

Here, the head job runs the Nextflow manager. Nextflow submits each fastp, FastQC, and MultiQC task as a separate Slurm job.

[qc_nextflow_hpc.sh]({{ '/qc_nextflow_hpc.sh' | relative_url }}) adds `-c hpc.config`:

```bash
{% include_relative qc_nextflow_hpc.sh %}
```

The head job requests one CPU and 4 GB. The task jobs use the process resources in `main.nf` and the scheduling settings in [hpc.config]({{ '/hpc.config' | relative_url }}):

```groovy
{% include_relative hpc.config %}
```

> **Before submitting:** Replace `YOUR_ACCOUNT` in `hpc.config`. Its `queue = 'cpu'` sets the child-job partition; change it if needed. The account and partition passed to `sbatch` configure the **head job** separately.

### Submit the examples

From `$RCAC_SCRATCH/nextflow_workflow`, replace the account and partition placeholders and submit each example in turn:

```bash
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_forloop.sh
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_local.sh
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_hpc.sh
squeue -u "$USER"
```

Run one Nextflow example at a time. Watch for task jobs in `squeue` when using the Slurm executor. The four-hour head-job limit includes time spent waiting for child jobs; if it expires, resubmit the launcher to resume.

## Find your results

Each route writes to its own results folder under the working directory.

| Route | Combined report |
| --- | --- |
| Bash loop | `results/forloop/multiqc/multiqc_report.html` |
| Nextflow local | `results/local/multiqc/multiqc_report.html` |
| Nextflow Slurm | `results/slurm/multiqc/multiqc_report.html` |

The `fastp/` and `fastqc/` folders beside each `multiqc/` folder contain the individual outputs. Open the combined HTML report through Open OnDemand, or copy it to your computer.

```bash
ls results/slurm/multiqc/multiqc_report.html
du -sh work results
```

Check that the reports describe the expected input files. A completed scheduler job is the starting point for checking your results.

## Resume and troubleshoot

Both Nextflow launchers already include `-resume`. To reuse matching completed tasks, resubmit the same script:

```bash
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_local.sh
# Or resume the Slurm example:
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_hpc.sh
```

Keep **both** `.nextflow/` and `work/`. The first stores task metadata; the second holds the task outputs that Nextflow needs to resume. Published reports alone aren't enough. Changed inputs, scripts, or software can invalidate cached tasks.

### Read the run history

Load Nextflow and inspect the run from the working directory:

```bash
module load biocontainers nextflow
cd "$RCAC_SCRATCH/nextflow_workflow"
nextflow log
nextflow log last -f name,status,exit,workdir
```

`-resume` uses the latest run by default. If you've switched between examples, use `-resume RUN_NAME` in the launcher to select an older run listed by `nextflow log`.

### Follow a failure to its task folder

Read the Slurm output file in the working directory and the `.nextflow.log` file. Use the work directory shown in the error message or run history to inspect:

| File | What to look for |
| --- | --- |
| `.command.sh` | The exact command the task ran |
| `.command.err` | Tool error messages |
| `.exitcode` | The task's exit status |

For a missing module, check `module avail` or `module spider`. For rejected Slurm jobs, check your allocation and the account/partition in `hpc.config`. Debug tool commands inside an interactive compute allocation.

### One dash or two?

**One dash** for Nextflow options: `-resume`, `-c`, `-profile`, `-r`. **Two dashes** for pipeline parameters: `--fastq_dir`, `--outdir`. `--resume` is not the resume option.

## Save your work, then clean up

Scratch is temporary and isn't a backup. Check the reports and copy important results, scripts, settings, and logs to durable project storage before deleting work files.

```bash
myquota
purgelist
nextflow log
# Replace RUN_NAME with a completed run from the history:
nextflow clean RUN_NAME -n
```

`-n` previews what would be removed. Only replace it with `-f` after saving your results and checking that preview. Cleaning task work prevents those tasks from being resumed.

### Keep learning

This is a custom QC exercise using Purdue modules. For a separate nf-core exercise, follow the full pipeline instructions, including its inputs, release, and container configuration.

- [Nextflow training](https://training.nextflow.io/) — continue with hands-on lessons.
- [Caching and resuming](https://docs.seqera.io/nextflow/cache-and-resume) — understand what makes a task reusable.
- [nf-core getting started](https://nf-co.re/docs/usage/getting_started/introduction) — explore community pipelines.
