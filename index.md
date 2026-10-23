---
layout: guide
lesson: nextflow
title: Nextflow fundamentals
subtitle: From a Bash loop to a reproducible workflow on Purdue HPC.
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

You'll need HPC access, a Slurm allocation, and the `biocontainers` and `nextflow` modules. Submit the examples through `sbatch` so the work runs on compute nodes. Run `slist` on the cluster to find your available accounts.

Clone the workshop into scratch:

```bash
git clone https://github.com/zhan4429/PurdueNfWorkshop.git "$RCAC_SCRATCH/PurdueNfWorkshop"
cd "$RCAC_SCRATCH/PurdueNfWorkshop"
bash setup.sh
```

Run all scripts from the repository directory. Files stay under that directory:

| Contents | Folder |
| --- | --- |
| Downloaded FASTQ files | `data/` |
| Published reports | `results/` |
| Nextflow task files | `work/` |

The setup script downloads the FASTQ files and checks that they are valid gzip files. It stops if a download or compressed-file check fails.

### The setup script

This code is included directly from [setup.sh]({{ '/setup.sh' | relative_url }}). Edit that file to change the downloads.

```bash
{% include_relative setup.sh %}
```

> **A teaching example, one file at a time.** The download contains seven R1 files and four R2 files: 11 files, not 11 biological samples. We process each independently in single-end mode. These outputs are **not synchronized paired-end reads**. For paired-end analysis, group mates and run fastp with `-i/-I/-o/-O` together.

## Begin with a Bash loop

The familiar version processes one FASTQ file at a time: trim, check quality, move to the next file, then combine the reports. If the job stops, submitting it again starts from the first file.

[qc_forloop.sh]({{ '/qc_forloop.sh' | relative_url }}) requests two CPUs. It stops on tool failures and overwrites the combined MultiQC report when you run it again.

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

### Which configuration file does what?

| File | Purpose | Used by |
| --- | --- | --- |
| `nextflow.config` | Prepare the task environment and copy inputs: purge modules, load the QC tools, export their Bash functions, and stage readable files in each task folder | Both local and Slurm routes; loaded automatically |
| `hpc.config` | Select the Slurm executor, task partition, and account | Slurm route only; added with `-c hpc.config` |

Keep both files beside `main.nf`. The local launcher uses `nextflow.config` alone; the Slurm launcher uses both. Input/output parameters and task resources remain in `main.nf`.

### Make RCAC's tools available to task shells

Each launcher runs `module --force purge` before loading its modules. This removes preloaded modules such as XALT, whose `LD_PRELOAD` can interfere with biocontainer images.

RCAC's biocontainer modules provide `fastp`, `fastqc`, and `multiqc` as Bash functions. A separate task shell needs those functions exported. Nextflow automatically reads [nextflow.config]({{ '/nextflow.config' | relative_url }}) from the repository:

```groovy
{% include_relative nextflow.config %}
```

`module --force purge` removes conflicting modules; `module load` defines the tool functions; `export -f` passes them to the child Bash shell that executes the task. All task module loading is handled in `nextflow.config`; `main.nf` defines the workflow and its task resources.

`process.beforeScript` resets and loads the tool modules, then exports their functions before each task command runs. This setup applies to both executors. Keep `nextflow.config` beside `main.nf`; `-c hpc.config` adds Slurm scheduling settings without replacing it. Without this task setup, the tools may fail with exit code `127` (command not found).

`process.stageInMode = 'copy'` copies each input into its task folder. Nextflow's default is to create symlinks, but RCAC's tool functions launch containers themselves, and a container may not see a symlink's target. Copying inputs avoids that dependency for fastp, FastQC, and MultiQC. It uses extra work-directory space, which is small for this workshop dataset. This setting controls **task inputs**; `publishDir` controls how **outputs** are published.

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

“Local” means inside the compute allocation running Nextflow. It is Nextflow's default executor. The launcher requests four CPUs through its `#SBATCH` directives.

[qc_nextflow_local.sh]({{ '/qc_nextflow_local.sh' | relative_url }}) runs directly from the workshop working directory:

```bash
{% include_relative qc_nextflow_local.sh %}
```

