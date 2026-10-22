# Download once, share an nf-core pipeline, and run it on Purdue HPC

Download a fixed pipeline release and its container images into your group's shared storage. Group members then run that local copy with their own samplesheet, configuration, work directory, and results. In each Slurm script, set `NXF_APPTAINER_CACHEDIR` to the downloaded image folder.

This example uses **nf-core/rnaseq 3.27.0 on Gautschi**. Replace `YOUR_GROUP`, `YOUR_ACCOUNT`, and all project paths with your own values. On another Purdue cluster, use its matching institutional profile and partition.

## 1. Choose what to share

| Contents | Suggested location | Who manages it? |
| --- | --- | --- |
| Pipeline release, bundled institutional configs, container images | A group directory in Data Depot | A designated group maintainer |
| Samplesheet, genome FASTA, annotation GTF | Project storage | Project members |
| Nextflow state, task work directories, temporary downloads | Each user's scratch space | Each user |
| Final results and run records | Project storage after the run | Project members |

Use storage that every compute node can access. Keep each installed release unchanged once people start using it; install new releases alongside it. Group members need read access to the pipeline and images, and directory traversal permission on their parent folders. Let a designated maintainer manage additions and updates.

## 2. Download the pipeline and images once

The maintainer needs Nextflow, Apptainer, and the nf-core toolkit available in the download environment. Use a compute allocation with internet access and your group's approved toolkit installation. The current toolkit command is `nf-core pipelines download`.

```bash
module purge
module load nextflow
# Activate your installed nf-core toolkit environment as appropriate.

nf-core --version
nextflow -version
apptainer --version

# This parent directory must already be writable by the maintainer.
mkdir -p /depot/YOUR_GROUP/pipelines/nf-core-rnaseq

nf-core pipelines download rnaseq \
  -r 3.27.0 \
  --outdir /depot/YOUR_GROUP/pipelines/nf-core-rnaseq/3.27.0 \
  --download-configuration yes \
  --container-cache-utilisation copy \
  --compress none
```

**When prompted, choose to download Apptainer-compatible container images.** The `copy` setting includes the images in the downloaded bundle rather than leaving them only in the maintainer's private cache. `none` avoids an archive packaging step. See the [nf-core download documentation](https://nf-co.re/docs/nf-core-tools/cli/pipelines/download).

Record the download command, toolkit version, and Nextflow version with the installation. Do not use `--force` to overwrite a release that other people are running.

## 3. Identify the pipeline and image folders

A layout like this is normal:

```text
/depot/YOUR_GROUP/pipelines/nf-core-rnaseq/3.27.0/
├── 3_27_0/                 # Pipeline code: main.nf and nextflow.config
├── configs/                # Bundled institutional profiles
└── <image-directory>/      # Container images; name depends on the toolkit
```

Some toolkit versions use a `workflow/` code folder instead. Inspect the actual download rather than assuming its folder names:

```bash
find /depot/YOUR_GROUP/pipelines/nf-core-rnaseq/3.27.0 \
  -maxdepth 3 -type f \
  \( -name main.nf -o -name '*.sif' -o -name '*.img' \) | head -30
```

Use the directory containing the **top-level `main.nf` and `nextflow.config`** as your pipeline path. Use the downloaded container image directory as your image path. Replace `IMAGE_FOLDER` in the Slurm script below with that actual directory name. Preserve the generated image filenames and symlinks so Nextflow can find them.

