# ---------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        g++ \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /cuclark
COPY . .

RUN cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CUDA_ARCHITECTURES="70;75;80;86;89;90" \
    && cmake --build build -j$(nproc) \
    && cmake --install build --prefix /usr/local

# ---------------------------------------------------------------
# Stage 2: Runtime (smaller image, no compiler)
# ---------------------------------------------------------------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        gawk \
        coreutils \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/cuCLARK        /usr/local/bin/cuCLARK
COPY --from=builder /usr/local/bin/cuCLARK-l      /usr/local/bin/cuCLARK-l
COPY --from=builder /usr/local/bin/getTargetsDef  /usr/local/bin/getTargetsDef
COPY --from=builder /usr/local/bin/getAccssnTaxID /usr/local/bin/getAccssnTaxID
COPY --from=builder /usr/local/bin/getfilesToTaxNodes /usr/local/bin/getfilesToTaxNodes

COPY *.sh /opt/cuclark/scripts/
RUN chmod +x /opt/cuclark/scripts/*.sh

WORKDIR /data
ENTRYPOINT ["/usr/local/bin/cuCLARK"]
