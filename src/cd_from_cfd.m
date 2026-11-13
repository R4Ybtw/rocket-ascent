%% cd_from_cfd.m — convert Flow Simulation drag forces into the Cd(Mach) table
%
% Input  data/results/flowsim_drag.csv, one row per run:
%   mach,Fx,model_fraction
%   0.1,0.0581,0.25
% Fx is the Force (X) goal in newtons. model_fraction is how much of the
% rocket was inside the domain: 0.25 for the quarter model with two symmetry
% planes, 1 for a full model. Flow Simulation reports force only on the
% geometry it simulates, so divide by the fraction. VERIFY this once by running
% one Mach number with the full model.
%
% Output data/results/cd_cfd.csv (mach,cd), read by compare_openrocket.m

clear; clc;
here = fileparts(mfilename('fullpath')); addpath(here);
root = fullfile(here, '..');
r = load_rocket();
[~, ~, rho, a] = isa_atmos(0);
D = dlmread(fullfile(root, 'data', 'results', 'flowsim_drag.csv'), ',', 1, 0);
M = D(:,1); Fx = D(:,2)./D(:,3);
q = 0.5*rho*(M*a).^2;
Cd = Fx./(q*r.A_ref);
fprintf('%6s %10s %8s %10s\n', 'Mach', 'Fx full', 'Cd CFD', 'Cd build');
for k = 1:numel(M)
    fprintf('%6.2f %10.4f %8.3f %10.3f\n', M(k), Fx(k), Cd(k), drag_buildup(r, M(k)*a, 0));
end
fid = fopen(fullfile(root, 'data', 'results', 'cd_cfd.csv'), 'w');
fprintf(fid, 'mach,cd\n'); fprintf(fid, '%.4f,%.5f\n', [M Cd]'); fclose(fid);
