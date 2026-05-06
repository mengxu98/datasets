# CytoTRACE 2 Model Data

This directory contains pre-trained model parameters and reference data for CytoTRACE 2, a computational method for predicting cellular developmental potential from single-cell RNA-sequencing data.

## Source

- **Original repository**: https://github.com/digitalcytometry/cytotrace2
- **Publication**: Kang, M., Brown, E., Almagro Armenteros, J.J. et al. "Improved reconstruction of single-cell developmental potential with CytoTRACE 2." *Nature Methods* (2025). https://doi.org/10.1038/s41592-025-02857-2
- **Authors**: Minji Kang, Erin Brown, Jose Juan Almagro Armenteros, Gunsagar Gulati, Rachel Gleyzer, and Susanna Avagyan (Stanford University, Newman Lab)

## License

The model parameters and associated data files are provided under the **Stanford Non-Commercial Software License Agreement**.

- Free for non-commercial use only.
- Commercial entities are prohibited from using this software for any purpose, including research.
- Commercial entities wishing to use this software should contact Stanford University's Office of Technology Licensing (docket S24-057).

See [LICENSE](LICENSE) for complete terms.

## Files

| File | Description |
|------|-------------|
| `model_parameters.rds` | Ensemble of 19 pre-trained GSBN models (6 layers each) for cellular potency prediction |
| `features_model_training_17.csv` | ~14,271 pre-selected mouse gene features used for model training |
| `mt_dict_human_to_mouse.csv` | Human-to-mouse orthology mapping (Ensembl BioMart 1-to-1 best match) |
| `mt_human_alias.csv` | Human gene alias/previous-symbol rescue mapping |
| `mt_mouse_alias.csv` | Mouse gene alias resolution mapping (MGI) |
| `LICENSE` | Stanford Non-Commercial Software License Agreement |

## Usage in scop

This data is used by the `RunCytoTRACE` function in the [scop](https://github.com/mengxu98/scop) R package. The function provides a native C++ implementation of the CytoTRACE 2 algorithm with RcppArmadillo acceleration.
