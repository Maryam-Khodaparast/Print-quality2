# Choosing a channel from a scan

`findChannel2Use` picks the channel, or the combination of channels, that a
print quality measurement should be taken from. This note says why the
standard deviation it used to pick on does not survive a noisy scan, what
replaced it, and what the replacement still cannot do.

## Why the standard deviation fails

The old selection scored each channel with `std(double(channel(:)))` and took
the largest. The standard deviation of a scan is the spread of everything in
it, and only some of that is print:

* **Noise counts as signal.** A channel with no ink in it at all but 14 code
  values of scanner noise scores higher than a clean channel carrying the
  print. On the `faint cyan bars, noisy blue channel` case below the standard
  deviation picks the empty blue channel every time, and the scan that comes
  back is noise.
* **A sparse feature scores low however clean it is.** Spread goes as
  `contrast * sqrt(coverage)`, so a fine line covering 1% of the scan divides
  its contrast by ten before it is compared with anything.
* **Shading counts as signal.** An illumination gradient across the scan
  raises the standard deviation of every channel without helping any of them
  separate ink from paper.
* **Dust counts as signal.** A few hundred specks of very dark dust move the
  standard deviation more than a faint tint does.

The quantity that decides whether the print can actually be told apart from
the paper is not the spread. It is the contrast between ink and paper
compared with the noise the ink has to be told apart from - the contrast to
noise ratio, `CNR = contrast/noise`. That is what the selection scores on now.

## What the selection does

1. **Find the printed area, once.** Each channel is searched for pixels that
   stand clear of the paper level and have neighbours doing the same. Dust,
   hot pixels and noise spikes are scattered rather than packed, so they do
   not survive that test (`pqDenseRegions`). If no channel shows print pixel
   by pixel, the search is repeated over a box average, where print too faint
   to clear the noise in any single pixel still stands clear (`pqBoxFilter`).
   The channel that shows most of the print defines the printed area.
2. **Measure every candidate over that same area.** Print is the same
   physical thing in every channel, so judging each channel over its own idea
   of where the print is compares them over different pixels and lets
   whatever a channel happens to contain be measured as though it were print.
   The candidates are each channel on its own, the two neutrals (`min` and
   `max` across channels), the mean, and the noise weighted mix below.
3. **Score by contrast to noise ratio** (`pqChannelStats`):
   * *paper* is the mode of the histogram, refined to sub code value
     accuracy, with a clipping spike at the top or bottom of the scale
     discounted unless it is most of the scan;
   * *contrast* is the median deviation from paper over the printed area, so
     it does not change with how much of the scan is printed;
   * *noise* is a median based estimate from the Laplacian of Immerkaer and
     from neighbouring pixel differences (`pqEstimateNoise`). Being medians,
     they are not inflated by edges, text or halftone dots; being a
     Laplacian, the first is blind to illumination shading; and both are
     refined over the paper alone once the paper level is known.
4. **Offer a noise weighted mix** (`pqOptimalMix`). Ink usually shows in more
   than one channel and scanner noise is correlated between channels, so the
   best combination is neither the mean nor any single channel. With ink and
   paper levels `inkLevels` and `paperLevels` and the noise covariance `C`
   measured over the paper, the weights that maximise CNR are
   `C\(paperLevels-inkLevels)` - the matched filter for ink, which adds the
   channels that carry signal and subtracts the noise they share. The weights
   are scaled to sum to one so the result stays on the code value scale of
   the scan.
5. **Prefer the simple answer.** A combination has to beat the best single
   channel by 20% before it is taken, so the choice does not flip between
   near equal candidates from one scan to the next.
6. **Say when the scan is not worth trusting.** If nothing reaches a CNR of
   3, `info.lowConfidence` is set and `selectChannel` refuses the scan rather
   than returning a mask of noise. Pure noise, and noise on paper clipped at
   the top of the scale, are both refused in 20 scans out of 20.

## What it measures against the old selection

`tests/pqCompareChannelSelection` runs both selections over synthetic scans
whose ink, noise, shading, dust and screening are known, so the choice can be
scored against what was really there. `eff` is the CNR the choice delivers as
a fraction of the best available candidate, and `IoU` is the overlap of the
printed area mask from `selectChannel` with the true printed area.

