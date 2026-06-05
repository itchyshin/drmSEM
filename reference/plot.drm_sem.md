# Plot the distributional SEM as a component-labelled DAG

Nodes are variables; arrows are coloured and styled by the
distributional component they target (mu solid black, sigma dashed
green, zi dotted orange, random-effect scale grey dotted, rho12
long-dash). Uses `igraph` for layout.

## Usage

``` r
# S3 method for class 'drm_sem'
plot(x, ...)
```

## Arguments

- x:

  A `drm_sem` object.

- ...:

  Passed to the underlying plot.

## Value

`x`, invisibly.
