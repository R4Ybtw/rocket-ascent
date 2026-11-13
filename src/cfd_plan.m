%% cfd_plan.m — Flow Simulation run list for the drag curve Cd(Mach)
%
% Prints, for each Mach number: the velocity to enter, the Reynolds number,
% the dynamic pressure, and the drag force the build-up method PREDICTS for a
% quarter model, as a prediction to test the CFD against.
% Air at sea level, 288.15 K (ISA), to match the flight model's launch conditions.

clear; clc;
here = fileparts(mfilename('fullpath')); addpath(here);
r = load_rocket();
[T, p, rho, a, mu] = isa_atmos(0);
Ms = [0.1 0.2 0.3 0.4 0.5];
fprintf('Air (ISA sea level): T = %.2f K, p = %.0f Pa, rho = %.4f kg/m^3, a = %.1f m/s\n', T, p, rho, a);
fprintf('Reference area A = pi D^2/4 = %.4e m^2, length L = %.3f m\n\n', r.A_ref, r.length);
fprintf('%6s %9s %11s %9s %9s %16s\n', 'Mach', 'V [m/s]', 'Re_L', 'q [Pa]', 'Cd pred', 'Fx quarter [N]');
for M = Ms
    V = M*a; q = 0.5*rho*V^2;
    Cd = drag_buildup(r, V, 0);
    fprintf('%6.2f %9.2f %11.3g %9.1f %9.3f %16.4f\n', M, V, V*r.length*rho/mu, q, Cd, Cd*q*r.A_ref/4);
end
fprintf('\nThe highest Mach worth running is just above the flight''s maximum\n');
fprintf('(run_flight.m reports it: about 0.32 for the F40, 0.46 for the G80T).\n');
