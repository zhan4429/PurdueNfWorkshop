---
layout: guide
lesson: nf-core
title: nf-core fundamentals
subtitle: Run a ready-made bioinformatics pipeline on Purdue HPC.
permalink: /nf-core/
---

In [Nextflow fundamentals]({{ '/' | relative_url }}), you connected processes and channels yourself. **nf-core provides ready-made pipelines built using Nextflow.** You choose a pipeline, provide your inputs, and let Nextflow run the analysis.

This workshop covers choosing a pipeline, running a small demo on Gautschi, checking results, adjusting process resources, and preparing inputs for an RNA-seq analysis.

## 1. Understand the main components

| Component | What it does |
| --- | --- |
| **Nextflow** | Runs the workflow and tracks completed tasks |
| **nf-core** | Provides community-maintained bioinformatics pipelines |
| **Slurm** | Schedules tasks on the cluster |
| **Apptainer** | Runs the analysis software inside containers |
| **Institutional profile** | Supplies settings for your cluster |

Choose a pipeline for your research question at [nf-co.re/pipelines](https://nf-co.re/pipelines). Read its input requirements and use the documentation for the release you plan to run.

For example, **nf-core/rnaseq** performs RNA-seq quality control, trimming, alignment, and expression quantification. Your organism, reference genome, and analysis goals guide the parameter choices.

### Find your way around a pipeline repository

Open the [nf-core/rnaseq GitHub repository](https://github.com/nf-core/rnaseq). These are the main places to look when you want to understand or customize a pipeline:

| File or folder | What it is used for |
| --- | --- |
| `README.md` and `docs/` | Overview, input requirements, usage, and output descriptions |
| `main.nf` | Entry point that starts the workflow |
| `nextflow.config` | Default parameters, profiles, and links to other configuration files |
| `nextflow_schema.json` | Descriptions and validation rules for pipeline parameters |
| `conf/base.config` | Default CPU, memory, and time requests, grouped by process label |
| `conf/modules/` | Settings for particular steps, such as STAR arguments and output locations |
| `workflows/` and `subworkflows/` | Connect analysis steps; subworkflows group related steps, such as alignment and BAM processing |
| `modules/nf-core/` | Reusable tool modules imported from the shared nf-core collection, such as STAR and FastQC |
| `modules/local/` | Modules written for this pipeline's particular needs, such as rnaseq's DESeq2 QC step |

**“Local” means local to the pipeline project.** Both types of module can run on HPC with containers. A module defines a step's inputs, command, outputs, and resource label.

On GitHub, use the branch/tag dropdown to select the release matching your `-r` option. The rnaseq examples below use `3.27.0`; file locations and settings can differ between releases.

For this workshop, we will use **nf-core/demo** with a small test dataset.

## 2. Prepare your workspace

On the Gautschi login node, find your allocation account:

```bash
slist
```

Replace `YOUR_ACCOUNT` in the examples with that account. Prepare a workspace in scratch:

```bash
mkdir -p "$RCAC_SCRATCH/nfcore-workshop"
cd "$RCAC_SCRATCH/nfcore-workshop"
```

We will submit Nextflow through Slurm so it runs on a compute node. Keep temporary task files in scratch and copy important results to persistent storage after the run. **Scratch is not backed up.**

### Set one container image folder for all pipelines

The `purdue_gautschi` profile already uses `$RCAC_SCRATCH/.apptainer/cache`. With the `test,apptainer` profile shown below, **set `NXF_APPTAINER_CACHEDIR` explicitly** to use the same location:

```bash
export NXF_APPTAINER_CACHEDIR="$RCAC_SCRATCH/.apptainer/cache"
mkdir -p "$NXF_APPTAINER_CACHEDIR"
```

The export is optional with the [Gautschi institutional profile](https://nf-co.re/configs/purdue_gautschi/). Using the same folder across pipelines lets Nextflow reuse matching images. Different software versions may need different images. If the scratch cache is deleted, the images will be downloaded again when needed.

### Where does the pipeline code go?

`nextflow run nf-core/demo -r 1.2.0` downloads the pipeline code automatically. By default, it is stored in **`$HOME/.nextflow/assets/nf-core/demo/`**, separate from your analysis files and container images. Nextflow reuses this copy and selects the release specified by `-r`.

| Contents | Location in this workshop |
| --- | --- |
| Pipeline code | `$HOME/.nextflow/assets/nf-core/demo/` |
| Container images for all pipelines | `$RCAC_SCRATCH/.apptainer/cache/` |
| Task files and final outputs | `work/` and `results/` in your scratch workspace |

If your environment sets `NXF_HOME` or `NXF_ASSETS`, the pipeline code location may differ.

### Read a launch command

```bash
nextflow run nf-core/demo -r 1.2.0 \
  -profile test,purdue_gautschi \
  --cluster_account YOUR_ACCOUNT \
  --outdir results
```

| Option | Meaning |
| --- | --- |
| `-r 1.2.0` | Run this pipeline release |
| `-profile test,purdue_gautschi` | Use test data and Gautschi's Slurm/Apptainer settings |
| `--cluster_account` | Charge task jobs to your allocation |
| `--outdir` | Write final results here |

**One dash** is for Nextflow options, such as `-r`, `-profile`, and `-resume`. **Two dashes** are for pipeline parameters, such as `--input` and `--outdir`.

Use `test` for the example dataset. For your own analysis, remove `test` and supply the pipeline's required inputs. On Bell or Negishi, use the matching institutional profile and Slurm partition.

## 3. Submit the demo

### Use the Apptainer profile

The `apptainer` profile enables containers. This script runs the whole demo within **one Slurm job with 4 CPU cores**. Memory is allocated with the cores on Gautschi. The Gautschi profile example below submits separate jobs for the pipeline tasks.

Save this as `run_demo_apptainer.sh` in your workspace and replace `YOUR_ACCOUNT`:

```bash
#!/bin/bash
#SBATCH --job-name=nfcore-demo-apptainer
#SBATCH --account=YOUR_ACCOUNT
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=02:00:00
#SBATCH --output=nfcore-%j.out

set -euo pipefail
module purge
module load nextflow

mkdir -p "$RCAC_SCRATCH/nfcore-workshop/apptainer-demo"
cd "$RCAC_SCRATCH/nfcore-workshop/apptainer-demo"

export NXF_APPTAINER_CACHEDIR="$RCAC_SCRATCH/.apptainer/cache"
mkdir -p "$NXF_APPTAINER_CACHEDIR"

nextflow run nf-core/demo -r 1.2.0 \
  -profile test,apptainer \
  --outdir "$PWD/results" \
  -resume
```

Submit from your workspace:

```bash
sbatch run_demo_apptainer.sh
squeue -u "$USER"
```

This example uses the same image cache as the Gautschi profile. It does not need `--cluster_account` because `#SBATCH --account` sets the account for this single job.

**For real analyses, request more cores as needed.** Four cores are for this small test dataset. With `test,apptainer`, all tasks share the one job's allocation. Heavier analyses need enough cores and the associated memory for the most demanding task and any tasks running at the same time. For your own data, also remove `test` and provide the pipeline's required inputs.

### Use the Gautschi profile

Save the following as `run_demo.sh` in your workspace. Replace **both** occurrences of `YOUR_ACCOUNT`.

```bash
#!/bin/bash
#SBATCH --job-name=nfcore-demo
#SBATCH --account=YOUR_ACCOUNT
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --time=04:00:00
#SBATCH --output=nfcore-%j.out

set -euo pipefail
module purge
module load nextflow
cd "$RCAC_SCRATCH/nfcore-workshop"

nextflow run nf-core/demo -r 1.2.0 \
  -profile test,purdue_gautschi \
  --cluster_account YOUR_ACCOUNT \
  --outdir "$PWD/results" \
  -resume
```

**Optional cache override:** The `purdue_gautschi` profile already sets the container image cache to `$RCAC_SCRATCH/.apptainer/cache`, so no export is needed. To use another folder, add the following before `nextflow run` in your script, replacing the example path with your chosen folder:

```bash
export NXF_APPTAINER_CACHEDIR="/path/to/your/container-cache"
mkdir -p "$NXF_APPTAINER_CACHEDIR"
```

Submit and check your jobs:

```bash
sbatch run_demo.sh
squeue -u "$USER"
```

The script starts the **Nextflow manager** with 4 CPUs. Nextflow submits separate Slurm jobs for the pipeline tasks, each with its own resource request. The manager must remain running until the pipeline finishes.

The first run may take longer while Nextflow downloads the pipeline and containers. Later runs can reuse these downloads.

## 4. Check results and resume

In your workspace, look for:

| File or folder | What to check |
| --- | --- |
| `nfcore-<job-id>.out` | Slurm output and pipeline progress |
| `results/` | Final outputs and reports |
| `work/` | Temporary files for each task |
| `.nextflow.log` | Detailed information if the run fails |

Open the MultiQC HTML report under `results/` to review the quality-control results.

Both scripts include `-resume`. Once the previous run has stopped, resubmit the same script you used:

```bash
sbatch run_demo.sh
# Or, if you used the Apptainer-only example:
sbatch run_demo_apptainer.sh
```

Nextflow reuses unchanged, successfully completed tasks. **Keep the same run directory, `.nextflow/`, and `work/` to resume.**

If a task fails, start with the error in `nfcore-<job-id>.out`. It usually identifies the failed process and its work directory. Check that task's `.command.err` and `.command.log` for the tool's error message.

## 5. Override pipeline resource settings

The institutional profile handles cluster settings. The pipeline supplies CPU, memory, and time requests for its analysis steps. If a task runs out of memory or time, find its defaults and override them in your own `custom.config`.

### Example: find STAR_ALIGN's default resources

First, open [`modules/nf-core/star/align/main.nf`](https://github.com/nf-core/rnaseq/blob/3.27.0/modules/nf-core/star/align/main.nf). Near the top, find the process name and label:

```groovy
process STAR_ALIGN {
    label 'process_high'
    // ...
}
```

Next, open [`conf/base.config`](https://github.com/nf-core/rnaseq/blob/3.27.0/conf/base.config) and search for `process_high`:

```groovy
withLabel: process_high {
    cpus   = { 12    * task.attempt }
    memory = { 72.GB * task.attempt }
    time   = { 16.h  * task.attempt }
}
```

Follow this same path for other steps: **process definition → label → settings in `conf/base.config`**. STAR's alignment arguments are configured separately in [`conf/modules/align_star.config`](https://github.com/nf-core/rnaseq/blob/3.27.0/conf/modules/align_star.config).

### How `* task.attempt` changes resources on retry

`task.attempt` is the attempt number for an individual task. It starts at **1** and increases when Nextflow automatically retries that failed task. The expressions inside `{ ... }` are evaluated for each attempt, so `* task.attempt` multiplies each base resource request by the attempt number:

| Task attempt | CPUs requested | Memory requested | Time limit |
| --- | --- | --- | --- |
| 1: initial attempt | 12 | 72 GB | 16 hours |
| 2: first retry | 24 | 144 GB | 32 hours |
| 3: second retry, if allowed | 36 | 216 GB | 48 hours |

The increase is linear: **1×, 2×, 3×** the base request. These values apply to each matching task, before other overrides or resource caps. The time is a maximum runtime; a task can finish earlier. See [Nextflow's dynamic task resources documentation](https://docs.seqera.io/nextflow/process#dynamic-task-resources).

**Retries must also be permitted by the error policy.** In [nf-core/rnaseq 3.27.0](https://github.com/nf-core/rnaseq/blob/3.27.0/conf/base.config), the default settings are:

```groovy
errorStrategy = { task.exitStatus in ((130..145) + 104 + (175..177)) ? 'retry' : 'finish' }
maxRetries    = 1
```

Only the listed exit codes trigger a retry. `maxRetries = 1` allows **one retry after the initial attempt**, for two attempts total. The third row in the table requires `maxRetries` of at least 2. Individual processes, profiles, or custom configurations can override these defaults.

The counter tracks attempts of the same task. Simply launching the whole workflow a second time does not itself mean `task.attempt = 2`.

### Override by label or process name

Save the following as `custom.config` in your **rnaseq run directory**. It shows both options; keep the block you need:

```groovy
process {
  // Scale resources on retry for tasks with the process_high label.
  withLabel: 'process_high' {
    cpus   = { 16    * task.attempt }
    memory = { 96.GB * task.attempt }
    time   = { 24.h  * task.attempt }
  }

  // Change tasks named STAR_ALIGN.
  withName: STAR_ALIGN {
    cpus   = 24
    memory = 128.GB
    time   = 24.h
  }
}
```

| Selector | Effect of this example |
| --- | --- |
| `withLabel` | Every `process_high` task starts with 16 CPUs, 96 GB, and 24 hours; each request scales with `task.attempt` |
| `withName` | STAR alignment tasks request a fixed 24 CPUs, 128 GB, and 24 hours on every attempt |

If you keep both blocks, the `withName` settings take priority for STAR. `STAR_ALIGN` matches the process name directly. For another step, use its process name from the module definition. A full workflow path can target a specific occurrence when the same process is used in several workflows.

**These are example requests for rnaseq, not settings needed for the demo.** Choose resources that fit your analysis and cluster limits. In your rnaseq Slurm script, add **`-c custom.config`** to the `nextflow run` command to apply the overrides. Keep the pipeline files unchanged.

With the `withLabel` block alone, the first retry requests **32 CPUs, 192 GB, and 48 hours**, if permitted by the error policy and resource limits. The fixed `withName` requests stay the same on retries. To scale those too, use the same `* task.attempt` expressions, such as `memory = { 128.GB * task.attempt }`.

### Submit with `custom.config`

Create your rnaseq run directory:

```bash
mkdir -p "$RCAC_SCRATCH/rnaseq-project"
cd "$RCAC_SCRATCH/rnaseq-project"
```

Save `custom.config` above and the following script as `run_rnaseq_custom.sh` in this directory. Replace `YOUR_ACCOUNT` and `YOUR_GROUP`, and prepare your samplesheet and reference files as described in [section 7](#7-prepare-inputs-for-a-real-analysis). Adjust the filenames and walltime for your analysis.

```bash
#!/bin/bash
#SBATCH --job-name=rnaseq-custom
#SBATCH --account=YOUR_ACCOUNT
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=2-00:00:00
#SBATCH --output=rnaseq-custom-%j.out

set -euo pipefail
module purge
module load nextflow

PROJECT_DIR="/depot/YOUR_GROUP/rnaseq_project"
cd "$RCAC_SCRATCH/rnaseq-project"

nextflow run nf-core/rnaseq -r 3.27.0 \
  -profile purdue_gautschi \
  -c custom.config \
  --cluster_account "$SLURM_JOB_ACCOUNT" \
  --input "$PROJECT_DIR/samplesheet.csv" \
  --fasta "$PROJECT_DIR/references/genome.fa.gz" \
  --gtf "$PROJECT_DIR/references/genes.gtf.gz" \
  --aligner star_salmon \
  --outdir "$PWD/results" \
  -resume
```

Submit from the same run directory and check your jobs:

```bash
sbatch run_rnaseq_custom.sh
squeue -u "$USER"
```

**`-c custom.config` loads your resource overrides.** The `#SBATCH` directives allocate resources for the Nextflow manager. The Gautschi profile submits separate jobs for analysis tasks, using the resource requests from the pipeline and your `custom.config`.

## 6. Try standby for short tasks

On Gautschi, adding `--use_standby true` lets eligible CPU tasks use standby. Tasks must request at most 4 hours and 384 GB; other tasks use normal QoS. Leave this option out for the workshop's first run. See the [Gautschi profile](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config) for details.

## 7. Prepare inputs for a real analysis

The demo's `test` profile supplies its inputs. For your own analysis, you prepare those files yourself. Here is a **paired-end nf-core/rnaseq example using release 3.27.0**. Replace the example paths with your files; see the [rnaseq input guide](https://nf-co.re/rnaseq/3.27.0/docs/usage/#samplesheet-input).

### Prepare the reads and samplesheet

Each paired-end sample has two FASTQ files: **R1 and R2**. Keep the matching pair together and give each biological sample a distinct name. Save a plain CSV file named `samplesheet.csv` in your project directory, for example `/depot/YOUR_GROUP/rnaseq_project/`:

```csv
sample,fastq_1,fastq_2,strandedness
control_rep1,/depot/YOUR_GROUP/rnaseq_project/fastq/control_rep1_R1.fastq.gz,/depot/YOUR_GROUP/rnaseq_project/fastq/control_rep1_R2.fastq.gz,auto
treated_rep1,/depot/YOUR_GROUP/rnaseq_project/fastq/treated_rep1_R1.fastq.gz,/depot/YOUR_GROUP/rnaseq_project/fastq/treated_rep1_R2.fastq.gz,auto
```

| Column | What to provide |
| --- | --- |
| `sample` | Sample name without spaces; include all biological replicates as separate samples |
| `fastq_1` | Absolute path to the sample's R1 FASTQ file |
| `fastq_2` | Absolute path to its matching R2 file; leave empty for single-end reads |
| `strandedness` | `forward`, `reverse`, or `unstranded` if known from library preparation; `auto` asks the pipeline to infer it |

Keep the header exactly as shown and check that every read file exists and is readable from compute nodes. The [samplesheet schema](https://github.com/nf-core/rnaseq/blob/3.27.0/assets/schema_input.json) defines the accepted values.

### Prepare the reference files

For this STAR/Salmon example, provide a **genome FASTA** and a **gene annotation GTF** for your organism. Obtain them for the same genome assembly and preferably from the same source and release, such as Ensembl or GENCODE.

For example, store them as `references/genome.fa.gz` and `references/genes.gtf.gz` under your project directory. These names are placeholders for your actual reference files. The pipeline can build the required index from them. See the [reference requirements](https://nf-co.re/rnaseq/3.27.0/docs/usage/#reference-genome-options).

### Pass your inputs to the pipeline

Save this as `run_rnaseq.sh`. Replace `YOUR_ACCOUNT` and `YOUR_GROUP`, and adjust the reference filenames and walltime for your analysis.

```bash
#!/bin/bash
#SBATCH --job-name=rnaseq
#SBATCH --account=YOUR_ACCOUNT
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=2-00:00:00
#SBATCH --output=rnaseq-%j.out

set -euo pipefail
module purge
module load nextflow

PROJECT_DIR="/depot/YOUR_GROUP/rnaseq_project"
mkdir -p "$RCAC_SCRATCH/rnaseq-project"
cd "$RCAC_SCRATCH/rnaseq-project"

nextflow run nf-core/rnaseq -r 3.27.0 \
  -profile purdue_gautschi \
  --cluster_account "$SLURM_JOB_ACCOUNT" \
  --input "$PROJECT_DIR/samplesheet.csv" \
  --fasta "$PROJECT_DIR/references/genome.fa.gz" \
  --gtf "$PROJECT_DIR/references/genes.gtf.gz" \
  --aligner star_salmon \
  --outdir "$PWD/results" \
  -resume
```

Submit with `sbatch run_rnaseq.sh`. `--input` points to the samplesheet; `--fasta` and `--gtf` supply the references. `star_salmon` selects STAR alignment and Salmon quantification. The Gautschi profile supplies the container cache location and submits separate task jobs.

**Choose appropriate cores for your needs.** The 16 cores above are an example allocation for the Nextflow manager. With `purdue_gautschi`, each analysis step has a separate resource request; use the pipeline defaults or `custom.config` to adjust its cores and memory based on genome size, read depth, and tool requirements. Increasing the manager's cores does not increase STAR's cores. With the `apptainer` profile alone, request enough cores and bundled memory for the whole analysis within one job.

To use your resource overrides from [section 5](#5-override-pipeline-resource-settings), place `custom.config` in `$RCAC_SCRATCH/rnaseq-project` and add `-c custom.config` to the run command. Copy final results from scratch to persistent project storage after completion.

## After the workshop

### Ask for help

Join [nf-core Slack](https://nf-co.re/join) and ask in your pipeline's channel, such as `#rnaseq`, or in `#help` or `#nostupidquestions`.

Include the pipeline release, Nextflow version, cluster profile, launch command, and relevant error message. Remove sensitive sample information before sharing logs. Contact Purdue RCAC for account, storage, or scheduler questions.

### Useful links

- [nf-core pipelines](https://nf-co.re/pipelines)
- [RCAC Nextflow setup on Gautschi](https://docs.rcac.purdue.edu/lifesciences/guides/nextflow-gautschi/)
- [Gautschi institutional profile](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config)
