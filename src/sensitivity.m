%% sensitivity.m — which input does the apogee actually depend on?
%
% Perturb one input at a time and report the normalised sensitivity
%   S = (% change in apogee) / (% change in input).
% S = -0.5 means a 10% error in that input moves the apogee 5% the other way.
% Use it to decide where accuracy matters: if drag has |S| ~ 0.4 and you know
% Cd to +-15%, that alone is a +-6% apogee uncertainty, so the CFD effort is
% justified only if it beats +-15%.

clear; clc;
here = fileparts(mfilename('fullpath')); addpath(here);
root = fullfile(here, '..');
r = load_rocket();
m = read_eng(fullfile(root, 'data', 'motors', r.motor_file));
base = ascent(r, m);
fprintf('Baseline apogee %.1f m (%s)\n\n', base.apogee, m.name);

cases = { 'Drag coefficient +10%', struct('cd_scale', 1.10),     10;
          'Drag coefficient -10%', struct('cd_scale', 0.90),    -10;
          'Total mass +10%',       struct('mass_scale', 1.10),   10;
          'Total mass -10%',       struct('mass_scale', 0.90),  -10;
          'Thrust +5%',            struct('thrust_scale', 1.05),  5;
          'Thrust -5%',            struct('thrust_scale', 0.95), -5 };
fprintf('%-24s %10s %10s %12s\n', 'Change', 'apogee', 'change', 'sensitivity');
for k = 1:size(cases, 1)
    S = ascent(r, m, cases{k,2});
    d = 100*(S.apogee - base.apogee)/base.apogee;
    fprintf('%-24s %10.1f %+9.2f%% %12.2f\n', cases{k,1}, S.apogee, d, d/cases{k,3});
end

% Launch conditions (not percentages)
S = ascent(r, m, struct('launch_angle', 5));
fprintf('%-24s %10.1f %+9.2f%%\n', 'Rail tilted 5 deg', S.apogee, 100*(S.apogee - base.apogee)/base.apogee);
S = ascent(r, m, struct('rail', 1.5));
fprintf('%-24s %10.1f   rail-exit speed %.1f -> %.1f m/s\n', '1.5 m rail', S.apogee, base.v_rail, S.v_rail);
