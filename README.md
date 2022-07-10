# PkgSwaps.jl

``PkgSwaps`` makes recommendations for switching out Julia packages you are using for 'superior' packages, where 'superior' is defined as other packages in the Julia package registry having made the same swap. For example, if package ``A`` depends on package ``B`` and then in a subsequent version drops package ``B`` and adds package ``C``, ``PkgSwaps`` records this as a choice for ``C`` over ``B``. If your environment currently has package ``B``, ``PkgSwaps`` will then suggest you consider using package ``C`` in place of package ``B``.

``PkgSwaps`` assumes that the ``General`` package registry accurately reflects the decisions of engaged package maintainers in their aim of developing the best packages possible. ``PkgSwaps`` takes advantage of these publicly available decisions in order to nudge use of 'Pareto optimal' dependency sets.

```julia
using PkgSwaps

PkgSwaps.recommend()
```
