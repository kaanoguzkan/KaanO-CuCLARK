# CuCLARK Minimum Working Example

This MWE demonstrates the full CuCLARK classification pipeline using 3 small viral genomes from NCBI.

## What it does

1. Downloads phiX174 (~5kb), Lambda phage (~48kb), and T4 phage (~169kb) from NCBI RefSeq
2. Creates a targets file mapping genome files to taxon names
3. Generates 150 simulated reads (50 per genome, 150bp each)
4. Runs cuCLARK-l (light mode) classification
5. Shows a summary of classification results

## Running with Docker Compose (alkanlab workflow)

```bash
# Start the container
docker compose up -d

# Enter the container
docker exec -it rica_s_id_cuclark bash

# Run the MWE inside the container
bash /opt/cuclark/mwe/run_mwe.sh

# Or specify a custom output directory
bash /opt/cuclark/mwe/run_mwe.sh /rica_s/data/cuclark_mwe
```

## Running with Docker directly

```bash
docker run --rm --gpus all -v ./data:/data alkanlab/cuclark:2.0 bash -c \
  "bash /opt/cuclark/mwe/run_mwe.sh /data/mwe"
```

## Expected output

All 150 reads should be classified with high confidence:

```
Classification Summary
  File:           /data/mwe/results.csv
  Total reads:    150
  Classified:     150 (100.0%)
  Unclassified:   0 (0.0%)

  Top 3 taxa:
    phiX174   50  (33.3%)
    lambda    50  (33.3%)
    T4        50  (33.3%)
```

## Useful follow-up commands

```bash
# JSON output
cuclark summary /data/mwe/results.csv --format json

# Krona-compatible TSV
cuclark summary /data/mwe/results.csv --krona

# Filter by confidence
cuclark summary /data/mwe/results.csv --min-confidence 0.9

# Check GPU info
cuclark version
```
