# Measuring the separation between two printheads

Five Xaar GS3-2000 heads print at 720 x 720 dpi, three in a back row and two
in front of them, and where two swathes meet the heads have to be aligned to
a few microns across the web. One pixel at 720 dpi is 35.2778 um, so a few
microns is a few hundredths of a pixel, and the chart has to be built so that
a few hundredths of a pixel is a thing that can be measured.

This note says what the chart is, why each part of it is there, what the
measurement cannot do however carefully it is made, and what has to be printed
on the real machine before anybody believes a number from it.

## What it measures, and the sign

`measureHeadSeparation` returns the cross web displacement of head B relative
to head A in microns, signed. Positive means head B's print sits to the right
of head A's.

Nothing in this code takes an absolute value, folds a result onto a pattern
pitch, or turns a result round. A negative answer is a negative answer. The
old periodic line pattern had a repeating pitch of about 141 um, which gave
the analyser somewhere to fold a result to, and an overlap that should have
read negative could come back positive and plausible. There is no pitch here
to fold onto: the pattern that measures the displacement is one mark per head
per group, and the answer is a difference of two positions, not a phase.

Down web displacement comes back as well, in `downWebMicrons`. It is not what
the chart is for and it is not checked as hard.

## The pattern

`pqSplitXPattern` builds one band per head to head join. A band is three
columns of blocks and an ink witness underneath them.

### The mark

The mark is an X with a hole in the middle: two diagonal arms at 45 degrees
that would cross at a virtual centre, printed on both sides of that centre and
not at it. The analyser finds the centre of the ink in every row of each arm,
fits a straight line through those centres, and crosses the two lines.

Three things about that are deliberate.

**The arms are fitted over many rows, so the centre is found far more
precisely than any one row could find it.** Each arm uses 64 nozzle columns,
so a row centre good to a tenth of a pixel gives an arm good to about a
hundredth.

**The hole is in the middle, so the centre is interpolated and not
extrapolated.** This is the single change that most improved the measurement.
A line fitted to n rows locates a point at the middle of them to
`scatter/sqrt(n)`, and a point a lever arm `d` away to
`scatter * sqrt(1/n + d^2/Syy)`. With arms that stop short of the centre, as
the earlier versions of this pattern had them, `d` is about 50 rows and the
second term dominates: the factor is 0.50 instead of 0.125, four times worse,
and that extrapolation was the largest single error in the whole measurement.
Printing the arms on both sides of the centre instead, with a blank hole
between them, makes `d` zero by symmetry. Measured repeatability went from
1.23 um to 0.35 um on the same scans.

**The arms never touch anything.** The two arms of a mark stop short of each
other, and the two heads print different marks in different rows, so no
displacement of either head can make their ink collide. The old pattern could
collide at large negative displacements, and a pattern whose ink merges stops
being measurable exactly when the fault it is measuring is worst.

### The group

A group is three marks in a column, **A B A**: the head under test in the
middle and the reference head above and below it. The separation is

    separation = (centre x of B - mean of the two A centres) * 35.2778 um

Taking the mean of the outer two puts the reference at the same height down
the band as the mark between them. Anything that slides the scan sideways in
proportion to how far down it is - a sheet fed in skew, a tilted scanner, a
bowed web - then moves the reference and the mark under test by the same
amount and cancels. A scan rotated by 5 mrad changes the answer by less than
0.1 um.

Groups alternate A B A and B A B so that over a band each head prints as many
outer marks as middle ones, and the two heads print exactly the same ink in
exactly the same columns. That congruence is what makes blur and symmetric dot
gain cancel: they move both heads' centres the same way, and the measurement
is a difference.

### The control blocks

To the left and the right of the measurement blocks are two more, printed
entirely by one head. Their true separation is zero by construction, so what
they read is the scan's own distortion - lens, web, camera - and not a head
displacement. It is subtracted, and it is also checked: a control reading more
than 10 um means something is bending the scan and the answer is refused.

A control cannot catch everything, and it is worth being clear about what it
is blind to. Both of its marks are the same head, so anything that moves all
of that head's ink moves both and cancels there. That is precisely the ink
growth problem below, and it is why the controls read clean on exactly the
scans where the measurement is most at risk.

### The two arm widths

Groups use arm runs of 3 pixels and of 7 pixels, in the order narrow, wide,
wide, narrow so that the two sets sit at the same average height in the band.
If the two sets disagree by more than the measurement can resolve, the band is
refused with `featureDependence`. Why that matters is the next section.

### The ink witness

Under the blocks, each head prints a solid reference patch, then ink lines and
paper gaps of both arm widths, three of each, spread right across the band so
that a run of dead adjacent nozzles can reach at most one of them.

