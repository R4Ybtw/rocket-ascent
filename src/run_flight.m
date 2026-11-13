%% run_flight.m — simulate the rocket in data/rocket.json and report the flight
%
% Change the rocket or motor in data/rocket.json, not here.

clear; clc;
here = fileparts(mfilename('fullpath')); addpath(here);
root = fullfile(here, '..');
r = load_rocket();
m = read_eng(fullfile(root, 'data', 'motors', r.motor_file));

fprintf('%s with %s %s (%s class, %.1f N s, %.2f s burn, %.1f N average)\n', ...
        r.name, m.maker, m.name, m.class, m.I_total, m.t_burn, m.F_avg);
fprintf('Lift-off mass %.3f kg, thrust-to-weight (average) %.1f\n', ...
        r.dry_mass + m.total_mass, m.F_avg/((r.dry_mass + m.total_mass)*9.80665));

S = ascent(r, m);
fprintf('\n  Apogee                %7.1f m above the pad at %.2f s\n', S.apogee, S.t_apogee);
fprintf('  Max speed             %7.1f m/s (Mach %.3f)\n', S.v_max, S.M_max);
fprintf('  Max acceleration      %7.1f m/s^2 (%.1f g)\n', S.a_max, S.a_max/9.80665);
fprintf('  Speed at burnout      %7.1f m/s at %.2f s\n', S.v_burnout, S.t_burnout);
fprintf('  Speed leaving the rail %6.1f m/s on a %.1f m rail', S.v_rail, r.launch_rail_length);
if S.v_rail < 15
    fprintf('  (below the common 15 m/s guideline for stable flight)\n');
else
    fprintf('\n');
end

figure('Position', [100 100 900 600]);
subplot(2,2,1); plot(S.t, S.z); grid on; xlabel('t [s]'); ylabel('altitude [m]'); title('Altitude');
subplot(2,2,2); plot(S.t, S.V); grid on; xlabel('t [s]'); ylabel('speed [m/s]'); title('Speed');
subplot(2,2,3); plot(S.t, S.acc/9.80665); grid on; xlabel('t [s]'); ylabel('[g]'); title('Acceleration');
subplot(2,2,4); plot(S.Mach, S.Cd, '.'); grid on; xlabel('Mach'); ylabel('C_D'); title('Drag coefficient used');

out = fullfile(root, 'data', 'results', sprintf('flight_%s.csv', m.name));
fid = fopen(out, 'w');
fprintf(fid, 't,altitude,speed,vz,mach,cd,thrust,mass\n');
fprintf(fid, '%.4f,%.3f,%.3f,%.3f,%.4f,%.4f,%.3f,%.5f\n', [S.t S.z S.V S.vz S.Mach S.Cd S.T S.m]');
fclose(fid);
fprintf('\nTime history written to %s\n', out);
