# QC Isolates

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

[[_TOC_]]

> [!CAUTION]
> Version 1.0.0 sets `--min_contig` to 1000 by default, filtering contigs shorter than 1000 bp. If using v1.0.0 and you do not want this behaviour, use `--keep_small_contigs`. This flag is deprecated in all later versions, where `--min_contig` defaults to 0.

## Pipeline overview

QC Isolates is a Nextflow DSL2 pipeline for assessing the quality of bacterial isolate genomes. It is not suitable for Metagenome-Assembled Genomes (MAGs); use [QC MAGs](../qc_mags) for those. The two pipelines differ primarily in that metagenomic decontamination is not applied to known isolates.

The pipeline performs the following steps:

1. **Taxonomic classification** — GTDBTk `classify_wf` classifies each genome taxonomically (the `ani_screen` step is skipped); QUAST evaluates assembly statistics.
2. **Quality assessment** — CheckM2 predicts completeness and contamination using machine-learning models; GUNC checks for chimerism and contamination; seqkit can optionally remove short contigs.
3. **Reporting** — a summary CSV is produced combining QC metrics and GTDBTk classification results.

## Usage

### Quickstart

#### From source code

1. Clone this repository (including submodules):

   ```bash
   git clone --recurse-submodules https://gitlab.internal.sanger.ac.uk/sanger-pathogens/pipelines/qc_isolates.git
   cd qc_isolates
   ```

2. To run with `docker`, use the `-profile docker` option:

   ```bash
   nextflow run main.nf \
       -profile docker \
       --manifest manifest.csv \
       --outdir my_output
   ```

   Other profiles are also supported (`singularity`).  
   :warning: If no profile is specified the pipeline will run with the Sanger HPC-specific configuration.

3. Once the run has finished, clean up intermediate files:

   ```bash
   rm -rf work .nextflow*
   ```

#### Using on the Sanger farm

First load the latest pipeline module:

```bash
module load qc_isolates
```

Then run on the command line with `qc_isolates <options>`. For instance, to see a help message:

```bash
qc_isolates --help
```

Submit to LSF:

```bash
bsub -o output.o -e error.e -q oversubscribed -R "select[mem>4000] rusage[mem=4000]" -M4000 \
    qc_isolates \
        --manifest manifest.csv \
        --outdir my_output
```

### Input

#### Manifest (`--manifest`)

A CSV file with per-sample paths to directories containing isolate genome FASTA files. Run `qc_isolates --help` for the exact manifest format required by this pipeline version.

```
ID,FASTA_DIR
sample1,/path/to/sample1/
sample2,/path/to/sample2/
```

### Output

Results are written to `--outdir` (default: `./results`):

```
results/
  gtdbtk/
    <sample_ID>/                   # GTDBTk classification output
  quast/
    <sample_ID>/                   # QUAST assembly statistics
  checkm2/                         # CheckM2 completeness/contamination reports
  gunc/                            # GUNC chimerism reports
  reports/
    summary.csv                    # Combined QC and taxonomy summary
```

### Parameters

**Database options**

| Option         | Type   | Default                                             | Description                                |
| -------------- | ------ | --------------------------------------------------- | ------------------------------------------ |
| `--checkm2_db` | `path` | `/data/pam/software/checkm2_db/uniref100.KO.1.dmnd` | Path to the CheckM2 Diamond database file. |
| `--gunc_db`    | `path` | `/data/pam/software/gunc/GTDB/gunc_db_gtdb95.dmnd`  | Path to the GUNC Diamond database file.    |
| `--gtdbtk_db`  | `path` | `/data/pam/software/GTDBTk/release226`              | Path to the GTDBTk database directory.     |

---

**Other options**

| Option                | Type      | Default   | Description                                                                                        |
| --------------------- | --------- | --------- | -------------------------------------------------------------------------------------------------- |
| `--fasta_ext`         | `string`  | `fa`      | File extension for output FASTA files.                                                             |
| `--min_contig`        | `integer` | `0`       | Minimum contig length (bp). Contigs below this value are removed before QC metrics are calculated. |
| `--report_config`     | `path`    | (bundled) | JSON configuration file to customise the summary report.                                           |
| `--temp_file_storage` | `string`  | `/tmp`    | Directory for GTDBTk temporary files. Options: `/tmp`, `/dev/shm`, or `null` (write to memory).    |
| `--temp_space`        | `string`  | `30GB`    | Amount of temporary storage to reserve for GTDBTk jobs on the HPC.                                 |

---

**Output options**

| Option              | Type      | Default     | Description                          |
| ------------------- | --------- | ----------- | ------------------------------------ |
| `--outdir`          | `path`    | `./results` | Directory where results are written. |
| `--monochrome_logs` | `boolean` | `false`     | Output logs in plain ASCII.          |

### Advanced usage

#### GTDBTk temporary storage

GTDBTk requires significant temporary disk space. By default `/tmp` is used. On the Sanger HPC, consider `/dev/shm` for faster I/O. For large datasets, ensure sufficient space is available or increase `--temp_space`.

#### Minimum contig length

Set `--min_contig` to a positive value (e.g. `500`) to remove short contigs from FASTA inputs before running QC. This can reduce contamination signals from fragmented assemblies.

### Dependencies

All software dependencies are containerised. The following databases must be available locally (Sanger HPC defaults are pre-configured):

- CheckM2 Diamond database (`--checkm2_db`)
- GUNC Diamond database (`--gunc_db`)
- GTDBTk database (`--gtdbtk_db`)

## Software versions

| Software | Version | Image                                                     |
| -------- | ------- | --------------------------------------------------------- |
| GTDBTk   | 2.4.1   | `quay.io/biocontainers/gtdbtk:2.4.1--pyhdfd78af_1`        |
| QUAST    | 5.3.0   | `quay.io/biocontainers/quast:5.3.0--py39pl5321heaaa4ec_0` |
| CheckM2  | 1.0.2   | `quay.io/biocontainers/checkm2:1.0.2--pyh7cba7a3_0`       |
| GUNC     | 1.0.6   | `quay.io/biocontainers/gunc:1.0.6--pyhdfd78af_0`          |
| seqkit   | 2.10.0  | `quay.io/biocontainers/seqkit:2.10.0--h9ee0642_0`         |

See `assorted-sub-workflows/qc_isolates/modules/` for pinned container versions.

## Troubleshooting

- **GTDBTk fails with out-of-disk-space**: ensure the `--temp_file_storage` directory has sufficient space. On the Sanger HPC, use `/dev/shm` or a scratch directory.
- **Database not found**: confirm all database paths exist and are accessible. Default Sanger HPC paths are pre-configured.
- **Resuming a failed run**: add `-resume` to your command to restart from cached intermediate results.
- For further help, check `.nextflow.log` and the per-process logs in the `work/` directory.

## Issues and Contributions

**GitHub users:** if you find an issue with this pipeline, or would like to suggest an improvement, please log an issue or open a pull request on this repository.

**Sanger users:** if you need internal support, you can raise an issue on the PAM Freshservice portal: https://sanger.freshservice.com/support/catalog/items/426