### Slurm: a separate job for each task

Here, the head job runs the Nextflow manager. Nextflow submits each fastp, FastQC, and MultiQC task as a separate Slurm job.

[qc_nextflow_slurm.sh]({{ '/qc_nextflow_slurm.sh' | relative_url }}) adds `-c hpc.config`:

```bash
{% include_relative qc_nextflow_slurm.sh %}
```

The head job requests two CPUs. Each task gets its CPU count and time limit from `main.nf`. The executor, partition, and account are set in [hpc.config]({{ '/hpc.config' | relative_url }}):

```groovy
{% include_relative hpc.config %}
```

> **Before submitting:** Use `slist` to find your account and pass it with `sbatch -A YOUR_ACCOUNT`. Slurm sets `SLURM_JOB_ACCOUNT` in the head job; `hpc.config` reads it so child jobs use the same account. Its `queue = 'cpu'` sets the child-job partition; change it if needed. The `sbatch -p` option sets the head-job partition.

### Requested and allocated resources

The `#SBATCH` settings describe the launcher job; the process directives in `main.nf` describe individual tasks. In local mode, those tasks share the launcher's allocation. In Slurm mode, each task receives its own allocation.

On the [Gautschi CPU partition](https://docs.rcac.purdue.edu/userguides/gautschi/run_jobs/queues/), memory is allocated in proportion to requested cores. An explicit memory request can cause Slurm to allocate additional cores, so the allocated count may exceed `-c`. Check the job's actual allocation with `scontrol show job JOBID`, replacing `JOBID` with the ID from `sbatch`.

The launchers omit `--mem`, and the processes omit the `memory` directive. Memory follows the partition’s default allocation per core. The Slurm head job limits the Nextflow JVM heap to 1 GB with `NXF_OPTS`, leaving room for JVM overhead. Check the partition’s memory policy if adapting these examples to another system.

### Submit the examples

From `$RCAC_SCRATCH/PurdueNfWorkshop`, replace the account and partition placeholders and submit each example in turn:

```bash
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_forloop.sh
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_local.sh
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_slurm.sh
squeue -u "$USER"
```

**First Slurm demonstration:** `qc_nextflow_slurm.sh` deliberately omits `-resume`, so submitting it starts new tasks even after a completed local run. The local launcher includes `-resume`. Separate work folders do not isolate the run history or cached tasks.

Run one Nextflow example at a time. Watch for task jobs in `squeue` when using the Slurm executor. The 30-minute head-job limit includes time spent waiting for child jobs; if it expires, follow the resume instructions below before resubmitting.

## Publish outputs with publishDir

Tasks produce files in `work/`. `publishDir` exposes declared outputs in a results folder. Our FASTP process uses:

```groovy
publishDir "${params.outdir}/fastp", mode: 'copy'
```

With `params.outdir = 'results/local'`, Nextflow creates `results/local/fastp/` automatically when publishing. No `mkdir` is needed. The parameter alone does not create directories.

### Compare publishing modes

| Mode | What appears in results? | Storage and cleanup |
| --- | --- | --- |
| `copy` | Independent file copies | Uses extra space; copies survive removal of `work/`. |
| `symlink` (default) | Absolute symbolic links | Little extra space; links break if their targets are removed or relocated. |
| `rellink` | Relative symbolic links | Little extra space; moving both folders together preserves links if their relative layout stays unchanged. |
| `link` | Hard links sharing file data | Requires the same filesystem; files survive removal of the original links. Edits affect both. |
| `move` | Original files moved out of `work/` | Only for terminal processes; downstream tasks must not need these files. |
| `copyNoFollow` | Copies that preserve symbolic links | Copies links themselves; their targets must remain available. |

**Why we use `copy`:** workshop reports are easy to download and keep independently of task folders. Retain `work/` and `.nextflow/` for `-resume`.

Publishing is asynchronous. Pass outputs through channels to downstream processes, rather than reading the results folder.

Reference: [Nextflow publishDir documentation](https://docs.seqera.io/nextflow/reference/process/directives/publish-dir).

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

Check that the reports describe the expected input files. A job that finished without errors still needs its reports checked.

## Resume and troubleshoot

The local launcher includes `-resume`, so resubmitting it reuses matching completed tasks.

The Slurm launcher starts fresh by default. **To resume a Slurm run**, add `-resume RUN_NAME` to its `nextflow run` command, replacing `RUN_NAME` with the Slurm run name from `nextflow log`, then resubmit. Use that specific name after switching between routes.

```bash
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_local.sh
# After adding -resume RUN_NAME to the Slurm launcher:
sbatch -A YOUR_ACCOUNT -p YOUR_PARTITION qc_nextflow_slurm.sh
```

Keep **both** `.nextflow/` and `work/`. The first stores task metadata; the second holds the task outputs that Nextflow needs to resume. Published reports alone aren't enough. Changed inputs, scripts, or software can invalidate cached tasks.

### Read the run history

Load Nextflow and inspect the run from the working directory:

```bash
module --force purge
module load nextflow
cd "$RCAC_SCRATCH/PurdueNfWorkshop"
nextflow log
nextflow log last -f name,status,exit,workdir
```

**What does `last` mean?** It selects the most recently launched Nextflow run recorded in this working directory, whether it succeeded or failed. It does not mean the last task or the last successful run. After switching between local and Slurm examples, check `nextflow log` to confirm which run is latest.

`-f` selects the columns: `name` is the task name, `status` is its execution status, `exit` is its exit code (`0` means success), and `workdir` is its task directory.

#### Useful log shortcuts

| Command | What it shows |
| --- | --- |
| `nextflow log` | Run history, including run names and session IDs |
| `nextflow log last` | Task directories for the latest run |
| `nextflow log RUN_NAME` | Task directories for a specific run from the history |
| `nextflow log SESSION_ID` | The same lookup using a session ID |
| `nextflow log -quiet` | Only run names |
| `nextflow log -l` | Available fields for `-f` |
| `nextflow log -h` | Help for the log command |

Replace `RUN_NAME` or `SESSION_ID` with a value from `nextflow log`. Add the same `-f name,status,exit,workdir` option to inspect tasks in an older run.

To show only failed tasks in the latest run:

```bash
nextflow log last -F "status == 'FAILED'" -f name,status,exit,workdir
```

**Lowercase `-f` chooses fields; uppercase `-F` filters tasks.** A run that failed before any tasks started may have no task records to display; inspect `.nextflow.log` for the error.

Reference: [Nextflow log command](https://docs.seqera.io/nextflow/reference/cli/log).

`-resume` uses the latest run by default. If you've switched between examples, use `-resume RUN_NAME` in the launcher to select an older run listed by `nextflow log`.

### Follow a failure to its task folder

Read the Slurm output file in the working directory and the `.nextflow.log` file. Use the work directory shown in the error message or run history to inspect:

| File | What to look for |
| --- | --- |
| `.command.sh` | The exact command the task ran |
| `.command.err` | Tool error messages |
| `.exitcode` | The task's exit status |

For exit code `127` from a QC tool, check that `nextflow.config` is present and its module-load/export commands succeeded. For a missing module, check `module avail` or `module spider`. For rejected Slurm jobs, check the account passed to `sbatch -A` and the partition in `hpc.config`. Debug tool commands inside an interactive compute allocation.

If fastp exits with `255` and `ERROR: Failed to open file`, it started but could not read the input. Check that `process.stageInMode = 'copy'` is present in the cluster's `nextflow.config`, then resubmit the launcher. This avoids staged symlinks whose targets may be hidden inside the tool's container. Keep `.nextflow/` and `work/` for `-resume`; failed tasks will be rerun. The Nextflow update notice is informational.

If the error persists, check the source file from the repository directory:

```bash
ls -l data/SRR6357071_1.fastq.gz
gzip -t data/SRR6357071_1.fastq.gz
```

In the failed task folder, inspect `.command.run` for the staging commands and use `ls -l` to check that the input is a regular file. If it is readable on the host but the QC tool still cannot read it, check the container's mounts and permissions inside a compute allocation. Copy staging also applies to FastQC and MultiQC inputs, so their containers can read files produced by earlier tasks.

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
