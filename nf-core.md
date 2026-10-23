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

## Choose the right profile

There are two types of profiles to distinguish:

| Profile | What it configures |
| --- | --- |
| `-profile apptainer` | Container execution only, when the pipeline provides this profile. It does not configure Slurm accounts, partitions, or resource routing. |
| `-profile purdue_...` | Institutional settings for Slurm execution, Apptainer, and HPC resource policies. Prefer the profile matching your Purdue system. |

```bash
# Container-only profile: NOT a complete HPC configuration
nextflow run nf-core/demo -r 1.2.0 -profile test,apptainer --outdir results

# Gautschi profile: Slurm + Apptainer + site policies
nextflow run nf-core/demo -r 1.2.0 -profile test,purdue_gautschi \
  --cluster_account YOUR_ACCOUNT --outdir results
```

Use `test` only for example datasets. Purdue institutional profiles include `purdue_bell`, `purdue_gautschi`, and `purdue_negishi`; choose the one matching your system. The commands below use Gautschi. Replace `YOUR_ACCOUNT` with your allocation account.

> **Scratch first.** Start Nextflow from a compute allocation, not a login node. Keep work directories and container caches in `$RCAC_SCRATCH`; move important results to persistent storage.

## What the Gautschi profile provides

The [current Gautschi profile](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config) enables Slurm, native Apptainer with automatic mounts, and iGenomes at `/depot/itap/datasets/igenomes`. Supply `--cluster_account`.

| Task request | Routing in the current profile |
| --- | --- |
| CPU task, memory at most 384 GB | `cpu` |
| CPU task, memory above 384 GB | `highmem`; its documented policy requires at least 49 CPUs and a maximum 24-hour request |
| `process_gpu` label | `smallgpu` by default; `--gpu_partition ai` selects H100 GPUs |

Global ceilings: 192 CPUs, 1500 GB, 336 hours. **Partition limits still apply.** Highmem routing does not adjust CPUs or time; set compatible overrides.

Standby is opt-in with `--use_standby true`, for CPU tasks within 4 hours and 384 GB; high-memory and GPU tasks use normal QoS.

## Get a Gautschi compute allocation

