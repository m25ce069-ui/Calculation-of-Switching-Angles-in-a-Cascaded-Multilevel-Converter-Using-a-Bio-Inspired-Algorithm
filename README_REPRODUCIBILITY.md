# Reproducibility of the seven-level CHB fixed-configuration benchmark

This package supports the manuscript on DE, TLBO, GWO and AFTA at a 250 V peak fundamental reference. It contains the original 120 final runs, 24,120 batch-history records and 6717 improvement events supplied by the authors. No sensitivity experiments or new timing measurements were added in this revision.

## Files and entry points

- `CHB_UNIFICADO_usado.m`: unchanged archived source used for the supplied results.
- `CHB_UNIFICADO.m`: byte-identical copy with the filename matching its first function. Use this copy for MATLAB calls.
- `configuracion_y_entorno.mat` and `entorno_y_protocolo.txt`: original configuration and environment.
- `principal_250V/estudio.mat`: original complete saved study.
- `principal_250V/resultados_corridas.csv`: final values and target attainment for all 120 runs.
- `principal_250V/convergencia_por_corrida.csv`: per-run best objective at each recorded evaluation count.
- `principal_250V/mejoras_evaluacion_exacta.csv`: exact best-so-far improvement events.
- `principal_250V/estadistica_Friedman.csv`: four omnibus tests, tie correction, Kendall W and four-test Holm adjustment.
- `principal_250V/estadistica_pares_Wilcoxon_Holm.csv`: 24 paired comparisons, signed-rank and sign-test results, rank-biserial correlation and Holm adjustments.
- `reproducir_estadisticas.m`: new entry point to recompute those statistics from the original MAT file. Its statistical helper functions are copied unchanged from the archived source.
- `verificar_resultados.py`: independent electrical, convergence, attainment and Friedman consistency checks; not an independent implementation of all pairwise tests.
- `figuras_articulo.py`: regenerates the combined analytical waveform and target-attainment panels for Figures 17 and 18.
- `SHA256SUMS.txt`: checksums for all other files in this archive.

## MATLAB instructions

Extract the ZIP to a writable folder. In MATLAB set that folder as the Current Folder. Use MATLAB R2024b to match the recorded release. The source recommends R2020a or later and does not require Statistics and Machine Learning Toolbox; cross-version operation has not been tested in this revision.

Regenerate optimizer figures from saved data without new optimization:

```matlab
CHB_UNIFICADO('graficas', fullfile(pwd,'principal_250V','estudio.mat'));
```

Recompute the main inferential results from the saved runs, including their original recorded runtimes:

```matlab
reproducir_estadisticas;
```

Compare the two generated statistical CSV files with the correspondingly named originals in `principal_250V`. MATLAB is not available in the revision environment, so this new entry point has been reviewed statically but not executed there. The underlying statistical functions are unchanged from the executed source. This limitation does not affect the original supplied CSV files.

Run the full principal experiment again, including new timing measurements:

```matlab
CHB_UNIFICADO('principal');
```

This creates a timestamped results directory; it does not overwrite the archived study. The principal configuration is Np=1000, 201000 total evaluations and seeds 1:30 for each of the four methods. Keep the supplied source unchanged for verification. `prueba` is a smoke-test mode and `completo` requests additional experiments; neither corresponds to the published principal dataset. Runtime is machine- and session-dependent: new timings need not reproduce the numerical values or inferential results based on the original timings. Regeneration from `estudio.mat` is the correct route for checking the published timing statistics.

## Python instructions

Install Python with NumPy, pandas, SciPy and matplotlib, then run from the extracted folder:

```text
python verificar_resultados.py
python figuras_articulo.py
```

The first script asserts consistency and writes `verificacion_numerica.json`. The second writes Figures 17 and 18 as 600 dpi PNG files in `figuras_articulo/`. Both scripts were run successfully during this revision. The verification covers all 120 final electrical results, the 24,120 batch records, first-hit events and the four saved Friedman statistics. It does not rerun the optimization or independently validate every MATLAB instruction.

## Mapping to the manuscript

| Item | Principal source files or command |
| --- | --- |
| Tables 1 and 2 | `CHB_UNIFICADO.m`, `configuracion_y_entorno.mat`, `entorno_y_protocolo.txt` |
| Table 3 | `principal_250V/resumen_comparativo.csv` and `resultados_corridas.csv` |
| Table 4 | `resultados_corridas.csv`, `mejoras_evaluacion_exacta.csv`, conditional first-hit summaries in `resumen_comparativo.csv` |
| Table 5 | `estadistica_Friedman.csv` |
| Tables 6 and 7 | `estadistica_pares_Wilcoxon_Holm.csv`, filtered by metric `J` and `Tiempo_s` |
| Figure 9 | `convergencia_por_corrida.csv`; MATLAB `graficas` mode |
| Figures 10–12 | `resultados_corridas.csv`; MATLAB `graficas` mode |
| Figures 13–16 | `datos_espectro_DE.csv`, `datos_espectro_TLBO.csv`, `datos_espectro_GWO.csv`, `datos_espectro_AFTA.csv`; MATLAB `graficas` mode |
| Figures 17 and 18 | `figuras_articulo.py`, using original `resultados_corridas.csv` |

Tables display rounded values. Do not calculate spectra or repeat inference from rounded manuscript values. Paired differences use A minus B and all four metrics are minimized. For Tables 6 and 7 use `p_Holm_todas_comparaciones` for signed ranks and `p_Signos_Holm_global` for signs; do not substitute `p_Holm_por_metrica`. Each of those two families contains 24 tests. Table 5 uses `p_Holm_4_metricas`. Quantization is 1e-9 for J, THD in percentage points and voltage error in volts; 1e-6 s for runtime. It is used for statistical ranking, not to round the original measurements.

## Distribution

Attach this archive as supplementary material and make its contents available in the repository cited in Appendix A. Keep the principal scripts, README and datasets individually accessible. Confirm public access before submitting; packaging this archive does not publish or update the repository.
