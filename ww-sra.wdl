version 1.0
# Pulls down paired fastq's for SRA ID's provided 

#### WORKFLOW DEFINITION

workflow SRA_Download {
  input { 
    Array[String] sra_id_list
  }

  scatter ( id in sra_id_list ){
    call fastqdump {
      input:
        sra_id = id,
        ncpu = 8
    }
  }

  output {
    Array[File] output_R1 = fastqdump.r1_end
    Array[File] output_R2 = fastqdump.r2_end
  }

  parameter_meta {
    sra_id_list: "list of SRA sample ID's to be pulled down and aligned"

    output_R1: "array of R1 fastq files for each sample"
    output_R2: "array of R2 fastq files for each sample"
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
    fi
    # perform fastqdump
    if [ $paired_end == 'true' ]; then
      echo true > paired_file
      parallel-fastq-dump \
        --sra-id ~{sra_id} \
        --threads ~{ncpu} \
        --outdir ./ \
        --split-files \
        --gzip
    else
      touch paired_file
      parallel-fastq-dump \
        --sra-id ~{sra_id} \
        --threads ~{ncpu} \
        --outdir ./ \
        --gzip
    fi
  >>>

  output {
    File r1_end = "~{sra_id}_1.fastq.gz"
    File r2_end = "~{sra_id}_2.fastq.gz"
    String paired_end = read_string('paired_file')
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
    r2_end: "R2 fastq file downloaded for the sample in question"
    paired_end: "string indicating whether the sample in question used paired-end read sequencing"
  }
}