Follow the [RCAC setup instructions](https://docs.rcac.purdue.edu/lifesciences/guides/nextflow-gautschi/#setting-up-on-gautschi):

```bash
# On the login node: find your account and request a compute session
slist
sinteractive -A YOUR_ACCOUNT -N 1 -n 2 -p cpu -t 2:00:00

# Continue with the workspace setup once the compute session starts.
```

Alternatively, use the batch script below. Keep an interactive allocation alive until Nextflow finishes.

## Prepare the workspace

Purdue provides Nextflow and the nf-core toolkit as modules; no manual installation is needed. Load them in your compute session and start from scratch:

```bash
module purge
module load nextflow
module load nf-core

mkdir -p "$RCAC_SCRATCH/nfcore-workshop"
cd "$RCAC_SCRATCH/nfcore-workshop"
```

Nextflow creates `work/` here automatically. The nf-core toolkit prepares pipeline downloads; Nextflow runs the pipeline.

### Are extra exports necessary?

| Variable | Needed for this setup? |
| --- | --- |
| `NXF_HOME` | No. Normally defaults to `$HOME/.nextflow`, holding user state such as plugins and downloaded pipeline code. Change it only if you want that storage elsewhere. |
| `NXF_WORK` | No. The default is `./work`, already in scratch because you changed into the scratch workspace. |
| `APPTAINER_TMPDIR` | No. Apptainer uses `$TMPDIR` or `/tmp` by default. Set it if image downloads or builds need more temporary space. |

For group image sharing, set only `NXF_APPTAINER_CACHEDIR` to the shared image folder, as shown below. 

### Where data should live

| Contents | Location |
| --- | --- |
| Input data | Project depot |
| `work/` task files | Scratch |
| Nextflow container images (`$RCAC_SCRATCH/.apptainer/cache`) | Scratch |
| Final results | Persistent storage or archive |

Scratch is not backed up. Keep the input sheet, run command, configuration, and final reports with your archived results.

## Two ways to obtain a pipeline

**Pipeline code and container images are stored separately.** A direct run downloads code into Nextflow's asset cache. The nf-core toolkit lets you prepare a group installation in a location you choose.

| Where files go | Direct `nextflow run nf-core/demo` | Download first with the nf-core toolkit |
| --- | --- | --- |
| Pipeline code | Under `$NXF_ASSETS`, which defaults to `$NXF_HOME/assets`. With no overrides, the root is `$HOME/.nextflow/assets`. | Under `--outdir`, for example `/depot/YOUR_GROUP/nfcore/pipelines/nf-core-demo/1.2.0/1_2_0/`. |
| Container images | Pulled as needed into the configured Apptainer image cache. | All pipelines add images to one shared group folder, such as `/depot/YOUR_GROUP/nfcore/container-images/`, using `amend` mode. |
| Institutional configs | Normally fetched from nf-core/configs when configuring the run. | Included when requested with `--download-configuration yes`. |
| How you launch | Use the repository name, such as `nf-core/demo`. | Use the local directory containing `main.nf` and `nextflow.config`. |

With the default `NXF_HOME`, directly fetched pipeline code goes under `$HOME/.nextflow/assets`. A module or your own `NXF_HOME` / `NXF_ASSETS` setting can change this location. See [Nextflow's environment settings](https://docs.seqera.io/nextflow/reference/env-vars#nxf_assets).

### Where images go during a direct run

With `-profile test,purdue_gautschi`, the [Gautschi profile](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config) stores images in `$RCAC_SCRATCH/.apptainer/cache`. Without an explicit image-cache setting or environment override, Nextflow's native Apptainer default is an `singularity/` folder under the work directory, usually `work/singularity/`. Images are reused on later runs. See [Nextflow's Apptainer image handling](https://docs.seqera.io/nextflow/container/apptainer#apptainer-and-docker-hub).

Running `nextflow run nf-core/demo` alone does not select an HPC or container profile. Use the full profiled command above on Purdue.

### Download once and share with your group

**Use one group image folder for all pipelines and releases.** Keep each pipeline release in its own code directory. 

```text
/depot/YOUR_GROUP/nfcore/
├── container-images/                   # Images reused by every pipeline
└── pipelines/
    ├── nf-core-demo/1.2.0/1_2_0/        # Demo code
    └── nf-core-rnaseq/3.27.0/3_27_0/    # RNA-seq code
```

```bash
module load nextflow
module load nf-core

export NXF_APPTAINER_CACHEDIR="/depot/YOUR_GROUP/nfcore/container-images"
mkdir -p "$NXF_APPTAINER_CACHEDIR" \
  /depot/YOUR_GROUP/nfcore/pipelines/nf-core-demo

nf-core pipelines download demo -r 1.2.0 \
  --outdir /depot/YOUR_GROUP/nfcore/pipelines/nf-core-demo/1.2.0 \
  --download-configuration yes \
  --container-system apptainer \
  --container-cache-utilisation amend \
  --compress none
```

**`amend` adds missing images to the central cache and avoids copying images into the pipeline's folder.** Repeat for other pipelines with the same image folder and a different pipeline name, release, and `--outdir`. Existing matching images can be reused. See the [nf-core downloader documentation](https://nf-co.re/docs/nf-core-tools/cli/pipelines/download).

Inspect the downloaded code directory: its name may be `1_2_0/` or `workflow/`, depending on the toolkit version. Use the directory containing `main.nf` and `nextflow.config`.

In each user's Slurm script, point to the shared image folder and the desired pipeline release:

```bash
export NXF_APPTAINER_CACHEDIR="/depot/YOUR_GROUP/nfcore/container-images"

nextflow run /depot/YOUR_GROUP/nfcore/pipelines/nf-core-demo/1.2.0/1_2_0/ \
  -profile test,purdue_gautschi \
  -c custom.config --cluster_account YOUR_ACCOUNT \
  --outdir "$PWD/results" -resume
```

Add this line to your own `custom.config` so the Gautschi profile uses the image path exported by your script:

```groovy
apptainer.cacheDir = System.getenv('NXF_APPTAINER_CACHEDIR')
```

Use the Slurm script below as the wrapper, replacing its image-cache export and run command with this example. For RNA-seq or another pipeline, substitute the release, local path, and required inputs; use `test` only for test datasets.

Both download modes can use this central image cache when configured to point there. Give group members read access to the code and images from all compute nodes, and let maintainers add missing images. Keep each analysis's work directory, run history, and Apptainer's own `APPTAINER_CACHEDIR` in per-user storage. Pipeline releases remain separate while their images are shared. Pre-downloading code and images does not also prepare every plugin or reference dataset.

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

For the workshop demo, run this command inside a compute allocation, with your account substituted:

```bash
nextflow run nf-core/demo -r 1.2.0 \
  -profile test,purdue_gautschi \
  -c custom.config \
  --cluster_account YOUR_ACCOUNT \
  --outdir "$PWD/results" -resume
```

`-c` adds your custom configuration on top of the pipeline and institutional settings. Review the effective configuration before a large run:

```bash
nextflow pull nf-core/demo -r 1.2.0
nextflow -c custom.config config nf-core/demo \
  -profile test,purdue_gautschi -flat | less
```

### Choose CPUs, memory, and time

Start with pipeline defaults. Check the task trace under `results/pipeline_info/`, Slurm `seff JOBID`, and memory/time failures. Increase only the processes that need it. A request exceeding a node or partition limit can remain pending or fail submission.

> **Manager resources and task resources are separate.** The manager job below requests 2 CPUs and 8 GB to run Nextflow. The institutional profile determines how each pipeline task is submitted. Manager `#SBATCH` settings are separate from `process.cpus`, `memory`, and `time`.

## Launch through Slurm

Save this as `run_demo.sh` in `$RCAC_SCRATCH/nfcore-workshop`. Replace **both** occurrences of `YOUR_ACCOUNT`. This example uses Gautschi's `cpu` partition and `purdue_gautschi` profile; adapt them for another cluster. Keep `custom.config` in the same workspace.

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
export NXF_APPTAINER_CACHEDIR="$RCAC_SCRATCH/.apptainer/cache"
mkdir -p "$NXF_APPTAINER_CACHEDIR"

nextflow run nf-core/demo -r 1.2.0 -profile test,purdue_gautschi \
  -c custom.config --cluster_account YOUR_ACCOUNT \
  --outdir "$PWD/results" -resume -ansi-log false
```

Submit from the workspace:

```bash
cd "$RCAC_SCRATCH/nfcore-workshop"
sbatch run_demo.sh
```

The demo is pinned to [release `1.2.0`](https://github.com/nf-core/demo/releases/tag/1.2.0). It requires Nextflow **25.10.4 or newer**, as specified in its [pipeline configuration](https://github.com/nf-core/demo/blob/1.2.0/nextflow.config). Check the loaded version with `nextflow -version`. For another pipeline, choose a compatible release with `-r VERSION` and supply its required inputs. Save your Nextflow version and custom config with the results; a pipeline release pin does not freeze the shared institutional profile.

## Use idle resources with standby

**Standby is useful for running short tasks on idle capacity across the cluster, including resources outside your group's purchased allocation.** On Negishi, standby jobs have low priority, can run for at most **four hours per job**, and do not consume the group's normal allocation balance. Start time depends on available capacity. See [RCAC's standby policy](https://www.rcac.purdue.edu/knowledge/negishi/run/slurm/queues).

The four-hour limit applies to each Slurm job, not to the total duration of a pipeline whose manager stays running. Nextflow can reuse completed tasks after an interruption with `-resume`.

### Enable standby for pipeline tasks

The [Negishi profile documentation](https://github.com/nf-core/configs/blob/master/docs/purdue_negishi.md#standby-queue-optional) enables standby with `--use_standby true`. The profile checks each task's requested resources:

| Profile | Tasks eligible for standby | Other tasks |
| --- | --- | --- |
| `purdue_negishi` | Time at most 4 hours and memory at most 256 GB | Normal QoS |
| `purdue_gautschi` | CPU tasks with time at most 4 hours and memory at most 384 GB | Normal QoS, including high-memory and GPU tasks |

Create a copy of the Slurm script above named `run_demo_standby.sh`. Keep its environment setup and use this run command **on Negishi**:

```bash
nextflow run nf-core/demo -r 1.2.0 \
  -profile test,purdue_negishi \
  --cluster_account YOUR_ACCOUNT \
  --use_standby true \
  --outdir "$PWD/results" -resume -ansi-log false
```

On Gautschi, use `test,purdue_gautschi` instead. For a downloaded pipeline, replace `nf-core/demo -r 1.2.0` with its local code directory. Keep `-c custom.config` if you need the shared-image override or project resource settings; a step requesting more than four hours will use normal QoS. The profile adds `--qos=standby` to eligible child jobs automatically.

### Choose where the manager runs

To run the Nextflow manager itself in standby too, submit the copied script with:

```bash
sbatch --qos=standby --time=04:00:00 run_demo_standby.sh
```

Use your usual account and the `cpu` partition from the script. `standby` is a **QoS**, not an account. The submission option controls the manager job; `--use_standby true` controls the pipeline's child jobs.

For longer analyses, keep the manager on normal QoS and request enough walltime for the whole run. Eligible child tasks can still use standby. This also lets longer tasks finish on normal QoS while the manager remains active.

### Resume after a timeout or failed task

Once the previous manager has stopped, resubmit the same script from the same run directory. Its run command already contains `-resume`. Keep `.nextflow/`, the task work directory, inputs, and pipeline release so eligible completed tasks can be reused. Inspect and correct the failure before resubmitting when needed.

**Resume preserves completed tasks; an interrupted task normally starts again from the beginning.** It does not give one task unlimited runtime in four-hour pieces. If a task repeatedly needs more than four hours, give that process a longer time request so the profile routes it to normal QoS. Automatic retries also depend on the pipeline's retry policy. See [Nextflow's resume documentation](https://docs.seqera.io/nextflow/cache-and-resume).

## Inspect, resume, and preserve

```bash
squeue -u "$USER"      # monitor jobs
nextflow log           # run history
# Failed task: inspect work/xx/hash/.command.err
# Rerun the same command with -resume
nextflow clean -n      # preview only; do not rush cleanup
```

Keep the work directory and run history available for `-resume`. Archive important results and the information needed to reproduce the run before cleaning up scratch.

## Get help directly in nf-core Slack

**nf-core Slack is a very useful place to ask other users and pipeline developers directly for help.** If you are stuck on a pipeline error, resource override, input format, or interpretation of a pipeline option, ask the community early. Other users may have encountered the same issue, and developers can help explain the pipeline's behavior. The [nf-core community recommends Slack as the first place to seek help running its pipelines](https://nf-co.re/join#slack).

1. [Request an invitation](https://nf-co.re/join), then sign in at [nfcore.slack.com](https://nfcore.slack.com/).
2. Join the channel for your pipeline, such as `#methylseq`. For general help or beginner questions, use `#help` or `#nostupidquestions`.
3. Post a clear question in the channel so other users and developers can join the discussion and benefit from the answer.

### What to include in your question

- Pipeline name and release (`-r`), plus your Nextflow version.
- Cluster and profile, such as Gautschi and `purdue_gautschi`.
- The run command and relevant `withLabel` or `withName` overrides.
- The error message, failing process name, and relevant task logs.
- Requested memory/time and Slurm job details when asking about resources.

Remove personal information and sensitive sample details before sharing logs or samplesheets. For an nf-core bug, the community may ask you to open an issue in the pipeline's GitHub repository. For general Nextflow language or engine questions, use the [Nextflow Community Forum](https://community.seqera.io/), as directed by [nf-core's help guidance](https://nf-co.re/join).

Contact Purdue RCAC for account access, allocations, quota, and scheduler policy questions.

## Reference documents

- [Purdue Gautschi institutional profile source](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config): current execution, resource routing, and cache settings.
- [RCAC: Reproducible Bioinformatics Using Nextflow](https://docs.rcac.purdue.edu/lifesciences/guides/nextflow-gautschi/): compute-node setup and the pinned demo walkthrough.
- [Join the nf-core community](https://nf-co.re/join): Slack invitation and support guidance.

> **Take-home:** Institutional profile = HPC integration. Custom `-c` = targeted overrides. Apptainer cache and Nextflow work = scratch. Final results = persistent storage.
