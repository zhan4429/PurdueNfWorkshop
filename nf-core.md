---
layout: guide
lesson: nf-core
title: nf-core fundamentals
subtitle: From Nextflow concepts to reproducible, community-maintained bioinformatics pipelines on Purdue HPC.
permalink: /nf-core/
---

## What changes after Workshop 1?

In [Nextflow fundamentals]({{ '/' | relative_url }}), you connected processes and channels yourself. **nf-core supplies ready-made, versioned pipelines.** Institutional profiles connect those pipelines to Purdue Slurm and Apptainer.

| Component | Role |
| --- | --- |
| **Nextflow** | The engine that runs processes and channels |
| **nf-core** | Community-maintained bioinformatics pipelines |
| **Profiles** | Settings that connect a pipeline to your HPC system |
| **Slurm** | Schedules the pipeline's tasks |
| **Apptainer** | Provides the software in containers |

This lesson follows the [four-page workshop flyer]({{ '/nfcore_fundamentals_4page_flyer_UPDATED.pdf' | relative_url }}).

## Choose the right profile

There are two types of profiles to distinguish:

| Profile | What it configures |
| --- | --- |
| `-profile apptainer` | Container execution only, when the pipeline provides this profile. It does not configure Slurm accounts, partitions, or resource routing. |
| `-profile purdue_...` | Institutional settings for Slurm execution, Apptainer, and HPC resource policies. Prefer the profile matching your Purdue system. |

```bash
# Container-only profile: NOT a complete HPC configuration
nextflow run nf-core/demo -profile test,apptainer

# Institutional profile: Slurm + Apptainer + site policies
nextflow run nf-core/demo -profile test,PURDUE_PROFILE \
  --cluster_account YOUR_ACCOUNT --outdir results
```

Use `test` only for example datasets. Purdue institutional profiles include `purdue_bell`, `purdue_gautschi`, and `purdue_negishi`; replace `PURDUE_PROFILE` with the one matching your system. Replace `YOUR_ACCOUNT` with your allocation account.

> **Scratch first.** Start Nextflow from a compute allocation, not a login node. Keep work directories and container caches in `$RCAC_SCRATCH`; move important results to persistent storage.

## Control where Nextflow writes

Purdue uses Apptainer. Some Nextflow and nf-core settings still contain the historic word **Singularity**; this does not mean you must install Singularity.

Prepare the workspace before submitting the launch script later in this guide:

```bash
mkdir -p "$RCAC_SCRATCH/nfcore-workshop"
cd "$RCAC_SCRATCH/nfcore-workshop"
mkdir -p work images apptainer-tmp apptainer-cache

export NXF_HOME="$PWD/.nxf-home"
export NXF_WORK="$PWD/work"
export NXF_SINGULARITY_CACHEDIR="$PWD/images"
export NXF_APPTAINER_CACHEDIR="$PWD/images"
export APPTAINER_CACHEDIR="$PWD/apptainer-cache"
export APPTAINER_TMPDIR="$PWD/apptainer-tmp"
```

### What does each variable mean?

| Variable | Purpose |
| --- | --- |
| `NXF_HOME` | Nextflow installation, plugins, and metadata; avoids filling your home quota. |
| `NXF_WORK` | Hashed task directories and intermediate files used when resuming a run. |
| `NXF_SINGULARITY_CACHEDIR` | Nextflow-managed container image cache when the `singularity` engine is selected; common in older Purdue examples. |
| `NXF_APPTAINER_CACHEDIR` | Corresponding Nextflow image cache for the native `apptainer` engine; use for Purdue institutional profiles that enable Apptainer. |
| `APPTAINER_CACHEDIR` | Apptainer's own download/blob cache, separate from Nextflow's image cache. |
| `APPTAINER_TMPDIR` | Temporary space for pulling and converting images. |

> **Check the profile's cache setting.** An institutional profile can define `apptainer.cacheDir` itself. Explicit configuration can take precedence over environment defaults. Both Nextflow cache variable names are shown for teaching; you only need the one matching the engine in use.