| case | std eff | std IoU | CNR eff | CNR IoU |
|---|---|---|---|---|
| solid black bars, clean scan | 0.57 | 1.00 | 1.00 | 1.00 |
| faint cyan bars, noisy blue channel | 0.01 | 0.33 | 1.00 | 1.00 |
| faint yellow bars, noisy blue channel | 0.80 | 0.39 | 0.89 | 0.58 |
| fine lines, 1% coverage, noisy blue | 1.00 | 1.00 | 1.00 | 1.00 |
| 30% halftone tint, noisy blue | 0.19 | 0.07 | 1.48 | 1.00 |
| illumination gradient of 25 levels | 1.00 | 0.46 | 0.92 | 0.59 |
| dust on the glass, faint magenta bars | 1.00 | 0.99 | 1.00 | 1.00 |
| ink in two channels, shared scanner noise | 1.00 | 0.36 | 1.52 | 0.96 |
| bright feature, noisy blue channel | 0.18 | 0.22 | 1.00 | 0.97 |
| saturated paper, faint print | 1.00 | 0.62 | 1.09 | 0.76 |
| text target, noisy red channel | 0.09 | 0.03 | 1.00 | 1.00 |
| **mean** | **0.62** | **0.50** | **1.08** | **0.90** |

The best available candidate is chosen on 9 of the 11 cases against 5 of 11,
and the two it does not win it loses by 8% and 11% rather than by the factor
of ten the standard deviation loses by when it goes wrong. Where the figure
is above 1.00 the noise weighted mix beat every single channel and every
fixed combination.

## Other methods that were considered

* **Otsu, or the Fisher ratio between the two classes.** Sound where the
  print covers a good share of the scan, and no use where it does not: with a
  1% feature the split lands inside the paper distribution. The contrast used
  here is a median over the printed area, which does not care about coverage.
* **Principal components across the channels.** Maximises variance, which is
  the same trap the standard deviation falls into - the first component of a
  scan with one noisy channel is that noisy channel. The noise whitened mix
  maximises contrast against noise instead, which is the discriminant
  direction rather than the direction of most spread.
* **Entropy, or gradient energy.** Both rank a noisy channel top for the same
  reason: noise carries plenty of both.
* **A median filter before measuring.** Removes dust, and removes halftone
  dots with it, which on a screened tint is the print. Judging each pixel by
  the company it keeps (`pqDenseRegions`) drops the dust and keeps the dots.

## What it still cannot do

* **Shading comparable with the contrast.** The paper level is one number for
  the whole scan, so an illumination gradient of 25 code values against a
  contrast of 25 leaves a mask that follows the shading (IoU 0.59 above, and
  0.46 for the old code). Fixing that means estimating the paper level over a
  coarse grid and interpolating it, which is a change to the masking rather
  than to the selection.
* **Scans printed more than about half over.** The paper level is the
  histogram mode, which assumes the paper is the most common thing in the
  scan.
* **Very light screened tints.** Below about 5% coverage a halftone is
  sparse enough that its dots start to look like the dust the density test is
  there to remove.
* **Wholesale clipping.** A scan whose paper is clipped over a large area has
  had its noise cut off by the top of the scale, and no measurement can put
  that back. The selection stays honest on such scans rather than accurate.

## Running it on your own scans

```matlab
addpath tests
pqInspectScan('/path/to/scan.tif')            % one scan
pqInspectScan('/path/to/folder')              % every image in a folder
pqInspectScan('/path/to/folder','/tmp/out')   % also write what it chose
```

It prints contrast, noise, CNR and the old standard deviation for every
candidate, what each of the two selections picks, and whether they disagree.
No ground truth is needed - the numbers come from the scan itself. The cases
worth looking at first are the ones where the two disagree.

```matlab
pqCompareChannelSelection   % the table above, on synthetic scans
pqRunSelfTests              % awkward inputs, and timing
```

A 6 megapixel three channel scan is selected in about 4 seconds under Octave,
and a 1 megapixel one in about 1 second.
