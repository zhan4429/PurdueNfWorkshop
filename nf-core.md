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

On GitHub, use the branch/tag dropdown to select the release matching your `-r` option. The STAR example below links to `master`; file locations and settings can differ between releases.

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

### Use the Gautschi profile

Save the following as `run_demo.sh` in your workspace. Replace **both** occurrences of `YOUR_ACCOUNT`. Repeat the cache export in the script so it is set whenever the job runs.

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

export NXF_APPTAINER_CACHEDIR="$RCAC_SCRATCH/.apptainer/cache"
mkdir -p "$NXF_APPTAINER_CACHEDIR"

nextflow run nf-core/demo -r 1.2.0 \
  -profile test,purdue_gautschi \
  --cluster_account YOUR_ACCOUNT \
  --outdir "$PWD/results" \
  -resume -ansi-log false
```

Submit and check your jobs:

```bash
sbatch run_demo.sh
squeue -u "$USER"
```

The script starts the **Nextflow manager** with 4 CPUs. Nextflow submits separate Slurm jobs for the pipeline tasks, each with its own resource request. The manager must remain running until the pipeline finishes.

The first run may take longer while Nextflow downloads the pipeline and containers. Later runs can reuse these downloads.

### Alternative: run with `test,apptainer`

The `apptainer` profile enables containers. This script runs the whole demo within **one Slurm job with 4 CPU cores**. Memory is allocated with the cores on Gautschi. The Gautschi profile example above submits separate jobs for the pipeline tasks.

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
  -resume -ansi-log false
```

Submit from your workspace:

```bash
sbatch run_demo_apptainer.sh
squeue -u "$USER"
```

