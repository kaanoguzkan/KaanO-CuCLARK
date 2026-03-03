# Setup Guide

## Option 1: Docker (Recommended)

### Requirements

- Docker
- NVIDIA GPU with driver installed
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

### Pull and run

```bash
docker pull alkanlab/cuclark:2.0
```

```bash
# Check GPU detection
docker run --rm --gpus all alkanlab/cuclark:2.0 version
```

### Run the demo

```bash
docker run --rm --gpus all -v ./data:/data alkanlab/cuclark:2.0 \
  bash -c "bash /opt/cuclark/mwe/run_mwe.sh /data/mwe"
```

This downloads 3 small viral genomes, generates test reads, classifies them, and shows results. Takes about a minute.

---

## Option 2: Build from Source

### Requirements

- Linux (64-bit)
- CMake 3.20+
- GCC with C++17 support
- CUDA Toolkit 11.0+
- NVIDIA GPU (compute capability 7.0+)

### Build

```bash
git clone https://github.com/alkanlab/cuclark.git
cd cuclark
bash scripts/install.sh
```

Binaries go to `exe/`. The `cuclark` wrapper goes to `bin/`.

### Verify

```bash
# Check version and GPU detection
cuclark version

# Or if not in PATH:
python3 scripts/cuclark version
```

---

## Usage

### 1. Set up a database

Download genomes from NCBI and build the target database:

```bash
cuclark setup-db --db-dir /data/db bacteria viruses
```

This downloads genomes and taxonomy data, then builds the k-mer database. Takes a while for large databases (bacteria = ~150 GB RAM needed for full mode).

For a specific taxonomy rank:

```bash
cuclark setup-db --db-dir /data/db bacteria --rank genus
```

### 2. Classify reads

```bash
cuclark classify \
  --reads /data/reads.fa \
  --output /data/results \
  --targets /data/db/.targets \
  --db-dir /data/db/
```

The wrapper auto-detects GPUs and selects the best variant:
- **8+ GB VRAM** → cuCLARK (full mode)
- **< 8 GB VRAM** → cuCLARK-l (light mode)

To force a specific variant:

```bash
cuclark classify --full ...    # Force full mode
cuclark classify --light ...   # Force light mode
```

For paired-end reads:

```bash
cuclark classify \
  --paired /data/R1.fastq /data/R2.fastq \
  --output /data/results \
  --targets /data/db/.targets \
  --db-dir /data/db/
```

### 3. View results

```bash
# Text summary
cuclark summary /data/results.csv

# Filter by confidence
cuclark summary /data/results.csv --min-confidence 0.9

# JSON output
cuclark summary /data/results.csv --format json

# Krona-compatible TSV (for Krona visualization)
cuclark summary /data/results.csv --krona > krona_input.tsv
```

### 4. Other commands

```bash
# Download genomes only (without building DB)
cuclark download --db-dir /data/db bacteria viruses

# List available databases
cuclark list-db --db-dir /data/db

# GPU info
cuclark version
```

---

## Docker Compose (Lab Workflow)

For persistent containers with GPU access:

```bash
docker compose up -d
docker exec -it rica_s_id_cuclark bash
```

Inside the container, all `cuclark` commands are available. Run the MWE to verify:

```bash
bash /opt/cuclark/mwe/run_mwe.sh
```

Edit `docker-compose.yml` to change volume mounts and container name for your environment.

---

## Tuning

| Flag | Default | Description |
|------|---------|-------------|
| `--kmer-size` / `-k` | 31 (full), 27 (light) | k-mer length |
| `--threads` / `-n` | 1 | CPU threads |
| `--batches` / `-b` | auto | GPU batches (higher = less memory per batch) |
| `--devices` / `-d` | all GPUs | Number of GPUs to use |

If you get out-of-memory errors, increase `--batches`. If classification is slow, increase `--threads`.

---

## Custom Database

To classify against your own genomes:

```bash
# 1. Prepare a tab-separated mapping file (filename → tax ID)
cat > tax_map.tsv <<EOF
genome1.fna	12345
genome2.fna	67890
EOF

# 2. Set up the custom database
bash scripts/setup_custom_db.sh /path/to/fasta_dir tax_map.tsv /data/custom_db

# 3. Classify
cuclark classify \
  --reads /data/reads.fa \
  --output /data/results \
  --targets /data/custom_db/.fileToTaxIDs \
  --db-dir /data/custom_db/
```

Or use the built-in custom database support:

```bash
# Put your FASTA files in a "Custom" folder inside the DB directory
mkdir -p /data/db/Custom
cp *.fna /data/db/Custom/

cuclark setup-db --db-dir /data/db custom
```
