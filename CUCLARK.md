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

## 9. Batch-classifying many small files (list mode)

When you have thousands of small FASTA files (e.g. 3000+ files with ~11 reads each), do **not** invoke `classify_metagenome.sh` once per file — the database load dominates runtime. Use cuCLARK's list mode so the DB loads once and all inputs are classified in sequence.

### Important: use `-n 1` for tiny per-file inputs

cuCLARK splits each input file into `numBatches` parallel windows **by byte offset**, where `numBatches = max(-b, -n)`. When a file has fewer reads than threads, windows land mid-read, the boundary-detection loop skips a `>` character, and the same read gets re-registered by multiple windows — producing **duplicate rows in the output CSV**.

Running `-n 1 -b 1` forces a single serial parse per file and eliminates the duplication. Parsing 11 reads is microseconds, so there's no practical cost; GPU classification speed is unchanged; and the DB still loads only once across the whole list.

### List-mode contract

- `-O inputs.txt`: plain text, one input FASTA/FASTQ path per line.
- `-R outputs.txt`: plain text, one output path per line (same order as `-O`). cuCLARK appends `.csv` — do **not** include the extension.
- The `-R` file **must already exist** before invocation; otherwise cuCLARK treats it as a single-file output path.
- The first line of `-O` must not start with `>` or `@` and must not contain 2 whitespace/comma-separated tokens, or cuCLARK treats it as a single FASTA.

### Loop script (with resume + crash-recovery blacklist)

```bash
cd /opt/cuclark/scripts
mkdir -p /work/results_all_run2
: > /work/blacklist.txt
: > /work/classify_run2.log

# Build the input list (one path per line). Adjust the search directory.
find /rica_s/_10seqs_3Q -type f \( -name '*.fasta' -o -name '*.fa' -o -name '*.fna' -o -name '*.fastq' \) | sort > /work/reads_list2.txt

prev_remaining=-1
stuck_count=0

while true; do
  # Compute remaining inputs by basename (robust to path/extension drift)
  comm -23 \
    <(awk -F/ '{f=$NF; sub(/\.(fa|fasta|fna|fastq)$/,"",f); print f"\t"$0}' /work/reads_list2.txt | sort) \
    <(ls /work/results_all_run2/*.csv 2>/dev/null | awk -F/ '{f=$NF; sub(/\.csv$/,"",f); print f}' | sort) \
    > /work/todo_pairs.txt

  if [ -s /work/blacklist.txt ]; then
    grep -vxFf /work/blacklist.txt /work/todo_pairs.txt > /work/todo_pairs.tmp && mv /work/todo_pairs.tmp /work/todo_pairs.txt
  fi

  cut -f2 /work/todo_pairs.txt > /work/todo.txt
  remaining=$(wc -l < /work/todo.txt)
  echo "[$(date +%H:%M:%S)] remaining: $remaining"
  [ "$remaining" -eq 0 ] && break

  awk -F/ '{f=$NF; sub(/\.(fa|fasta|fna|fastq)$/,"",f); print "/work/results_all_run2/"f}' /work/todo.txt > /work/todo_out.txt

  # -n 1 avoids the batch-boundary duplication bug; DB still loads once.
  ./classify_metagenome.sh -O /work/todo.txt -R /work/todo_out.txt -n 1 >> /work/classify_run2.log 2>&1

  # Crash recovery: blacklist the file the binary was on when it died
  bad=$(grep "Processing file" /work/classify_run2.log | tail -1 | sed "s/.*'\([^']*\)'.*/\1/")
  if [ -n "$bad" ]; then
    bad_base=$(basename "$bad")
    bad_base="${bad_base%.fasta}"; bad_base="${bad_base%.fa}"; bad_base="${bad_base%.fna}"; bad_base="${bad_base%.fastq}"
    if ! [ -f "/work/results_all_run2/${bad_base}.csv" ]; then
      echo "$bad_base" >> /work/blacklist.txt
      echo "blacklisted: $bad_base"
    fi
  fi

  # Bail if progress stalls (crash before any file, or a blacklist that doesn't match)
  if [ "$remaining" -eq "$prev_remaining" ]; then
    stuck_count=$((stuck_count+1))
    if [ "$stuck_count" -ge 3 ]; then
      echo "ERROR: no progress for 3 iterations, aborting. Check /work/classify_run2.log"
      break
    fi
  else
    stuck_count=0
  fi
  prev_remaining=$remaining
done

echo "Done. Results in /work/results_all_run2/"
ls /work/results_all_run2/*.csv 2>/dev/null | wc -l
```

### Running in an existing container

```bash
# From the host: list containers, pick the cuCLARK one
docker ps

# Open a shell in the running container
docker exec -it <container-name> bash

# Or launch the loop detached so it survives disconnects
docker exec -d <container-name> bash -c 'nohup bash /work/run.sh > /work/run.out 2>&1 &'
```

### Monitoring progress

From a second shell into the same container:

```bash
tail -f /work/classify_run2.log                              # per-file progress
watch -n 5 'ls /work/results_all_run2/*.csv | wc -l'         # CSV count climbing
nvidia-smi                                                   # GPU utilization
wc -l /work/blacklist.txt                                    # crashed files
```

### Sanity checks

```bash
# Every CSV should have 11 reads + 1 header = 12 lines (adjust for your read count).
# Files with any other line count indicate duplication or truncation.
find /work/results_all_run2 -name '*.csv' -exec wc -l {} + | awk '$1 != 12 && $2 != "total"'

# Input list count vs produced CSVs
wc -l /work/reads_list2.txt
ls /work/results_all_run2/*.csv | wc -l
```

### Retrieving results

Copy results out of the container to the host, then download to a local machine:

```bash
# On the host
docker cp <container-name>:/work/results_all_run2/. ~/cuclark_results_run2/
tar czf ~/cuclark_results_run2.tar.gz -C ~/cuclark_results_run2 .

# On your local PC
scp -o ProxyJump=user@jump.host user@remote.host:~/cuclark_results_run2.tar.gz ~/Downloads/
tar xzf ~/Downloads/cuclark_results_run2.tar.gz -C ~/Downloads/cuclark_results_run2/
```