If a head's ink spreads `gLeft` past every left hand edge and `gRight` past
every right hand one, then a nominal `w` wide ink line comes back `w+gLeft+
gRight` wide and a nominal `w` wide paper gap comes back `w-gLeft-gRight`
wide. Half their difference is the total growth, and it needs neither the
nominal width nor a threshold:

    growth = (line width - gap width) / 2 = gLeft + gRight

Widths are measured as the ink's integral divided by the solid ink amplitude,
which is the width the ink would have if its edges were hard. Blur does not
change it, because blur moves ink about without adding any. On synthetic scans
the witness reads an injected growth of 0.8, 1.6 and 2.4 pixels as 0.804,
1.596 and 2.405.

A nozzle that fails takes ink away and never adds any, so damage makes a line
narrower and a gap wider, and both make the growth look smaller than it is.
The widest line and the narrowest gap are therefore the least damaged pair
there is, and that is the pair the growth is taken from.

## The one thing no pattern of this kind can do

Every pattern tried against this problem - ABA bars, MultiMark, Split-X,
balanced overlap - was fooled by one sided dot growth, and it is worth saying
exactly why, because the answer is not that they were badly designed.

Growing a head's ink by `gLeft` to the left and `gRight` to the right is the
same operation as **moving it sideways by `(gRight-gLeft)/2` and then growing
it evenly by `(gLeft+gRight)/2`**. That is not an approximation; dilating a
set by the segment `[-gLeft, +gRight]` is exactly a translation followed by a
symmetric dilation. The even part leaves every centre, every centroid and
every fitted intersection where it was. The sideways part moves all of that
head's ink.

A head that has moved also moves all of its ink. The two are the same picture.
No measurement of a printed image can separate them, because there is nothing
in the image to separate.

So the honest reckoning is:

* **What the chart measures is where the ink lands.** That is the quantity
  that decides whether the print has a visible stitch, so measuring it is not
  a consolation prize. A head whose ink lands 13 um to the right is 13 um
  misaligned as far as the printed sheet is concerned, and should be adjusted.
* **It is not a measurement of where the mechanical head is.** If the two have
  parted company, this chart reports the ink and says nothing about the metal.
  Only an independent mechanical reference can tell you about the metal.
* **The number stops being useful when the ink lands differently on different
  features**, because then there is no single displacement to report: the
  chart's thin lines would be telling you about the chart's thin lines.

The last of those is the one that can be caught, and it is what the two arm
widths are for. Ink that grows by the same amount on a 3 pixel feature and a 7
pixel one shifts every feature equally; both sets of groups read the same, and
the answer carries over to a printed image. Ink whose growth depends on the
feature shifts the two sets by different amounts, and the band is refused. On
synthetic scans, growth that varies with feature width makes the two sets
disagree by 36 um and is refused every time.

The witness adds a second, weaker guard. A head laying more ink than its
neighbour might be doing it evenly, which costs nothing, or all to one side,
which costs half the difference, and nothing in the image says which. So

    possible bias = |growth of B - growth of A| / 2

is reported as `inkBiasBoundMicrons`, added to the uncertainty, and refused
when it exceeds the accuracy the measurement is wanted to. That is a refusal
to certify, not a claim that the answer is wrong: in the synthetic case where
head B lays 0.8 pixels more ink than head A, evenly, the answer is right to
0.4 um and is refused anyway, because from the scan alone it could have been
14 um out. The cure is a process cure - match the ink laydown of the two heads
and print it again - and the default tolerance of 4 um should be set from
measured machine data rather than left where it is.

`inkBiasEstimateMicrons` carries the same size with a sign, from how lopsided
the ink profiles are. It is reported and **never subtracted**. Subtracting it
would be assuming the answer to the question the measurement cannot answer.

## What the analyser does

`measureHeadSeparation(scan,pattern)` sends the scan to `pqAnalyseSplitX` or
`pqAnalyseMultiMark`. Either way it is given the scan and the nominal
geometry, and nothing else: not the displacement, not which nozzles were
firing, not where the scanner put the sheet.

1. `pqPrepareScan` picks the channel and the polarity, through `selectChannel`
   on a colour scan, which refuses a scan whose print does not stand clear of
   its own noise.
2. `pqRegisterPattern` finds the whole pixel position of the band by
   correlating the row and column ink profiles with the nominal ones. Only the
   whole pixel part - the fraction is the measurement.
3. `pqInkGain` reads the witness: the solid amplitude of each head, and its
   growth at each feature width.
4. `pqArmCentres` measures every row of every arm. For each row it takes a
   window, fits a straight background to the pixels at both ends of it, and
   takes the centroid of what stands above that background.
