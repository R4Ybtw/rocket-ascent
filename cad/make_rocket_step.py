"""Build the PR-1 rocket from data/rocket.json as a STEP file for Flow Simulation.

    pip install cadquery
    python make_rocket_step.py          (run from the cad/ folder)

Axis along +X, nose tip at the origin, base at x = total length.
The four fins sit at 45, 135, 225 and 315 degrees, so the planes y = 0 and
z = 0 pass BETWEEN them: both can be symmetry planes, and a quarter model
(y >= 0, z >= 0) holds exactly one fin.
Solid body (no motor tube or hollow interior); the base is flat, which is what
the coasting rocket looks like to the air.
"""
import json
import math
import cadquery as cq

with open("../data/rocket.json") as f:
    r = json.load(f)

mm = 1000.0
R = r["body_diameter"] / 2 * mm
Ln = r["nose_length"] * mm
Lt = (r["nose_length"] + r["body_length"]) * mm
cr, ct = r["fin_root_chord"] * mm, r["fin_tip_chord"] * mm
span, sweep, t = r["fin_span"] * mm, r["fin_sweep_length"] * mm, r["fin_thickness"] * mm

# Tangent ogive radius profile y(x), x from tip (0) to shoulder (Ln)
rho = (R**2 + Ln**2) / (2 * R)
n = 60
nose = [(Ln * i / n, math.sqrt(rho**2 - (Ln - Ln * i / n) ** 2) + R - rho) for i in range(n + 1)]
nose[0] = (0.0, 0.0)

outline = cq.Workplane("XY").moveTo(0, 0).spline(nose[1:], includeCurrent=True) \
    .lineTo(Lt, R).lineTo(Lt, 0).close()
body = outline.revolve(360, (0, 0, 0), (1, 0, 0))

x0 = Lt - cr                                  # fin root leading edge
r_in = R - 1.0                                # sink the root 1 mm into the body so the union is clean
fin_profile = [(x0, r_in), (x0 + sweep, R + span), (x0 + sweep + ct, R + span), (Lt, r_in)]
fin = cq.Workplane("XY").polyline(fin_profile).close().extrude(t / 2, both=True)

rocket = body
for k in range(r["fin_count"]):
    ang = r["fin_angle_offset_deg"] + 360.0 * k / r["fin_count"]
    rocket = rocket.union(fin.rotate((0, 0, 0), (1, 0, 0), ang))

solid = rocket.val()
bb = solid.BoundingBox()
cq.exporters.export(rocket, "pr1_rocket.step")
print(f"length {bb.xlen:.1f} mm, span across fins {bb.ylen:.1f} x {bb.zlen:.1f} mm, "
      f"volume {solid.Volume()/1e3:.1f} cm^3, valid={solid.isValid()}")
print(f"body diameter {2*R:.1f} mm, frontal (reference) area {math.pi*R**2:.1f} mm^2")
