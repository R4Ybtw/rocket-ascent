# Motor thrust curves

RASP `.eng` files taken unmodified from OpenRocket's bundled motor file (`core/src/main/resources/datafiles/thrustcurves/RASAero/rasp.eng`, github.com/openrocket/openrocket; OpenRocket is distributed under GPL-3.0). That file collects curves submitted to ThrustCurve.org. Each file's comment header names its original source: NAR certification data, or the manufacturer for the G80T.

Because OpenRocket uses the same curves, comparing against OpenRocket isolates the flight model, not the motor data.

For other motors, download `.eng` files from thrustcurve.org.

Header line format: `name  diameter[mm]  length[mm]  delays  propellant_mass[kg]  total_mass[kg]  maker`, followed by `time[s] thrust[N]` pairs ending at zero thrust.
