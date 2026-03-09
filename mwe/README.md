# CuCLARK MWE — FASTA Test

Tests the CuCLARK pipeline by classifying simulated reads from a FASTA file against viral reference genomes.

## What it does

1. Validates FASTA format (header, characters, N-content)
2. Generates 200 simulated reads (150bp) from informative regions
3. Downloads 3 small viral genomes (phiX174, Lambda, T4) from NCBI
4. Copies the input FASTA as a self-classification target
5. Runs cuCLARK classification
6. Prints a results summary with a sanity check

## Usage

```bash
# Inside the Docker container
bash /opt/cuclark/mwe/test_example_fasta.sh [DATA_DIR] [INPUT_FASTA]

# Defaults: DATA_DIR=/data/test_example, INPUT_FASTA=example.fasta
```

### With Docker directly

```bash
docker run --gpus all -v ${PWD}:/data cuclark \
  bash /opt/cuclark/mwe/test_example_fasta.sh
```

### With Docker Compose

```bash
docker compose up -d
docker exec -it rica_s_id_cuclark bash
bash /opt/cuclark/mwe/test_example_fasta.sh
```

## Expected output

All 200 reads should classify as the input target with confidence 1.0:

```
  Total reads:    200
  Classified:     200
  Sanity check: 200 reads classified as human_chr1
  PASS: Reads from human chr1 are being classified back to human_chr1
```
