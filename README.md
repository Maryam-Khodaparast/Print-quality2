# Print quality: channel selection

Picks the channel, or combination of channels, of a scan that separates
printed ink from paper most reliably, and masks the printed area.

| file | what it does |
|---|---|
| `findChannel2Use.m` | chooses the channel or combination, and reports what it measured |
| `selectChannel.m` | that choice, plus the paper value and the printed area mask |
| `pqChannelStats.m` | paper level, noise, contrast and contrast to noise ratio of one plane |
| `pqOptimalMix.m` | noise whitened combination of the channels |
| `pqEstimateNoise.m` | noise standard deviation, robust to the print itself |
| `pqPaperLevel.m` | paper code value, from the histogram mode |
| `pqDenseRegions.m` | tells packed print from scattered dust and noise spikes |
| `pqBoxFilter.m`, `pqMosaic.m`, `pqSample.m`, `pqPercentile.m` | supporting measurements |
| `tests/` | the comparison against the old selection, the self tests, and the inspector for real scans |

Selection is by contrast to noise ratio rather than by standard deviation.
[docs/channel-selection.md](docs/channel-selection.md) says why, what it
measures against the old selection, and what it still cannot do.

```matlab
[imageGreyscale,mask,paper] = selectChannel(scan);

addpath tests
pqInspectScan('/path/to/your/scans')   % how your own scans score
```

# Print quality: head separation

Measures the cross web displacement of one printhead relative to its
neighbour, signed, from a printed chart.

| file | what it does |
|---|---|
| `pqHeadJoins.m` | the head to head joins, and whether their routing has been confirmed |
| `pqSplitXPattern.m` | the primary band: crossing diagonal marks, A B A groups, same head controls, ink witness |
| `pqMultiMarkPattern.m` | the cross check band: plain marks on three baselines, which also measures scanner scale |
| `pqHeadSeparationChart.m`, `pqHeadSeparationBitmap.m` | the whole chart, and which physical head prints each pixel |
| `measureHeadSeparation.m` | scan plus nominal geometry in, signed displacement and a verdict out |
| `pqAnalyseSplitX.m`, `pqAnalyseMultiMark.m` | the two analysers |
| `pqInkGain.m`, `pqWitnessBand.m` | how far each head's ink has grown past the edges it aimed at |
| `pqArmCentres.m`, `pqMarkCentre.m`, `pqLocalProfile.m`, `pqRobustLineFit.m` | the subpixel measurements |
| `pqRasteriseRects.m`, `pqRenderPattern.m`, `pqRegisterPattern.m` | geometry to pixels, and finding the band on a scan |
| `pqHeadSeparationOverlay.m`, `pqPlotHeadSeparation.m` | what a debug figure has to show, and the drawing of it. Called by nothing in the analysis |
| `runHeadSeparation.m` | make the charts, or measure a folder of scans |

The result is signed and stays signed: nothing takes an absolute value or
folds a result onto a pattern pitch. A result comes back with an uncertainty
and a verdict, and a band that cannot answer is refused rather than guessed.
[docs/head-separation.md](docs/head-separation.md) says how it works, what it
measures on synthetic scans, the one thing no pattern of this kind can do, and
what has to be printed on the real machine before the numbers mean anything.

```matlab
runHeadSeparation('demo')                  % print, scan and measure, no hardware
runHeadSeparation('bitmap','/tmp/chart')   % the chart, one bitmap per head
runHeadSeparation('measure','/tmp/scans')  % every scan in a folder

addpath tests
pqRunHeadSeparationSelfTests               % the checks that have to hold
pqHeadSeparationBenchmark                  % accuracy and the stress matrix
```