5. `pqRobustLineFit` fits each arm, keeping the rows it rejected and why.
6. The arm lines are crossed, the groups are differenced, the controls are
   subtracted, and the result comes back with an uncertainty and a verdict.

Three details in step 4 are each worth more than they look.

**The background is removed as a sloping line, not as a level.** Scanner
illumination and paper shade drift across a band, and a slope under a feature
is not a harmless offset: it multiplies the squared distance from the centre
when the centroid is formed and pulls the measured centre downhill. Removing
the slope took the scatter from 1.8 um to 0.27 um.

**The ink is integrated over a narrow window whose width is set from how far
the ink actually spreads on that scan.** The far pixels of a wide window hold
no feature and all of the noise. A window that is too narrow is worse than
wasteful: it cuts the blur off, and it cuts more off one side than the other
whenever the ink does not sit squarely on a pixel, which is a bias, and a
different bias for the head that has moved than for the one that has not. A
fixed window cost 1.3 um on a heavily blurred scan; a window set from the
measured spread costs 0.3 um.

**Where the window goes is decided once per arm, not row by row.** A window
sits on whole pixels, so placing it means rounding, and rounding is a step: a
row whose ink sits near half way between two pixels has its window thrown from
one pixel to the next by noise, and which way it goes depends on the noise.
Measuring from wherever it lands leans the answer, by an amount that grows
with the noise and vanishes when the ink sits squarely on a pixel - so the two
heads of a band, sitting at different fractions of a pixel, lean by different
amounts and the leaning does not cancel. This was worth up to 3 um on a noisy
scan and it was invisible on a clean one. Deciding the window once per arm,
from the middle of fifty rows, takes the noise on that decision down by the
root of fifty.

### Why a scan is refused

| reason | what it means |
|---|---|
| `routingNotVerified` | nobody has confirmed which physical head prints which half of the band |
| `scanRefused` | no channel of the scan lifts the print clear of its noise |
| `notRegistered` | the band is not in this scan |
| `missingHead` | one head printed nothing, or far less than the other |
| `fewGroups`, `groupLost` | too few measurement groups could be read |
| `groupSpread` | the groups disagree by more than 3 um, so the band is not measuring one number |
| `controlOffset` | the same head controls read more than 10 um, so the scan is distorted |
| `headTilt` | the two heads' arms differ in slope, so one head is rotated |
| `outOfRange` | the ink has moved further than the measuring windows reach |
| `witnessUnreliable`, `witnessDisagrees` | the ink witness could not be read, or does not agree with the arms |
| `inkAsymmetry` | the two heads' ink growth differs enough to be worth more than the tolerance |
| `featureDependence` | the two arm widths disagree, so the ink does not land in one place |

A refusal is not a printer fault. It means the scan cannot answer the
question, and adjusting a head from a number that came with reasons attached
is how a machine ends up further out than it started.

## The cross check

`pqMultiMarkPattern` measures the same thing from plain rectangles. It is in
the chart because it shares no line fitting, no diagonal extraction and no
virtual centre with Split-X, so it does not share those ways of being wrong,
and because it can do one thing Split-X cannot.

Each measurement row holds three A to B baselines of very different nominal
lengths, all centred on the same place. A scanner whose x scale is out by a
fraction `e` stretches a baseline of nominal length `d` by `e*d`, so

    measured(d) - d = displacement + e*d

and a straight line through the three baselines separates them: the intercept
is the displacement, at zero baseline, where a scale error does nothing, and
the slope is the scale error. A control row of same head pairs measures the
same scale error with no displacement in it at all. On a synthetic scan with a
scanner scale error of 2.0e-4 injected, the baselines give 2.01e-4 and the
controls 1.95e-4, and the reported displacement does not move.

Split-X does not need this, because its two marks are at the same nominal
cross web position and a scale error has nothing to act on. MultiMark earns
its place by being able to tell you that the scanner is the problem.

## What it measures on synthetic scans

`tests/pqHeadSeparationBenchmark` prints, scans and measures bands whose true
displacement, nozzle failures, ink growth and scanner errors it made up, and
scores what came back. The analyser is given the scan and the nominal geometry
and nothing else. Refused scans stay in the denominator, accepted outliers are
not removed, and no threshold was changed after seeing a score.

Clean scans, 11 displacements from -250 to +250 um, three scanner sampling
phases each, in microns:

| pattern | bias | MAE | 95th | max | repeatability | valid |
|---|---:|---:|---:|---:|---:|---:|
| Split-X v3 | -0.15 | 0.24 | 0.66 | 0.74 | 0.33 | 100% |
| MultiMark | -0.03 | 0.20 | 0.37 | 0.39 | 0.26 | 100% |

