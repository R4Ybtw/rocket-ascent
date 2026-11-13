%% compare_openrocket.m — separate "flight model" differences from "drag model" differences
%
% Three MATLAB runs against one OpenRocket run of the same rocket and motor:
%   A. MATLAB, build-up drag                 differs from OpenRocket in drag AND flight model
%   B. MATLAB, OpenRocket's own Cd vs Mach   same drag -> remaining gap is the flight model
%   C. MATLAB, CFD Cd vs Mach (if available) what the CFD drag does to the apogee
% If B matches OpenRocket closely, the integrators agree and every other
% difference is about drag, which is the point of the CFD work.
%
% Needs: data/openrocket/PR1_<motor>.csv, OpenRocket's export of the same flight
% Optional: data/results/cd_cfd.csv (Mach,Cd) from cd_from_cfd.m

clear; clc;
here = fileparts(mfilename('fullpath')); addpath(here);
root = fullfile(here, '..');
r = load_rocket();
m = read_eng(fullfile(root, 'data', 'motors', r.motor_file));
orf = fullfile(root, 'data', 'openrocket', sprintf('PR1_%s.csv', m.name));   % OpenRocket export
OR = read_openrocket_csv(orf);

% OpenRocket's drag coefficient as a function of Mach, power off and power on
need = {'time', 'altitude', 'velocity', 'mach', 'cd', 'thrust'};
for k = 1:numel(need)
    if ~isfield(OR, need{k}), error('OpenRocket export is missing "%s" — tick it when exporting.', need{k}); end
end
up = [true; diff(OR.altitude) > 0] & OR.mach > 0.02 & ~isnan(OR.cd);   % ascent only
off = up & OR.thrust <= 0; on = up & OR.thrust > 0;
tab_off = mach_table(OR.mach(off), OR.cd(off));
tab_on  = mach_table(OR.mach(on),  OR.cd(on));

SA = ascent(r, m);
SB = ascent(r, m, struct('drag', 'table', 'cd_table', tab_off, 'cd_table_on', tab_on));
runs = {SA, 'MATLAB, build-up drag'; SB, 'MATLAB, OpenRocket C_D'};
cf = fullfile(root, 'data', 'results', 'cd_cfd.csv');
if exist(cf, 'file')
    T = dlmread(cf, ',', 1, 0);
    SC = ascent(r, m, struct('drag', 'table', 'cd_table', T(:,1:2), 'cd_table_on', []));
    runs(end+1, :) = {SC, 'MATLAB, CFD C_D (power off)'};
end

[apo, i] = max(OR.altitude);
fprintf('%-30s %9s %9s %9s %9s\n', 'Run', 'apogee', 't_apo', 'v_max', 'diff');
fprintf('%-30s %9.1f %9.2f %9.1f %9s\n', 'OpenRocket', apo, OR.time(i), max(OR.velocity), '-');
for k = 1:size(runs, 1)
    S = runs{k,1};
    fprintf('%-30s %9.1f %9.2f %9.1f %+8.1f%%\n', runs{k,2}, S.apogee, S.t_apogee, S.v_max, ...
            100*(S.apogee - apo)/apo);
end

figure('Position', [100 100 1000 380]);
subplot(1,3,1); hold on; grid on; title('Altitude'); xlabel('t [s]'); ylabel('m');
plot(OR.time, OR.altitude, 'k', 'LineWidth', 2, 'DisplayName', 'OpenRocket');
subplot(1,3,2); hold on; grid on; title('Speed'); xlabel('t [s]'); ylabel('m/s');
plot(OR.time, OR.velocity, 'k', 'LineWidth', 2);
subplot(1,3,3); hold on; grid on; title('Drag coefficient'); xlabel('Mach'); ylabel('C_D');
plot(tab_off(:,1), tab_off(:,2), 'k', 'LineWidth', 2);
plot(tab_on(:,1), tab_on(:,2), 'k--');
for k = 1:size(runs, 1)
    S = runs{k,1};
    subplot(1,3,1); plot(S.t, S.z, 'DisplayName', runs{k,2});
    subplot(1,3,2); plot(S.t, S.V);
    subplot(1,3,3); plot(S.Mach, S.Cd, '.');
end
subplot(1,3,1); legend('Location', 'southeast');

