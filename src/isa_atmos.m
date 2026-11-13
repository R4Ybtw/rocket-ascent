function [T, p, rho, a, mu] = isa_atmos(h)
%ISA_ATMOS  International Standard Atmosphere, 0-20 km (geopotential altitude).
%
%   [T, p, rho, a, mu] = isa_atmos(h)      h in metres (scalar or array)
%
%   Troposphere (0-11 km): temperature falls 6.5 K per km from 288.15 K.
%   Lower stratosphere (11-20 km): constant 216.65 K.
%   Pressure follows from hydrostatic balance with the ideal-gas law.
%   Viscosity from Sutherland's law.
%   (The Aerospace Toolbox function atmosisa gives the same numbers.)

    g0 = 9.80665; R = 287.05287; gam = 1.4;
    T0 = 288.15; p0 = 101325; L = 0.0065;
    h = min(max(h, 0), 20000);
    T = zeros(size(h)); p = zeros(size(h));
    lo = h <= 11000;
    T(lo) = T0 - L*h(lo);
    p(lo) = p0*(T(lo)/T0).^(g0/(L*R));
    T11 = T0 - L*11000; p11 = p0*(T11/T0)^(g0/(L*R));
    T(~lo) = T11;
    p(~lo) = p11*exp(-g0*(h(~lo) - 11000)/(R*T11));
    rho = p./(R*T);
    a   = sqrt(gam*R*T);
    mu  = 1.458e-6*T.^1.5./(T + 110.4);
end
