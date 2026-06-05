# CIBERSORT LM22

This directory stores the LM22 immune-cell signature matrix used by CIBERSORT workflows.

- `LM22.rds`: RDS copy of the LM22 matrix from the `Moonerss/CIBERSORT` R package.
- Matrix shape: genes in rows and 22 immune cell types in columns.
- Intended consumer: `scop::RunCIBERSORT(sig_matrix = "LM22")`.

## Source

The matrix was generated from:

- Repository: https://github.com/Moonerss/CIBERSORT
- Source object: `data/LM22.rda`

## Notes

LM22 and CIBERSORT are method resources with their own citation and usage requirements. Users should cite the original CIBERSORT/LM22 publication and check the upstream license or terms before redistribution or publication use.
