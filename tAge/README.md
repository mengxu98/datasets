# tAge transcriptomic clock models

This directory stores R-native conversions of the Elastic Net transcriptomic
clock models released with the tAge project.

## Source

- Original Zenodo record: https://zenodo.org/records/18763485
- Zenodo DOI: https://doi.org/10.5281/zenodo.18763485
- Code repository: https://github.com/Gladyshev-Lab/tAge
- Publication: Tyshkovskiy, A., Glubokov, D., Moliere, A., et al. Universal
  transcriptomic hallmarks of mammalian ageing and mortality. Nature (2026).
  https://doi.org/10.1038/s41586-026-10542-3

The Zenodo record is titled "Transcriptomic clock models and rodent gene
expression meta-dataset" and contains the original `.pkl` clock models.

## License and use

The upstream tAge package and transcriptomic clock models are distributed under
the MGB Open Access License 1.0 for non-commercial academic use. Commercial use
requires a separate license or agreement with Mass General Brigham.

See the upstream license for authoritative terms:
https://github.com/Gladyshev-Lab/tAge/blob/main/LICENSE

## Files

- `EN/models/*.rds`: R-native Elastic Net model objects converted from the
  original Zenodo `.pkl` files.
- `EN/manifest.tsv`: model index with source filename, source URL, checksum,
  size, parsed model metadata, and converted RDS checksum.
- `scripts/download_and_convert_en_models.R`: reproducible download and
  conversion script.

## Model object structure

Each RDS file is a list with:

- `model_type`: `"ElasticNet"`
- `pipeline`: upstream sklearn pipeline step names and classes
- `feature_names`: ordered model feature IDs
- `imputer_statistics`: median-imputation values
- `center`: StandardScaler centering values
- `scale`: StandardScaler scale values, or `NULL` when the upstream model does
  not scale by standard deviation
- `selected`: logical feature-selection mask
- `coef`: Elastic Net coefficients after feature selection
- `intercept`: Elastic Net intercept
- `species_adjustment`: tAge species scaling factors used for point prediction
- `source`: source Zenodo and file metadata

For Elastic Net point prediction, the R-native object is sufficient to reproduce
the sklearn prediction path without loading the original `.pkl` file.
