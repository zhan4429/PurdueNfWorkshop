// Read QC with Nextflow: fastp -> FastQC -> MultiQC

params.fastq_dir = "${System.getenv('RCAC_SCRATCH')}/nextflow_workshop/fastq"
params.outdir = 'results/local'

// Each FASTQ is processed independently in single-end mode.
// The outputs are NOT synchronized paired-end reads.


// Step 1: trim reads with fastp
process FASTP {
    tag "${reads.simpleName}"
    cpus 2
    memory '4 GB'
    time '30m'
    publishDir "${params.outdir}/fastp", mode: 'copy'

    input:
    path reads

    output:
    path '*.trimmed.fastq.gz', emit: trimmed
    path '*.fastp.json',       emit: json
    path '*.fastp.html'

    script:
    """
    fastp -w ${task.cpus} -i "${reads.name}" \\
        -o "${reads.simpleName}.trimmed.fastq.gz" \\
        -j "${reads.simpleName}.fastp.json" \\
        -h "${reads.simpleName}.fastp.html"
    """
}


// Step 2: FastQC on the trimmed reads
process FASTQC {
    tag "${reads.simpleName}"
    cpus 2
    memory '4 GB'
    time '30m'
    publishDir "${params.outdir}/fastqc", mode: 'copy'

    input:
    path reads

    output:
    path '*_fastqc.zip', emit: zip
    path '*_fastqc.html'

    script:
    """
    fastqc -t ${task.cpus} "${reads.name}"
    """
}


// Step 3: combine all reports with MultiQC
process MULTIQC {
    cpus 1
    memory '4 GB'
    time '30m'
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path reports

    output:
    path 'multiqc_report.html'

    script:
    """
    multiqc .
    """
}


workflow {
    reads_ch = channel.fromPath("${params.fastq_dir}/*.fastq.gz", checkIfExists: true)

    FASTP(reads_ch)
    FASTQC(FASTP.out.trimmed)
    MULTIQC(FASTP.out.json.mix(FASTQC.out.zip).collect(sort: true))
}
