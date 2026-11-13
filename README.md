# Model rocket ascent with CFD drag

How high does a small model rocket fly, and how much does the answer depend on the drag model? A point-mass flight model in MATLAB is run with three independent drag estimates: a component build-up, OpenRocket's own drag model, and CFD from SolidWorks Flow Simulation. OpenRocket's full simulation of the same flight serves as the cross-check.

*Work in progress: the flight model is complete and verified; OpenRocket and CFD results will be added as they are completed.*

## The rocket (PR-1)

| Part | Value |
|---|---|
| Nose | Tangent ogive, 170 mm |
| Body | 41.6 mm diameter, 650 mm long (820 mm overall) |
| Fins | 4 trapezoidal: root 100 mm, tip 50 mm, span 60 mm, sweep 50 mm, 3 mm thick |
| Mass without motor | 0.450 kg |
| Motor | AeroTech F40 (78.1 N·s, 2.06 s burn); AeroTech G80T and Estes D12 curves also included |
| Launch | 1.0 m rail, vertical, no wind |

All parameters live in `data/rocket.json`, which both the MATLAB code and the CAD script read.

## Approach

- **Flight model:** a point mass moving in a vertical plane. It is constrained to the launch rail, then flies at zero angle of attack, with thrust from the motor's certified thrust curve. Propellant mass falls in proportion to the impulse delivered, and the atmosphere is the International Standard Atmosphere.
- **Build-up drag:** turbulent skin friction on the body and fins, with a roughness limit; fin leading- and trailing-edge pressure drag; and base drag, which is reduced while the motor burns.
- **Comparison with OpenRocket in three runs:**
  - **A.** Build-up drag.
  - **B.** OpenRocket's own drag coefficients. This isolates the difference between the two flight models.
  - **C.** CFD drag coefficients. This shows what the CFD changes in the predicted apogee.
- **CFD:** Flow Simulation on a quarter model with two symmetry planes, at Mach 0.1–0.5, giving the drag coefficient as a function of Mach.

## Results so far (build-up drag)

| Quantity | Value |
|---|---|
| Apogee | 511 m at 10.0 s |
| Maximum speed | 109 m/s (Mach 0.32) |
| Maximum acceleration | 11 g |
| Speed leaving the 1 m rail | 13.9 m/s. That is below the common 15 m/s guideline for a stable departure; a 1.5 m rail gives 17.2 m/s |

| Input changed | Apogee sensitivity (% change in apogee per % change in input) |
|---|---|
| Thrust | +1.3 |
| Total mass | −0.9 |
| Drag coefficient | −0.37 |

The low drag sensitivity sets the bar for the CFD: a 10% error in drag moves the apogee only about 4%.

## Verification

`tests/test_rocket.m` switches physics off until an exact answer exists:

| Physics left on | Checked against |
|---|---|
| Atmosphere | Tabulated ISA values |
| Thrust only (no gravity, no drag) | The rocket equation, exact for any thrust curve |
| Gravity only | v²/2g |
| Gravity and quadratic drag | The closed-form logarithmic apogee |
| Full model | Agreement within 0.1 m between loose and tight integrator tolerances |

The OpenRocket file reader is also tested. All tests pass.

## Simulation setup (CFD)

| Item | Setting |
|---|---|
| Solver | SolidWorks Flow Simulation, 3D, external, steady |
| Model | Quarter model, with the fins at 45° so the symmetry planes pass between them. The quarter-model scaling is checked once against a full-model run |
| Conditions | ISA sea level, Mach 0.1–0.5, surface roughness 60 µm (matching OpenRocket's "regular paint") |
| Domain | One body length upstream, four downstream, 0.6 m to the side |
| Mesh | Base cells about 40 mm. The body region is refined to 5 mm, the rocket surface to 1.25 mm, and the fins to 0.6 mm, with a refined wake region. A three-level mesh study is run at Mach 0.3 |

The settings actually used for each run are recorded in `docs/run_log.md`.

## Repository layout

| Path | Contents |
|---|---|
| `data/rocket.json` | Rocket definition |
| `data/motors/` | RASP thrust curves and their source |
| `src/ascent.m` | Flight model |
| `src/drag_buildup.m` | Component drag build-up |
| `src/run_flight.m`, `src/sensitivity.m` | Nominal flight and sensitivity study |
| `src/compare_openrocket.m` | Runs A, B and C against OpenRocket |
| `src/cfd_plan.m`, `src/cd_from_cfd.m` | CFD run list, and conversion of CFD forces to Cd(Mach) |
| `tests/test_rocket.m` | Verification suite |
| `cad/` | Rocket geometry (STEP) and the script that builds it |
| `docs/run_log.md` | Run-by-run record of settings and results |

## Reproducing the analysis

```matlab
addpath tests; test_rocket        % verification
run('src/run_flight.m')           % nominal flight
run('src/sensitivity.m')          % which inputs matter
run('src/compare_openrocket.m')   % needs data/openrocket/PR1_F40.csv
```

The code runs in MATLAB and in GNU Octave.

## Limitations

- **Point-mass model:** no wind, weathercocking, stability or rotation. These need a six-degree-of-freedom model.
- **Drag build-up:** valid only below about Mach 0.8.
- **CFD:** steady, of a coasting solid body, so it doesn't capture the exhaust plume filling the base during the burn.
- **No flight test:** the predictions are compared with OpenRocket, not with a measured flight.

## References

- S. Niskanen, *OpenRocket technical documentation* (2013).
- S. F. Hoerner, *Fluid-Dynamic Drag* (1965).
- ISO 2533:1975, *Standard Atmosphere*.
- Motor thrust curves: NAR certification data via ThrustCurve.org, as bundled with OpenRocket (`data/motors/SOURCE.md`).

## Licence

Code: MIT (see `LICENSE`). Text and figures: CC BY 4.0. The thrust curves in `data/motors/` are not covered by either licence: they come from the motor file bundled with OpenRocket (GPL-3.0), compiled on ThrustCurve.org from NAR certification data. See `data/motors/SOURCE.md`.

MATLAB, OpenRocket and SolidWorks Flow Simulation. The code was first drafted with an AI assistant, then read, modified and run by me. The simulations and conclusions are my own.
