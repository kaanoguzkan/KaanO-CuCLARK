# CuCLARK

## Overview

CuCLARK (CLARK for CUDA-enabled GPUs) classifies metagenomic DNA reads by comparing them against a reference database of discriminative k-mers, with classification accelerated on NVIDIA GPUs. Given a FASTA/FASTQ file of reads, it assigns each read to a taxonomic ID.

Two variants are available:
- **cuCLARK** — full, requires large RAM (~40 GB for bacterial DB) and VRAM
- **cuCLARK-l** — light, low-memory (~4 GB RAM, 1 GB VRAM)

## 1. Docker Image

```
alkanlab/cuclark:latest
```

Custom image built from CuCLARK source with CUDA 11.4. Supports GPUs from Kepler (K20, sm_35) to RTX 3070 (sm_86).

## 2. Docker Compose

```yaml
services:
  rica_s_id_cuclark:
    container_name: rica_s_id_cuclark
    entrypoint:
      - /bin/bash
    hostname: rica_s_id_cuclark
    image: alkanlab/rica_s_id_cuclark:latest
    ipc: private
    logging:
      driver: json-file
      options: {}
    networks:
      - rica_s_net
    stdin_open: true
    tty: true
    volumes:
      - /home/ricardo/projects/rica_s:/rica_s
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

networks:
  rica_s_net:
    external: true

Replace `/home/ricardo/projects/rica_s` with the directory containing your data.

## 3. Running with `docker run` (pulling from Docker Hub)

If you pull the image directly, use `-v` to mount your current directory:

```bash
docker run --gpus all -it -v $(pwd):/data alkanlab/cuclark:latest
```

- Your current folder is mounted at `/data` inside the container
- Any results written to `/data` appear in your current folder on the host
- The container drops you into a bash shell

## 4. How to Run CuCLARK

### Step 1: Build the database

```bash
cd /opt/cuclark/scripts
./set_targets.sh /data/DB custom --species
```

This will:
1. Download NCBI taxonomy data
2. Map each accession number in the reference FASTA to its taxonomy ID
3. Build the taxonomy tree for species-level classification

Available taxonomy ranks: `--species` (default), `--genus`, `--family`, `--order`, `--class`, `--phylum`.

For standard NCBI databases:
```bash
./set_targets.sh /data/DB bacteria
./set_targets.sh /data/DB bacteria viruses human
```

### Step 2: Classify reads

**cuCLARK-l** (light, recommended for limited GPU memory):

```bash
./classify_metagenome.sh -O /data/reads/sample.fastq -R /data/results/sample -n <threads> -b <batches> --light
```

**cuCLARK** (full, requires ~40 GB RAM for bacterial DB):

```bash
./classify_metagenome.sh -O /data/reads/sample.fastq -R /data/results/sample -n <threads> -b <batches>
```

Replace `<threads>` with CPU thread count (e.g., 4) and `<batches>` with GPU batch count (increase if OOM errors, e.g., 4 or 8).

The first run builds the discriminative k-mer database (`.ky`, `.lb`, `.sz` files). Subsequent runs reuse it.

### Step 3: View results

Results are stored in `results/sample.csv`. CSV format:

| Column | Description |
|--------|-------------|
| Object_ID | Read name |
| Length | Read length (bp) |
| Gamma | Ratio of discriminative k-mers found vs read length |
| 1st_assignment | Tax ID of best match (NA = unclassified) |
| hit count of first | Number of discriminative k-mers matching 1st assignment |
| 2nd_assignment | Tax ID of second-best match |
| hit count of second | k-mer count for 2nd assignment |
| confidence | score1 / (score1 + score2) |

## 6. Parameters Reference

| Flag | Description |
|------|-------------|
| `-O <file>` | Input FASTQ/FASTA file |
| `-P <f1> <f2>` | Paired-end reads |
| `-R <file>` | Output results path (without `.csv` extension) |
| `-n <int>` | Number of CPU threads |
| `-b <int>` | Number of GPU batches (increase for OOM errors) |
| `-d <int>` | Number of CUDA devices to use (default: all) |
| `-k <int>` | K-mer length (default: 31 for cuCLARK, 27 for cuCLARK-l) |
| `-g <int>` | Gap for non-overlapping k-mers in DB creation (cuCLARK-l only, default: 4) |
| `-s <int>` | Sampling factor (cuCLARK full only) |
| `--light` | Use cuCLARK-l (low memory variant) |
| `--tsk` | Create detailed target-specific k-mer files |
| `--extended` | Extended output with hit counts for all targets |
| `--gzipped` | Input files are gzipped |

## 7. System Requirements

| Resource | cuCLARK (full) | cuCLARK-l (light) |
|----------|---------------|-------------------|
| RAM | ~146 GB to build DB, ~40 GB to classify | 4 GB |
| VRAM | As much as possible (tested with 6 GB) | 1 GB minimum |
| GPU | CUDA compute capability 3.0+ | CUDA compute capability 3.0+ |
| CUDA | Tested with 7.5+, image uses 11.4 | Same |

## 8. Scripts in the Image

| Script | Location | Purpose |
|--------|----------|---------|
| `set_targets.sh` | `/opt/cuclark/scripts/` | Build database targets from reference genomes |
| `classify_metagenome.sh` | `/opt/cuclark/scripts/` | Run classification |
| `download_data.sh` | `/opt/cuclark/scripts/` | Download bacteria/viruses/human from NCBI |
| `download_data_newest.sh` | `/opt/cuclark/scripts/` | Download newest RefSeq genomes |
| `download_data_release.sh` | `/opt/cuclark/scripts/` | Download latest RefSeq release |
| `download_taxondata.sh` | `/opt/cuclark/scripts/` | Download NCBI taxonomy data |
| `clean.sh` | `/opt/cuclark/scripts/` | Delete all database data |
| `resetCustomDB.sh` | `/opt/cuclark/scripts/` | Reset custom database targets |
| `updateTaxonomy.sh` | `/opt/cuclark/scripts/` | Update taxonomy data from NCBI |
