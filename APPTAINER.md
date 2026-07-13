# Advanced Apptainer/Singularity Container Guide

This repository ships an Apptainer definition file (`NISE.def`) that bakes every
dependency from `setup.py` plus the initialized submodules, the extracted REDUCE
hetdict, the LigandMPNN model weights, and the Boltz model / CCD cache into a
single GPU-enabled `.sif` image. Once built you do not need `uv`, a system
Python, or a pre-populated `~/.boltz`; just `--nv` and go.

Most users should download the prebuilt image from Hugging Face:

```bash
hf download benf549/NISE nise.sif --repo-type model --local-dir .
```

## Building The Container

The recommended build path is:

```bash
# Rootless build, recommended on shared clusters
bash build_container.sh                 # -> ./nise.sif

# Or choose a custom output name
bash build_container.sh my_nise.sif
```

`build_container.sh` removes top-level `.sif` artifacts before building so that
previous images are not accidentally copied into `/opt/NISE` by the `%files`
section of `NISE.def`.

You can also build manually:

```bash
apptainer build --fakeroot nise.sif NISE.def

# Or, with root:
sudo apptainer build nise.sif NISE.def
```

## Running The Container

Always pass `--nv` so the NVIDIA driver is forwarded:

```bash
# Interactive shell
apptainer shell --nv nise.sif

# Quick GPU / install sanity check
apptainer exec --nv nise.sif python -c \
    "import torch; print(torch.cuda.is_available(), torch.cuda.device_count())"

# Run the baked example scripts / apps
apptainer run --nv --app nise-boltz2x             nise.sif
apptainer run --nv --app nise-boltz2x-cli         nise.sif --help
apptainer run --nv --app nise-boltz1x             nise.sif
apptainer run --nv --app nise-boltz2x-ligandmpnn  nise.sif

# Run the boltz CLI directly
apptainer run --nv --app boltz nise.sif predict <inputs> ...

# Run an arbitrary script with the container's Python env
apptainer run --nv nise.sif /path/to/my_script.py
```

The baked CLI app is usually the easiest entry point:

```bash
apptainer run --cleanenv --nv --app nise-boltz2x-cli nise.sif \
    --input-pdb ./example_pdbs/02_apex_NISE_input-pose_00-seq_0980_model_0_rank_01.pdb \
    --smiles "COC1=CC=C(C=C1)N2C3=C(CCN(C3=O)C4=CC=C(C=C4)N5CCCCC5=O)C(=N2)C(=O)N" \
    --output-dir ./debug
```

This app will prepare the input for you by default: it protonates the ligand,
adds CONECT records, writes the prepared structure into
`./debug/input_backbones/`, and then launches the same NISE workflow used by
`run_nise_boltz2x.py`. If your input PDB is already protonated and has the
desired CONECT records, add `--no-prepare-input`.

## Baked Paths And Caches

The baked install lives at `/opt/NISE` inside the container (`$NISE_HOME`), the
Python interpreter at `/opt/NISE/.venv/bin/python`, and `/opt/NISE` is on
`PYTHONPATH` so `from LASErMPNN.run_inference import ...` resolves from any
working directory.

Boltz defaults to the baked cache at `/opt/NISE/boltz_cache` via `BOLTZ_CACHE`,
so the container does not depend on a host `~/.boltz`. Cache directories used by
`pykeops`, `matplotlib`, `torch`, and Hugging Face default to `/tmp/*` so the
read-only image is never written to.

Note: the `reduce` binary is *not* installed inside the container. If you want
`use_reduce_protonation=True`, bind-mount your own copy and set
`reduce_executable_path` accordingly in the `run_nise_*.py` scripts.