The bias is signed and quoted separately so that a sign error cannot hide
inside a mean absolute error. Repeatability is the pooled standard deviation
of the repeats at one displacement.

Twenty one stress conditions, three repeats each, all at a true head
displacement of +50 um. Every result is scored twice: against the head, which
is where the printhead really is, and against the ink, which is where head B's
ink really landed once its dot growth is accounted for. The two differ only
under one sided growth, for the reason given above.

| | Split-X v3 | MultiMark |
|---|---:|---:|
| correct, against the ink | 42 | 46 |
| accepted but wrong, against the ink | **0** | **0** |
| refused | 21 | 17 |
| total | 63 | 63 |
| accepted, but more than 4 um from the head | 9 | 9 |

The nine in the last row are the three one sided growth conditions. In each
one the band reports where the ink is, to better than 0.1 um, and the ink is
not where the head is. That is the identifiability limit, not an error, and it
is reported rather than hidden.

What each condition does:

| condition | Split-X | MultiMark |
|---|---|---|
| one dead edge nozzle | 0.07 um, accepted | 0.05 um, accepted |
| eight dead adjacent nozzles | 0.07 um, accepted | 0.05 um, accepted |
| a tenth of head B's nozzles dead | refused, `witnessUnreliable` | 0.05 um, accepted |
| head B missing | refused, `missingHead` | refused, `missingHead` |
| symmetric dot gain on both heads | 0.06 um, accepted | 0.05 um, accepted |
| extra symmetric gain on head B | refused, `inkAsymmetry` | refused, `inkAsymmetry` |
| one sided growth, +0.75, +0.4, -0.75 px | within 0.08 um of the ink | within 0.09 um of the ink |
| growth that depends on feature width | refused, `featureDependence` | refused, `inkAsymmetry` |
| head B rotated 2 mrad | refused, `groupSpread` | refused, `rowSpread` |
| scanner rotated 5 mrad | 0.20 um, accepted | 0.04 um, accepted |
| scanner x scale 2e-4 | 0.05 um, accepted | 0.04 um, accepted |
| quadratic web distortion | 0.17 um, accepted | 0.13 um, accepted |
| down web displacement of head B | 0.20 um, accepted | 0.05 um, accepted |
| heavy optical blur | 0.10 um, accepted | 0.24 um, accepted |
| noisy scan | 0.04 um, accepted | 0.25 um, accepted |
| faint print | 0.08 um, accepted | 0.19 um, accepted |
| illumination shading | refused | mostly refused |
| combined stress | refused, `inkAsymmetry` | refused, `inkAsymmetry` |

Three of those are worth reading twice.

**A tenth of head B's nozzles dead is refused by Split-X and measured by
MultiMark.** A three pixel arm run covers about five columns, so with a tenth
of the nozzles dead two rows in five have lost something, and the witness
features, being three pixels wide themselves, are damaged often enough that
the growth cannot be trusted. The separation it reports is still right to 0.3
um - it is the witness that fails, not the measurement - but a band that
cannot read its own ink witness has no business certifying itself. MultiMark's
marks are seven pixels wide and survive. This is the clearest case for keeping
both bands.

**Illumination shading refuses on Split-X.** Shading costs the thin diagonal
arms about 6 um of scatter and the controls see it, so the band is refused
with `controlOffset` and `groupSpread` rather than reported. MultiMark
survives it two times in three.

**The combined stress case is refused for unequal ink laydown**, not for any
of the three faults deliberately put into it. Head A was given more dot gain
than head B, and from the scan alone that extra ink could have gone on one
side. The answer it refused to certify was right to 0.6 um. That is the cost
of the bound, and it is the number the ink laydown trials below are meant to
settle.

## What it still cannot do

* **Tell ink that has moved from a head that has moved.** The section above.
* **Survive heavy illumination shading.** Shading of about 6% of contrast,
  varying over a couple of millimetres, costs Split-X about 6 um of scatter -
  far more than it costs MultiMark, whose marks are wider. The local sloping
  background removes the gradient but not the curvature. Most of these scans
  are refused by `groupSpread` rather than reported, but the honest answer is
  to flat field the scanner. The same limitation is noted for the channel
  selection in [channel-selection.md](channel-selection.md).
* **Measure a head that is more than about 390 um out.** The measuring windows
  reach about 11 pixels. Beyond that the band reports `outOfRange` rather than
  a wrong number, and the geometry has to be opened up with
  `options.halfWindow` and `halfGap`.