The toolkit can prepare multiple revisions and normalizes revision directory names; for example, `3.27.0` becomes `3_27_0`. See the [downloader implementation](https://github.com/nf-core/tools/blob/3.3.2/nf_core/pipelines/download.py#L582-L605).

## 4. Prepare your own run directory and config

Each group member creates a separate run directory. Keep your samplesheet and reference files at accessible absolute paths.

```bash
mkdir -p "$RCAC_SCRATCH/rnaseq-project1"
cd "$RCAC_SCRATCH/rnaseq-project1"
```

Save this as `custom.config` there:

```groovy
// Read the image location exported by the Slurm script.
apptainer.cacheDir = System.getenv('NXF_APPTAINER_CACHEDIR')
```

**This line is important on Gautschi:** its institutional profile defines `apptainer.cacheDir` explicitly. The override makes your script's chosen location take effect. See the [Gautschi profile](https://github.com/nf-core/configs/blob/master/conf/purdue_gautschi.config) and [Nextflow's Apptainer configuration](https://docs.seqera.io/nextflow/reference/config/apptainer#apptainercachedir).

Add any project-specific `withLabel` or `withName` resource overrides to this same file. For examples, see the [workshop guide's resource section](https://zhan4429.github.io/PurdueNfWorkshop/nf-core/#customize-a-site-profile-safely). Keep your overrides in your run directory rather than editing the shared pipeline.

## 5. Set the image path in your Slurm script

Save this as `run_rnaseq.sh` in your run directory. Replace `YOUR_ACCOUNT` in the Slurm header, all `/depot/YOUR_GROUP/...` paths, and `IMAGE_FOLDER` before submission. Adapt `3_27_0` if your download uses another code-directory name.

```bash
#!/bin/bash
#SBATCH --job-name=rnaseq
#SBATCH --account=YOUR_ACCOUNT
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=2-00:00:00
#SBATCH --output=rnaseq-%j.out

set -e
module purge
module load nextflow

# Shared installation: downloaded once by the group maintainer.
PIPELINE_DIR="/depot/YOUR_GROUP/pipelines/nf-core-rnaseq/3.27.0/3_27_0"
export NXF_APPTAINER_CACHEDIR="/depot/YOUR_GROUP/pipelines/nf-core-rnaseq/3.27.0/IMAGE_FOLDER"

# Your run: use the same directory when resuming this analysis.
RUN_DIR="$RCAC_SCRATCH/rnaseq-project1"
mkdir -p "$RUN_DIR"
cd "$RUN_DIR"

export NXF_HOME="$RCAC_SCRATCH/nextflow-home"
export NXF_WORK="$RUN_DIR/work"
export APPTAINER_CACHEDIR="$RUN_DIR/apptainer-cache"
export APPTAINER_TMPDIR="$RUN_DIR/apptainer-tmp"
mkdir -p "$NXF_HOME" "$NXF_WORK" \
  "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

# Confirm the installation and your config are available.
test -r "$PIPELINE_DIR/main.nf"
test -r "$PIPELINE_DIR/nextflow.config"
test -d "$NXF_APPTAINER_CACHEDIR"
test -r "$RUN_DIR/custom.config"

nextflow run "$PIPELINE_DIR" \
  -profile purdue_gautschi \
  --cluster_account "$SLURM_JOB_ACCOUNT" \
  -c "$RUN_DIR/custom.config" \
  --input /depot/YOUR_GROUP/project1/samplesheet.csv \
  --fasta /depot/YOUR_GROUP/references/genome.fa \
  --gtf /depot/YOUR_GROUP/references/genes.gtf \
  --outdir "$RUN_DIR/results" \
  -resume -ansi-log false
```

The FASTA and GTF must describe the same genome assembly. Add or adjust pipeline options for your experiment. Choose a Nextflow module compatible with the installed pipeline release; record the version actually loaded.

The 2 CPUs and 8 GB above are for the **Nextflow manager job**. Pipeline tasks get their own Slurm allocations from the institutional profile and your resource overrides. Set the manager's walltime long enough to supervise the entire analysis.

Submit from your run directory:

```bash
cd "$RCAC_SCRATCH/rnaseq-project1"
sbatch run_rnaseq.sh
squeue -u "$USER"
```

Because the command runs an installed directory, it uses that downloaded release. It does not need a remote pipeline name or `-r` to select a release.

## 6. Understand the three image-related settings

| Setting | Purpose in this workflow |
| --- | --- |
| `NXF_APPTAINER_CACHEDIR` | Points to the group's ready-to-run images; `custom.config` passes this to Nextflow. |
| `APPTAINER_CACHEDIR` | Your own cache for Apptainer downloads and layers. Keep it separate from the shared image folder. |
| `APPTAINER_TMPDIR` | Your temporary space for pulling or converting images. |

Apptainer's internal cache is per user; it is not the group's shared image collection. See the [Apptainer cache documentation](https://apptainer.org/docs/user/latest/build_env.html#cache-folders).

If a needed image is absent or has an unexpected filename, Nextflow may attempt a download. A user who cannot write to the shared image directory should ask the maintainer to complete the installation. Changing an environment variable does not move images already downloaded elsewhere.

Before announcing the installation to the group, run the pipeline's `test` profile with the same local pipeline, image folder, institutional profile, and cache override. A test-data run checks that setup, but does not exercise every optional analysis branch. Validate the options your group intends to use as well.

## 7. Resume and preserve results

Resubmit the same Slurm script to use `-resume`. Keep each analysis's launch directory, `.nextflow/` run history, and task work directory. Group members should not share those directories between independent analyses.

Copy final results, the samplesheet, run script, custom config, and version records to persistent project storage. Scratch can be cleaned automatically.

Pre-downloading the pipeline and images does not guarantee a completely offline run: Nextflow plugins, reference data, and any other required downloads must also be prepared. See [nf-core's offline checklist](https://nf-co.re/docs/usage/offline).

## 8. Ask the community when you need help

The [nf-core Slack community](https://nf-co.re/join) is very useful for asking other users and developers directly about pipeline errors and resource settings. Start in the pipeline's channel, such as `#rnaseq`, and include the release, Nextflow version, profile, run command, relevant config, and error message. Remove sensitive information before posting.

Contact Purdue RCAC for allocation, storage access, quota, and scheduler policy questions.
