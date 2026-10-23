# Materials review status — October 16, 2026

The workshop scripts, README, online guide, printable view, and nf-core
placeholder were reviewed and tested.

- Launch from `$RCAC_SCRATCH/nextflow_workflow`; inputs are stored separately in
  `$RCAC_SCRATCH/nextflow_workshop/fastq`.
- Parameters and task resources are in `main.nf`. `hpc.config` sets the Slurm
  executor, partition, and account only. All job and task limits are 30 minutes.
- The local launcher requests four CPUs and 12 GB; the HPC launcher requests
  one CPU and 4 GB for the Nextflow manager.
- All 11 FASTQ files are processed independently in single-end mode, producing
  23 Nextflow tasks. Outputs are not synchronized paired-end reads.
- Both launchers use `-resume`. A completed local run can supply cached tasks
  to a later Slurm run. README and guide explain removing `-resume` for the
  first Slurm demonstration, then restoring it for resubmissions.
- `field-guide.html` renders the same `index.md` and source scripts as the
  website. The separate four-page flyer and committed PDF were retired.
- The nf-core fundamentals page is intentionally a placeholder.

Passed: shell and JavaScript syntax, real downloads and gzip checks, repeat
setup, Bash execution with simulated QC tools, real Nextflow 25.10.4 execution
and resume, generated Slurm scripts with a simulated scheduler, missing-input
and tool-failure checks, log commands, internal/external links, all 14 copy
buttons, responsive layouts, source-example synchronization, and print layout.

Real Purdue module availability, QC-tool execution, account/partition policy,
and scheduler behavior still require a run on the training system. QC tools
and Slurm commands were simulated locally; Nextflow and downloads were real.

Detailed audit evidence is in `/tmp/purdue-audit-20261016/audit-results.md`.
This local review note is excluded from GitHub Pages.