This example uses the same image cache as the Gautschi profile. It does not need `--cluster_account` because `#SBATCH --account` sets the account for this single job. Its results and task files are in the `apptainer-demo` subfolder. See the [demo profile definitions](https://github.com/nf-core/demo/blob/1.2.0/nextflow.config) for these settings.

**For real analyses, request more cores as needed.** Four cores are for this small test dataset. With `test,apptainer`, all tasks share the one job's allocation. Heavier analyses need enough cores and the associated memory for the most demanding task and any tasks running at the same time. For your own data, also remove `test` and provide the pipeline's required inputs.

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

First, open [`modules/nf-core/star/align/main.nf`](https://github.com/nf-core/rnaseq/blob/master/modules/nf-core/star/align/main.nf). Near the top, find the process name and label:

```groovy
process STAR_ALIGN {
    label 'process_high'
    // ...
}
```

Next, open [`conf/base.config`](https://github.com/nf-core/rnaseq/blob/master/conf/base.config) and search for `process_high`:

```groovy
withLabel: process_high {
    cpus   = { 12    * task.attempt }
    memory = { 72.GB * task.attempt }
    time   = { 16.h  * task.attempt }
}
```

On the first attempt, STAR requests **12 CPUs, 72 GB, and 16 hours**, before other overrides or resource caps. `task.attempt` starts at 1 and increases on a retry.

Follow this same path for other steps: **process definition → label → settings in `conf/base.config`**. STAR's alignment arguments are configured separately in [`conf/modules/align_star.config`](https://github.com/nf-core/rnaseq/blob/master/conf/modules/align_star.config).

### Override by label or process name

Save the following as `custom.config` in your **rnaseq run directory**. It shows both options; keep the block you need:

```groovy
process {
  // Change every process with the process_high label.
  withLabel: 'process_high' {
    cpus   = 16
    memory = 96.GB
    time   = 24.h
  }

  // Change only STAR_ALIGN within the ALIGN_STAR workflow.
  withName: '.*ALIGN_STAR:STAR_ALIGN' {
    cpus   = 24
    memory = 128.GB
    time   = 24.h
  }
}
```

| Selector | Effect of this example |
| --- | --- |
| `withLabel` | Every `process_high` task requests 16 CPUs, 96 GB, and 24 hours |
| `withName` | STAR alignment tasks request 24 CPUs, 128 GB, and 24 hours |

If you keep both blocks, the `withName` settings take priority for STAR. The `.*` matches the earlier part of the workflow path. For another step, copy its full process name from the run's error message or `.nextflow.log`.

**These are example requests for rnaseq, not settings needed for the demo.** Choose resources that fit your analysis and cluster limits. In your rnaseq Slurm script, add **`-c custom.config`** to the `nextflow run` command to apply the overrides. Keep the pipeline files unchanged.

The fixed requests above stay the same on retries. To increase a request on retry, use an expression such as `memory = { 128.GB * task.attempt }`. `maxRetries = 1` allows one retry after the first attempt, when the pipeline's error policy permits it.

## 6. Prepare inputs for a real analysis

The demo's `test` profile supplies its inputs. For your own analysis, you prepare those files yourself. Here is a **paired-end nf-core/rnaseq example using release 3.26.0**. Replace the example paths with your files; see the [rnaseq input guide](https://nf-co.re/rnaseq/3.26.0/docs/usage/#samplesheet-input).

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

Keep the header exactly as shown and check that every read file exists and is readable from compute nodes. The [samplesheet schema](https://github.com/nf-core/rnaseq/blob/3.26.0/assets/schema_input.json) defines the accepted values.

### Prepare the reference files

For this STAR/Salmon example, provide a **genome FASTA** and a **gene annotation GTF** for your organism. Obtain them for the same genome assembly and preferably from the same source and release, such as Ensembl or GENCODE.

For example, store them as `references/genome.fa.gz` and `references/genes.gtf.gz` under your project directory. These names are placeholders for your actual reference files. The pipeline can build the required index from them. See the [reference requirements](https://nf-co.re/rnaseq/3.26.0/docs/usage/#reference-genome-options).

### Pass your inputs to the pipeline

Save this as `run_rnaseq.sh`. Replace `YOUR_ACCOUNT` and `YOUR_GROUP`, and adjust the reference filenames and walltime for your analysis.

```bash
#!/bin/bash
#SBATCH --job-name=rnaseq
#SBATCH --account=YOUR_ACCOUNT
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=2-00:00:00
#SBATCH --output=rnaseq-%j.out

set -euo pipefail
module purge
module load nextflow

PROJECT_DIR="/depot/YOUR_GROUP/rnaseq_project"
mkdir -p "$RCAC_SCRATCH/rnaseq-project"
cd "$RCAC_SCRATCH/rnaseq-project"

nextflow run nf-core/rnaseq -r 3.26.0 \
  -profile purdue_gautschi \
  --cluster_account "$SLURM_JOB_ACCOUNT" \
  --input "$PROJECT_DIR/samplesheet.csv" \
  --fasta "$PROJECT_DIR/references/genome.fa.gz" \
  --gtf "$PROJECT_DIR/references/genes.gtf.gz" \
  --aligner star_salmon \
  --outdir "$PWD/results" \
  -resume -ansi-log false
```

Submit with `sbatch run_rnaseq.sh`. `--input` points to the samplesheet; `--fasta` and `--gtf` supply the references. `star_salmon` selects STAR alignment and Salmon quantification. The Gautschi profile supplies the container cache location and submits separate task jobs, so the 4 cores above are for the Nextflow manager.

To use your resource overrides from the previous section, place `custom.config` in `$RCAC_SCRATCH/rnaseq-project` and add `-c custom.config` to the run command. Copy final results from scratch to persistent project storage after completion.

## After the workshop

### Try standby for short tasks

On Gautschi, adding `--use_standby true` lets eligible CPU tasks use standby. Tasks must request at most 4 hours and 384 GB; other tasks use normal QoS. Leave this option out for the workshop's first run. See the [Gautschi profile](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config) for details.

### Ask for help

Join [nf-core Slack](https://nf-co.re/join) and ask in your pipeline's channel, such as `#rnaseq`, or in `#help` or `#nostupidquestions`.

Include the pipeline release, Nextflow version, cluster profile, launch command, and relevant error message. Remove sensitive sample information before sharing logs. Contact Purdue RCAC for account, storage, or scheduler questions.

### Useful links

- [nf-core pipelines](https://nf-co.re/pipelines)
- [RCAC Nextflow setup on Gautschi](https://docs.rcac.purdue.edu/lifesciences/guides/nextflow-gautschi/)
- [Gautschi institutional profile](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config)
