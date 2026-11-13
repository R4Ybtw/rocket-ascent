%% test_rocket.m — verify the flight model against cases with exact answers
%
% Run from the project folder:   addpath tests; test_rocket
% Each test switches physics off until an exact answer exists, so a failure
% points at one piece of the model.

function test_rocket()
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'src'));
root = fullfile(here, '..');
ok = true;
r  = load_rocket();

%% 1. Standard atmosphere against tabulated ISA values
[T, p, rho] = isa_atmos([0 1000 5000 11000]);
ok = chk('ISA T at 5 km [K]',          T(3),   255.65, 1e-6) && ok;
ok = chk('ISA p at 1 km [Pa]',         p(2),   89874.6, 1e-4) && ok;
ok = chk('ISA rho at 11 km [kg/m3]',   rho(4), 0.36392, 1e-3) && ok;

%% 2. Motor file
m = read_eng(fullfile(root, 'data', 'motors', 'AeroTech_F40.eng'));
ok = chk('F40 is an F motor (40-80 N s)', double(m.class), double('F'), 0) && ok;
ok = chk('F40 average thrust ~ 40 N (it is in the name)', m.F_avg, 40, 0.08) && ok;

%% 3. Rocket equation: no gravity, no drag
%  Mass burns in proportion to impulse, so the exhaust speed is constant,
%  ve = I_total / m_prop, and dv = ve ln(m0/mf) exactly, whatever the thrust curve.
o = struct('g', 0, 'drag', 'constant', 'cd_const', 0, 'rail', 0);
S = ascent(r, m, setfield(o, 'MaxStep', 0.01));
m0 = r.dry_mass + m.total_mass; mf = m0 - m.prop_mass;
dv = m.I_total/m.prop_mass*log(m0/mf);
ok = chk('Rocket equation: burnout speed', S.v_burnout, dv, 1e-4) && ok;

%% 4. Vacuum coast: h = v0^2 / 2g
o = struct('drag', 'constant', 'cd_const', 0, 'rail', 0, 'v0', 50, 'const_rho', true);
S = ascent(r, [], o);
ok = chk('Vacuum coast apogee', S.apogee, 50^2/(2*9.80665), 1e-6) && ok;

%% 5. Coast with quadratic drag, constant density:
%  h = m/(2k) ln(1 + k v0^2/(m g)),  k = 0.5 rho Cd A
o.cd_const = 0.6;
S = ascent(r, [], o);
[~, ~, rho0] = isa_atmos(r.launch_altitude);
k = 0.5*rho0*0.6*r.A_ref; mm = r.dry_mass; g = 9.80665;
ok = chk('Quadratic-drag coast apogee', S.apogee, mm/(2*k)*log(1 + k*50^2/(mm*g)), 1e-6) && ok;

%% 6. Integrator: answer must not depend on the tolerances
S1 = ascent(r, m, struct('RelTol', 1e-6, 'AbsTol', 1e-6, 'MaxStep', 0.05));
S2 = ascent(r, m, struct('RelTol', 1e-10, 'AbsTol', 1e-10, 'MaxStep', 0.01));
fprintf('   apogee %.3f m (loose) vs %.3f m (tight)\n', S1.apogee, S2.apogee);
ok = chk('Apogee converged in tolerance (< 0.1 m)', abs(S1.apogee - S2.apogee) + 1, 1, 1e-1) && ok;

%% 7. Drag build-up stays in a sane range for this rocket
Cd = drag_buildup(r, 60, 10);
ok = chk('Build-up Cd in 0.3-1.0 (sanity)', double(Cd > 0.3 && Cd < 1.0), 1, 0) && ok;

%% 8. OpenRocket CSV reader on a file in OpenRocket's export format
f = [tempname '.csv'];
fid = fopen(f, 'w');
fprintf(fid, '# PR-1 (Simulation 1)\n# 30 data points written for 6 variables.\n#\n');
fprintf(fid, '# Time (s),Altitude (ft),Vertical velocity (m/s),Total velocity (m/s),Mach number (),Drag coefficient ()\n');
fprintf(fid, '# Event LAUNCH occurred at t=0 seconds\n');
fprintf(fid, '0,0,0,0,0,0.7\n1,328.084,50,50,0.15,0.75\n');
fclose(fid);
R = read_openrocket_csv(f); delete(f);
ok = chk('OpenRocket reader: ft -> m', R.altitude(2), 100.0, 1e-5) && ok;
ok = chk('OpenRocket reader: Cd column', R.cd(2), 0.75, 1e-12) && ok;

if ok, fprintf('\nALL TESTS PASS\n'); else, fprintf('\nSOME TESTS FAILED\n'); end
end

function ok = chk(name, got, want, reltol)
    if want == 0, e = abs(got); else, e = abs(got - want)/abs(want); end
    ok = e <= reltol;
    s = 'FAIL'; if ok, s = 'PASS'; end
    fprintf('%-48s got %12.6g  want %12.6g  -> %s\n', name, got, want, s);
end
