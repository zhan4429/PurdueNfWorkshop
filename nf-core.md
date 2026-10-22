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

### Example: custom.config

Save the following as `custom.config` in `$RCAC_SCRATCH/nfcore-workshop`:

```groovy
// Example overrides for a modest workshop run
process {
  withLabel: 'process_low' {
    cpus = 2
    memory = '4 GB'
    time = '2h'
  }
  withName: '.*:FASTQC' {
    cpus = 2
    memory = '4 GB'
  }
}
// Keep the institutional Slurm executor and Apptainer settings.
```

Labels and process names vary by pipeline. Inspect the pipeline source and configuration and use the exact names it defines. `withName` matches a process name; `withLabel` matches a label. Specific selectors can override more general settings.

### Layer the override with -c

Run this command inside a compute allocation, with your profile and account substituted:

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
