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

1. **Taxonomic classification** — [GTDBTk](https://ecogenomics.github.io/GTDBTk) `classify_wf` classifies each genome taxonomically (the `ani_screen` step is skipped); [QUAST](https://github.com/ablab/quast) evaluates assembly statistics.
2. **Quality assessment** — [CheckM2](https://github.com/chklovski/CheckM2) predicts completeness and contamination independently of their taxonomic classification using machine-learning models; [GUNC](https://github.com/grp-bork/gunc) checks for chimerism and contamination; [seqkit](https://github.com/shenwei356/seqkit) can optionally remove short contigs.
3. **Reporting** — a summary CSV is produced combining QC metrics and GTDBTk classification results.

## Usage

### Quickstart

#### From source code

1. Clone this repository (including submodules):

   ```bash
   git clone --recurse-submodules <repo-url>
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

3. Once the run has finished successfully and you have inspected the output, clean up intermediate files. The `work/` directory and `.nextflow.log` are useful for troubleshooting — do not delete them until you are satisfied the outputs are correct:

   ```bash
   rm -rf work .nextflow*
   ```

   Alternatively, use `nextflow clean` for more fine-grained control over which runs and intermediate files are removed.

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
ID,assembly_dir
sample1,/path/to/sample1/
sample2,/path/to/sample2/
```

### Output

Results are written to `--outdir` (default: `./results`):

```
results/
  gtdbtk/
    <sample_ID>_gtdbtk_summary.tsv    # GTDBTk taxonomic classification summary
  quast/
    <sample_ID>_quast_report.tsv      # QUAST assembly statistics report
  quast_summary/
    <sample_ID>_quast_summary.tsv     # Summarised QUAST metrics
  checkm2/
    <sample_ID>_quality_report.tsv    # CheckM2 completeness/contamination report
  gunc/
    <sample_ID>_gunc.tsv              # GUNC chimerism/contamination report
  seqkit/
    <sample_ID>/                      # Length-filtered FASTA files (after --min_contig filtering)
  report/
    <sample_ID>_final_report.tsv      # Combined QC and taxonomy summary
```

### Parameters

**Input/ Output options**
| Option | Type | Default | Description |
| `--manifest` | `path` | null | Directory where results are written. |
| `--outdir` | `path` | `./results` | Directory where results are written. |
| `--fasta_ext` | `string` | `fa` | File extension for input and output FASTA files. |

**Database options**

| Option         | Type   | Default                                             | Description                                |
| -------------- | ------ | --------------------------------------------------- | ------------------------------------------ |
| `--checkm2_db` | `path` | `/data/pam/software/checkm2_db/uniref100.KO.1.dmnd` | Path to the CheckM2 Diamond database file. |
| `--gunc_db`    | `path` | `/data/pam/software/gunc/GTDB/gunc_db_gtdb95.dmnd`  | Path to the GUNC Diamond database file.    |
| `--gtdbtk_db`  | `path` | `/data/pam/software/GTDBTk/release226`              | Path to the GTDBTk database directory.     |

---

**Other options**

| Option                | Type      | Default                                                                                         | Description                                                                                     |
| --------------------- | --------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `--min_contig`        | `integer` | `0`                                                                                             | Minimum contig length (bp). Contigs below this value are removed.                               |
| `--report_config`     | `path`    | (bundled, [`report_config.json`](assorted-sub-workflows/qc_isolates/assets/report_config.json)) | JSON configuration file to customise the summary report.                                        |
| `--temp_file_storage` | `string`  | `/tmp`                                                                                          | Directory for GTDBTk temporary files. Options: `/tmp`, `/dev/shm`, or `null` (write to memory). |
| `--temp_space`        | `string`  | `30GB`                                                                                          | Amount of temporary storage to reserve for GTDBTk jobs on the HPC.                              |

---

**Logging options**

| Option              | Type      | Default | Description                 |
| ------------------- | --------- | ------- | --------------------------- |
| `--monochrome_logs` | `boolean` | `false` | Output logs in plain ASCII. |

:warning: If using v1.0.0 of the pipeline please ensure you look at the README for that version, the parameters and defaults differ (specifically by `--min_contig` default and a version-specific flag `--keep_small_contigs`).

### Advanced usage

#### Report configuration

A configuration file can be supplied to the `--report_config` option to customise the final (per-sample) report generated by the pipeline. In particular, it allows (per-tool) customization of the identity column (to join the tool report tables together) and extract particular columns from these reports. The following tool names are currently mandatory: `GTDBTK`, `GUNC`, `CHECKM2` (NOTE: tool name must be uppercase). In the following example config block, we select 2 columns (`classification` and `closest_genome_reference`) to extract from the GTDBTk report and to use `user_genome` as the identity column:

```
"GTDBTK": {
    "id_column": "user_genome",
    "keep_columns": [
        "classification",
        "closest_genome_reference"
    ]
}
```

Please refer to the default [`report_config.json`](./assorted-sub-workflows/qc_isolates/assets/report_config.json) for expected JSON structure.

NOTE: In addition to columns derived from the tool reports, the script includes columns `genome_name`, `sample_or_strain_name` and `genome_status`. These are currently all derived from filenames (at some point).

| column                | description                                         |
| --------------------- | --------------------------------------------------- |
| genome_name           | Name of the input fasta file minus extension        |
| sample_or_strain_name | Name of the fasta file up to the last `_` character |
| genome_status         | `isolate`                                           |

#### GTDBTk temporary storage

GTDBTk requires significant memory which can be reduced by using temporary disk space. By default `/tmp` is used, which is the best configuration for the Sanger HPC. On other machines you may wish to set `--temp_file_storage /dev/shm` for faster I/O, check with your administrators if unsure. Ensure enough space is available or set `--temp_space` appropriately.

#### Minimum contig length

Set `--min_contig` to a positive value (e.g. `500`) to remove contigs with length shorter than the chosen value (in bp) from FASTA inputs. This can reduce contamination signals from fragmented assemblies. However, be aware that GTDBTk and QUAST currently run _before_ short contig removal by seqkit (i.e. pre-filter) whilst GUNC and CheckM2 run _after_ seqkit (post-filter).

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

For further help, check `.nextflow.log` and the per-process `.command.log` logs in the `work/` directory.

Sanger users may find [this page](https://ssg-confluence.internal.sanger.ac.uk/spaces/PaMI/pages/181078206/General+pipeline+info#Generalpipelineinfo-Troubleshootingafailedpipelinerunandsendingabugreport) useful for troubleshooting Nextflow pipeline runs.

## Issues and Contributions

**GitHub users:** if you find an issue with this pipeline, or would like to suggest an improvement, please log an issue or open a pull request on this repository.

**Sanger users:** if you need internal support, you can raise an issue on the PAM Freshservice portal: https://sanger.freshservice.com/support/catalog/items/426
