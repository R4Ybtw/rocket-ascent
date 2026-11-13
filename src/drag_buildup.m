function [Cd, parts] = drag_buildup(r, V, h, power_on, motor_diameter)
%DRAG_BUILDUP  Subsonic drag coefficient of a finned rocket by component build-up.
%
%   [Cd, parts] = drag_buildup(r, V, h)                       power off (coasting)
%   [Cd, parts] = drag_buildup(r, V, h, true, motor_diameter) motor burning
%
%   r  rocket struct from load_rocket(); V speed (m/s); h altitude (m, ISA).
%   Cd is referenced to the body cross-section r.A_ref, the convention
%   OpenRocket uses too.
%
%   Approach (simplified from the OpenRocket technical documentation,
%   S. Niskanen 2013, and Hoerner's Fluid-Dynamic Drag). Valid for Mach < ~0.8.
%   Each piece is a separate field of 'parts', so you can see which dominates.
%     friction_body  turbulent skin friction on nose + tube, with a fineness-ratio
%                    form factor; switches to a roughness-limited value when
%                    the surface is aerodynamically rough
%     friction_fins  the same on the fins, with a thickness form factor
%     fin_pressure   leading-edge and blunt trailing-edge drag of the fins
%     base           suction on the flat rear end. The largest single term for
%                    many model rockets. Smaller while the motor burns, because
%                    the exhaust fills part of the base.
%   Left out: nose pressure drag (small for a tangent ogive below Mach ~0.8),
%   launch lugs or rail buttons, interference, and anything transonic.
%   Expect agreement with OpenRocket and CFD of roughly +-15%; a large
%   disagreement means a units or area mistake.

    if nargin < 4, power_on = false; end
    if nargin < 5, motor_diameter = 0; end
    [~, ~, rho, a, mu] = isa_atmos(h);
    V = max(V, 1e-3);
    M = V/a; nu = mu/rho;
    D = r.body_diameter; L = r.length;

    Cf_b = cf_turb(V*L/nu, r.surface_roughness/L, M);
    Cf_f = cf_turb(V*r.fin_mac/nu, r.surface_roughness/r.fin_mac, M);
    fB = L/D;                                            % fineness ratio
    parts.friction_body = Cf_b*(1 + 1/(2*fB))*r.wet_body/r.A_ref;
    parts.friction_fins = Cf_f*(1 + 2*r.fin_thickness/r.fin_mac)*r.wet_fins/r.A_ref;

    Cd_base_coef = 0.12 + 0.13*M.^2;                     % blunt base, M < 1
    fin_front = r.fin_count*r.fin_span*r.fin_thickness;  % frontal area of all fins
    Cd_le = (1 - M.^2).^(-0.417) - 1;                    % rounded leading edge
    parts.fin_pressure = (Cd_le + Cd_base_coef)*fin_front/r.A_ref;

    A_base = r.A_ref;
    if power_on, A_base = max(A_base - pi*motor_diameter^2/4, 0); end
    parts.base = Cd_base_coef*A_base/r.A_ref;

    Cd = parts.friction_body + parts.friction_fins + parts.fin_pressure + parts.base;
    parts.Mach = M;
end

function Cf = cf_turb(Re, rel_rough, M)
    % Turbulent flat-plate skin friction with a roughness limit.
    if Re < 1e4
        Cf = 1.48e-2;
    else
        Re_crit = 51*rel_rough^(-1.039);                 % above this, roughness dominates
        if Re < Re_crit
            Cf = 1/(1.50*log(Re) - 5.6)^2;               % smooth turbulent
            Cf = Cf*(1 - 0.1*M^2);                       % subsonic compressibility
        else
            Cf = 0.032*rel_rough^0.2;                    % fully rough
            Cf = Cf/(1 + 0.18*M^2);
        end
    end
end