* **Know which physical head printed what.** It cannot, and it does not
  pretend to - see below.

## Which head printed it

A band's geometry says that some ink belongs to the head printing the middle
marks and some to the heads printing the outer ones. It does not say which
physical head that is, and no analysis of the printed sheet can recover it.
Get it the wrong way round and the chart looks right, analyses cleanly, and
reports the displacement with the sign reversed, or measures a head against
itself and reports zero. Nothing downstream can catch that.

So it is not assumed. `pqHeadJoins` writes down the believed layout - the five
head stagger, 1-3-5 in the back row and 2-4 in front, printing towards 2-4 -
with `routingVerified` false on every join, and nothing in this code can set
it true. The code that composes the chart and routes nozzles to heads has to
set it, after checking which physical head prints each column of the shared
region. Until it does:

* `pqHeadSeparationBitmap` refuses to write a production bitmap;
* every measurement comes back invalid with `routingNotVerified`.

`chart.headOfRect` carries a physical head number for every rectangle in the
chart, and `pqHeadSeparationBitmap` returns one bitmap per head, because a
chart that is right as one image and wrong as two measures the wrong thing.

## Before this replaces the production chart

None of the numbers in this note are measurements of a printer. They are
measurements of an analyser, taken on scans whose truth a simulator made up.
They say the analysis is not the limiting thing. They say nothing about
whether the printed chart behaves like the simulated one.

Print, on the real machine, at known mechanical offsets, both bands, for every
join:

| condition | what it is for |
|---|---|
| -50, 0, +50 um set mechanically | bias and gain against a known input |
| two clockwise adjustments, if one adjustment is known to be 25 um | that the scale is right over a range |
| one edge nozzle deliberately disabled | that a dead edge nozzle does not move the answer |
| several adjacent nozzles disabled | the same, for a run of them |
| two or three ink laydowns | this is what moves `inkBiasBoundMicrons`, and what sets its tolerance |
| left and right scans of the same sheet | scanner asymmetry |
| the sheet in several positions on the scanner | lens and illumination across the bed |
| ten repeats with no adjustment at all | repeatability, which is the only number that needs no reference |

For every condition report, for Split-X and for MultiMark separately:

* signed bias;
* mean absolute error;
* repeatability, as the standard deviation of the repeats;
* maximum absolute error;
* the proportion of scans that gave a valid result;
* the proportion refused, and the reasons;
* the proportion accepted whose error exceeded 4 um - the false valid rate,
  which is the one that matters, because a refusal costs a reprint and a false
  valid costs a misaligned machine;
* the agreement between the two bands on the same sheet.

Two of those conditions are doing more than checking a box.

**The ink laydown series sets the `inkAsymmetry` tolerance.** The default of 4
um is a guess. Printing the same offset at several laydowns measures how much
the heads' growth really differs in normal running, and how much the answer
moves when it does. If the answer does not move when the growth differs, the
bound is too conservative and the tolerance should be opened; if it moves by
half the growth difference, the bound is right and tight.

**The repeats with no adjustment are the only honest accuracy figure you can
get without a reference.** Everything else is measured against the machine's
own adjusters, which have their own error.

Do not claim plus or minus 2 to 4 um until it has been shown against an
independent physical reference - a measuring microscope or a calibrated stage
on the printed sheet, not the machine's own adjustment scale. And do not tune
a threshold in this code after seeing how it scored. If a threshold is wrong,
it is wrong for a reason that can be written down.

## Running it

```matlab
runHeadSeparation('demo')                 % print, scan and measure, no hardware
runHeadSeparation('bitmap','/tmp/chart')  % the chart, one bitmap per head
runHeadSeparation('measure','/tmp/scans') % every scan in a folder

addpath tests
pqRunHeadSeparationSelfTests              % the checks that have to hold
pqHeadSeparationBenchmark                 % the tables below
```

When a band is refused and the reason needs looking at:

```matlab
pattern = pqSplitXPattern(join);
result = measureHeadSeparation(scan,pattern);
pqPlotHeadSeparation(scan,pattern,result)   % nothing else opens a figure
```

It draws the nominal position of each arm, the centre found in each row, the
rows that were thrown away, the fitted lines, the virtual centres, and the ink
witness profiles. Nothing in the analysis calls it: an analyser that opens
windows on a production line is a nuisance at best.

Working out what to draw is `pqHeadSeparationOverlay`, which is separate and
is covered by the self tests. Drawing needs a screen; reading the result is
where the mistakes are, and that part runs anywhere. The drawing itself has
not been run here - the container these were developed in has no working text
renderer for Octave figures - so `pqPlotHeadSeparation` is the one file in
this set that has been read rather than executed.
