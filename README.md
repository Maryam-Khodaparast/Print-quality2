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
