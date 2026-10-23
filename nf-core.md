---
layout: guide
lesson: nf-core
title: nf-core fundamentals
subtitle: Run a ready-made bioinformatics pipeline on Purdue HPC.
permalink: /nf-core/
---

In [Nextflow fundamentals]({{ '/' | relative_url }}), you connected processes and channels yourself. **nf-core provides ready-made pipelines built using Nextflow.** You choose a pipeline, provide your inputs, and let Nextflow run the analysis.

This **30–40 minute workshop** covers choosing a pipeline, running a small demo on Gautschi, checking results, and making a simple resource change. Downloading images and waiting for Slurm may take additional time.

## 1. Understand the main components · 5 minutes

| Component | What it does |
| --- | --- |
| **Nextflow** | Runs the workflow and tracks completed tasks |
| **nf-core** | Provides community-maintained bioinformatics pipelines |
| **Slurm** | Schedules tasks on the cluster |
| **Apptainer** | Runs the analysis software inside containers |
| **Institutional profile** | Supplies settings for your cluster |

Choose a pipeline for your research question at [nf-co.re/pipelines](https://nf-co.re/pipelines). Read its input requirements and use the documentation for the release you plan to run.

For example, **nf-core/rnaseq** performs RNA-seq quality control, trimming, alignment, and expression quantification. Your organism, reference genome, and analysis goals guide the parameter choices.

For this workshop, we will use **nf-core/demo** with a small test dataset.

## 2. Prepare your workspace · 5 minutes

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

## 3. Submit the demo · 10 minutes

Save the following as `run_demo.sh` in your workspace. Replace **both** occurrences of `YOUR_ACCOUNT`.

```bash
#!/bin/bash
#SBATCH --job-name=nfcore-demo
#SBATCH --account=YOUR_ACCOUNT
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
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
  -resume -ansi-log false
```

Submit and check your jobs:

```bash
sbatch run_demo.sh
squeue -u "$USER"
```

The script starts the **Nextflow manager** with 2 CPUs and 8 GB of memory. Nextflow submits separate Slurm jobs for the pipeline tasks, each with its own resource request. The manager must remain running until the pipeline finishes.

`nextflow run` downloads the pipeline code and required container images automatically. You do not need the nf-core toolkit. The Gautschi profile stores images in `$RCAC_SCRATCH/.apptainer/cache`, where later runs can reuse them. No extra cache settings are needed for this demo.

## 4. Check results and resume · 5 minutes

In your workspace, look for:

| File or folder | What to check |
| --- | --- |
| `nfcore-<job-id>.out` | Slurm output and pipeline progress |
| `results/` | Final outputs and reports |
| `work/` | Temporary files for each task |
| `.nextflow.log` | Detailed information if the run fails |

Open the MultiQC HTML report under `results/` to review the quality-control results.

The script already includes `-resume`. Once the previous run has stopped, submit it again:

```bash
sbatch run_demo.sh
```

Nextflow reuses unchanged, successfully completed tasks. **Keep the same run directory, `.nextflow/`, and `work/` to resume.**

If a task fails, start with the error in `nfcore-<job-id>.out`. It usually identifies the failed process and its work directory. Check that task's `.command.err` and `.command.log` for the tool's error message.

## Customize a site profile safely

Spend the final **5–10 minutes** on this example if time allows.

The institutional profile handles cluster settings. The pipeline supplies CPU, memory, and time requests for its analysis steps. For example, [rnaseq's `conf/base.config`](https://github.com/nf-core/rnaseq/blob/master/conf/base.config) defines resource groups such as `process_low`, `process_medium`, and `process_high`.

If one step needs more memory, use your own `custom.config` rather than editing the pipeline. For example, for an **rnaseq STAR alignment task**:

```groovy
process {
  withName: 'STAR_ALIGN' {
    cpus   = 16
    memory = 64.GB
    time   = 12.h
  }
}
```

This requests resources for each matching task. **It is an rnaseq example, not a setting needed for the demo.** Copy the process name from your run's error message and choose resources appropriate for your data.

Add the file to your usual launch command with:

```bash
-c custom.config
```

Two selectors are useful:

- `withName` changes a particular process.
- `withLabel` changes all processes with a resource label, such as `process_high`.

Some pipelines increase resources when retrying a failed task. `maxRetries = 1` allows **one retry after the first attempt**. An expression such as `memory = { 32.GB * task.attempt }` requests 32 GB initially and 64 GB on the retry, subject to resource caps. Retry behavior depends on the pipeline's configuration and the failure type.

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
