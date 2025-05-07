version 1.0
# Pulls down paired fastq's for SRA ID's provided 

## TODO: add metadata pull using efetch
## TODO: add checksum for validation purposes
## TODO: add logging for better visibility

#### WORKFLOW DEFINITION

workflow SRA_Download {
  input { 
    Array[String] sra_id_list
  }

  scatter (id in sra_id_list) {
    call fastqdump {
      input:
        sra_id = id,
        ncpu = 8
    }
  }

  output {
    Array[File] output_R1 = fastqdump.r1_end
    Array[File?] output_R2 = fastqdump.r2_end
    Array[Boolean] is_paired_end = fastqdump.is_paired_end
  }

  parameter_meta {
    sra_id_list: "list of SRA sample ID's to be pulled down"

    output_R1: "array of R1 fastq files for each sample"
    output_R2: "array of R2 fastq files for each sample (null for single-end reads)"
    is_paired_end: "array of booleans indicating whether each sample used paired-end sequencing"
  }
}

#### TASK DEFINITIONS

task fastqdump {
  input {
    String sra_id
    Int ncpu = 8
  }

  command <<<
    set -eo pipefail
    # check if paired ended
    numLines=$(fastq-dump -X 1 -Z --split-spot "~{sra_id}" | wc -l)
    paired_end="false"
    if [ $numLines -eq 8 ]; then
      paired_end="true"
      echo true > paired_file
      parallel-fastq-dump \
        --sra-id ~{sra_id} \
        --threads ~{ncpu} \
        --outdir ./ \
        --split-files \
        --gzip
    else
      echo false > paired_file
      parallel-fastq-dump \
        --sra-id ~{sra_id} \
        --threads ~{ncpu} \
        --outdir ./ \
        --gzip
      # Rename the file to match the expected output format
      mv ~{sra_id}.fastq.gz ~{sra_id}_1.fastq.gz
      # Create an empty placeholder for R2
      touch ~{sra_id}_2.fastq.gz
    fi
  >>>

  output {
    File r1_end = "~{sra_id}_1.fastq.gz"
    File r2_end = "~{sra_id}_2.fastq.gz"
    Boolean is_paired_end = read_boolean('paired_file')
  }

  runtime {
    memory: 2 * ncpu + " GB"
    docker: "getwilds/sra-tools:3.1.1"
    cpu: ncpu
  }

  parameter_meta {
    sra_id: "SRA ID of the sample to be downloaded via parallel-fastq-dump"
    ncpu: "number of cpus to use during download"

    r1_end: "R1 fastq file downloaded for the sample in question"
    r2_end: "R2 fastq file downloaded for the sample in question (empty file for single-end reads)"
    is_paired_end: "boolean indicating whether the sample in question used paired-end read sequencing"
  }
}