### Where data should live

| Contents | Location |
| --- | --- |
| Input data | Project depot |
| `work/` task files | Scratch |
| `images/` container images | Scratch |
| Final results | Persistent storage or archive |

Scratch is not backed up. Keep the input sheet, run command, configuration, and final reports with your archived results.

## Customize a site profile safely

Institutional profiles provide sensible defaults. Use a small overlay configuration for project-specific resources rather than editing the shared nf-core profile.

### When the default memory is not enough

A pipeline's predefined resources may be too small for your data. For example, an alignment task might fail because it runs out of memory. Confirm the cause in the task log and Slurm report, then increase the resources for the affected steps in a **custom configuration file**. You do not need to edit the pipeline source.

Choose the selector based on how broadly the change should apply:

| Selector | What it changes | When to use it |
| --- | --- | --- |
| `withLabel` | Every process carrying the matching label, such as `process_low`, `process_medium`, or `process_high` | Several steps in a resource tier need larger requests. |
| `withName` | A process matched by its name, alias, or fully qualified workflow path | One particular step needs more memory or time. |

The spelling is **`withLabel`**. Labels and process names vary by pipeline and release. Check the pipeline's `conf/base.config` and module definitions for labels. Find a failing process's full name in the Nextflow error message, `.nextflow.log`, or execution trace.

### Example: custom.config

The following example is adapted from a methylseq run. It combines resource tiers with an override for one alignment process. Save it as `custom.config` in your run directory. These values illustrate a larger analysis; they are **not required resources for the small demo dataset**. Choose values that fit your data and partition.

```groovy
process {
  // Upper bounds for each task's request (Nextflow 24.04 or newer)
  resourceLimits = [
    cpus: 16,
    memory: 100.GB,
    time: 48.h
  ]

  // Apply to every process carrying the corresponding label
  withLabel: 'process_low' {
    cpus   = { 2 * task.attempt }
    memory = { 14.GB * task.attempt }
    time   = { 6.h * task.attempt }
  }
  withLabel: 'process_medium' {
    cpus   = { 6 * task.attempt }
    memory = { 42.GB * task.attempt }
    time   = { 8.h * task.attempt }
  }
  withLabel: 'process_high' {
    cpus   = { 12 * task.attempt }
    memory = { 84.GB * task.attempt }
    time   = { 10.h * task.attempt }
  }

  // Target one process using its fully qualified name
  withName: 'NFCORE_METHYLSEQ:METHYLSEQ:FASTQ_ALIGN_DEDUP_BWAMETH:BWAMETH_ALIGN' {
    memory = 60.GB
    time = 24.h
  }
}
```

Keep the institutional Slurm executor and container settings. Copy the exact process path from **your own pipeline run**; the methylseq path above will not match a step in `nf-core/demo` or necessarily in another methylseq release.

### How the overrides work

- **By label:** on the first attempt, a `process_medium` task requests 6 CPUs, 42 GB, and 8 hours. Every process with that label gets those settings.
- **By name:** the named `BWAMETH_ALIGN` process requests 60 GB and 24 hours. A matching `withName` selector takes priority over a `withLabel` selector for the same setting. Its CPU request still comes from other applicable settings because this name block does not set `cpus`.
- **On retries:** `task.attempt` starts at 1. If Nextflow retries a medium task, attempt 2 requests 12 CPUs, 84 GB, and 16 hours, subject to the caps. These expressions do not enable retries themselves; the pipeline's `errorStrategy` and `maxRetries` must allow the retry. The fixed 60 GB and 24 hours in the name block stay fixed on retries.
- **At the limits:** `resourceLimits` caps each task's request; it does not allocate those resources to every task. For example, a high-tier task's second attempt would calculate 24 CPUs and 168 GB, but these are capped at 16 CPUs and 100 GB. If the task needs more than the cap, it can still run out of memory. Check both your custom caps and any pipeline or site limits.

For a single failing step, a smaller file containing only the relevant `withName` block inside `process { ... }` is often sufficient. To increase memory on each retry for that step as well, use `memory = { 60.GB * task.attempt }`, with suitable limits and a retry policy.

See the Nextflow documentation for [selector matching and priority](https://docs.seqera.io/nextflow/config#process-selectors), [dynamic task resources](https://docs.seqera.io/nextflow/process#dynamic-task-resources), and [resource limits](https://docs.seqera.io/nextflow/reference/process/directives/resource-limits).

### Layer the override with -c

Add `-c custom.config` to the same `nextflow run` command you normally use. Keep the pipeline version, input arguments, and institutional profile for your analysis. The same approach works with a local pipeline path, as in the methylseq launch example, or a pipeline name such as `nf-core/demo`.

For the workshop demo, run this command inside a compute allocation, with your profile and account substituted:

```bash
nextflow run nf-core/demo \
  -profile test,PURDUE_PROFILE \
  -c custom.config \
  --cluster_account YOUR_ACCOUNT \
  --outdir "$PWD/results" -resume
```

`-c` adds your custom configuration on top of the pipeline and institutional settings. Review the effective configuration before a large run:

```bash
nextflow config nf-core/demo -profile PURDUE_PROFILE \
  -c custom.config -flat | less
```

### Choose CPUs, memory, and time

Start with pipeline defaults. Check a representative task's `trace.txt`, Slurm `seff JOBID`, and memory/time failures. Increase only the processes that need it. A request exceeding a node or partition limit can remain pending or fail submission.

> **Manager resources and task resources are separate.** The manager job below requests 2 CPUs and 8 GB to run Nextflow. The institutional profile determines how each pipeline task is submitted. Manager `#SBATCH` settings are separate from `process.cpus`, `memory`, and `time`.

## Launch through Slurm

Save this as `run_demo.sh` in `$RCAC_SCRATCH/nfcore-workshop`. Replace **both** occurrences of `YOUR_ACCOUNT`, plus `YOUR_PARTITION` and `PURDUE_PROFILE`. Keep `custom.config` in the same workspace.

```bash
#!/bin/bash
#SBATCH --job-name=nfcore-demo
#SBATCH --account=YOUR_ACCOUNT
#SBATCH --partition=YOUR_PARTITION
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=nfcore-%j.out

module load nextflow
cd "$RCAC_SCRATCH/nfcore-workshop"
export NXF_HOME="$PWD/.nxf-home"
export NXF_WORK="$PWD/work"
export NXF_APPTAINER_CACHEDIR="$PWD/images"
export APPTAINER_CACHEDIR="$PWD/apptainer-cache"
export APPTAINER_TMPDIR="$PWD/apptainer-tmp"
mkdir -p "$NXF_APPTAINER_CACHEDIR" \
  "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

nextflow run nf-core/demo -profile test,PURDUE_PROFILE \
  -c custom.config --cluster_account YOUR_ACCOUNT \
  --outdir "$PWD/results" -resume -ansi-log false
```

Submit from the workspace:

```bash
cd "$RCAC_SCRATCH/nfcore-workshop"
sbatch run_demo.sh
```

For a real pipeline, pin its release with `-r VERSION` and supply its required inputs.

## Inspect, resume, and preserve

```bash
squeue -u "$USER"      # monitor jobs
nextflow log           # run history
# Failed task: inspect work/xx/hash/.command.err
# Rerun the same command with -resume
nextflow clean -n      # preview only; do not rush cleanup
```

Keep the work directory and run history available for `-resume`. Archive important results and the information needed to reproduce the run before cleaning up scratch.

## Get help

Join the [nf-core Slack community](https://nf-co.re/join). Ask in `#help`, `#nostupidquestions`, or the pipeline-specific channel. Include the pipeline version, command, profile, relevant logs, and sanitized samplesheet details.

Contact Purdue RCAC for allocation, quota, and scheduler problems.

> **Take-home:** Institutional profile = HPC integration. Custom `-c` = targeted overrides. Apptainer cache and Nextflow work = scratch. Final results = persistent storage.
