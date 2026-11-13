function S = ascent(r, motor, opts)
%ASCENT  Point-mass ascent of a rocket from launch rail to apogee (2D, no wind).
%
%   S = ascent(r, motor)            r from load_rocket(), motor from read_eng()
%   S = ascent(r, motor, opts)      motor = [] for an unpowered body (used by the tests)
%
%   Model
%   * State [x z vx vz]: horizontal and vertical position and velocity.
%   * Forces: thrust (from the .eng curve), drag 0.5 rho V^2 Cd A_ref, gravity.
%   * On the rail, motion is constrained along the rail and the rocket can't
%     move backwards. Off the rail, thrust and drag act along the velocity:
%     zero angle of attack, which is what a stable rocket does in still air.
%   * Mass falls as propellant burns, in proportion to impulse delivered.
%   * ISA atmosphere from the launch altitude.
%   What it cannot do: wind and weathercocking, stability, rotation (that needs
%   the 6-DOF model in the advanced project). Compare with OpenRocket at zero wind.
%
%   opts fields (all optional):
%     drag        'buildup' (default; tabulated vs Mach at launch altitude) | 'table' | 'constant'
%     cd_table    [Mach Cd] rows, power off      (for 'table')
%     cd_table_on [Mach Cd] rows, power on       (optional; defaults to cd_table)
%     cd_const    value                          (for 'constant')
%     cd_scale, mass_scale, thrust_scale         multipliers for sensitivity runs (1)
%     g           gravity (9.80665)
%     const_rho   true -> density fixed at the launch-altitude value (tests)
%     v0          initial speed along the launch direction (0)
%     RelTol, AbsTol, MaxStep                    integrator settings
%
%   Output S: time histories (t, x, z = altitude above the pad, vx, vz, V, Mach,
%   acc, m, T, Dr, Cd) and a summary (apogee, t_apogee, v_max, M_max, a_max,
%   v_rail, t_burnout, v_burnout).

    if nargin < 3, opts = struct(); end
    o = defaults(opts, r);
    th = o.launch_angle*pi/180;
    e  = [sin(th); cos(th)];                     % rail direction
    if isempty(motor)
        motor = struct('t', [0; 1e-9], 'F', [0; 0], 'I_cum', [0; 0], 'I_total', 0, ...
                       'prop_mass', 0, 'total_mass', 0, 't_burn', 0, 'diameter', 0);
    end

    % Speed: the build-up drag depends almost only on Mach (Reynolds-number
    % changes over a <1 km flight move Cd by ~1%), so tabulate it once at the
    % launch altitude instead of rebuilding it at every integration step.
    if strcmp(o.drag, 'buildup')
        [~, ~, ~, a0] = isa_atmos(o.h0);
        Mg = (0:0.01:0.9)'; Coff = zeros(size(Mg)); Con = Coff;
        for k = 1:numel(Mg)
            Coff(k) = drag_buildup(r, max(Mg(k), 0.01)*a0, o.h0, false);
            Con(k)  = drag_buildup(r, max(Mg(k), 0.01)*a0, o.h0, true, motor.diameter);
        end
        o.drag = 'table'; o.cd_table = [Mg Coff]; o.cd_table_on = [Mg Con];
    end

    y0 = [0; 0; o.v0*e(1); o.v0*e(2)];
    t_end = max(motor.t_burn, 0) + 120;
    ev = @(t, y) apogee_event(t, y);
    odeopt = odeset('RelTol', o.RelTol, 'AbsTol', o.AbsTol, 'MaxStep', o.MaxStep, 'Events', ev);
    [t, Y] = ode45(@(t, y) rhs(t, y, r, motor, o, e), [0 t_end], y0, odeopt);

    n = numel(t);
    S.t = t; S.x = Y(:,1); S.z = Y(:,2); S.vx = Y(:,3); S.vz = Y(:,4);
    S.V = hypot(S.vx, S.vz);
    [S.acc, S.m, S.T, S.Dr, S.Cd, S.Mach] = deal(zeros(n, 1));
    for k = 1:n
        [dy, aux] = rhs(t(k), Y(k,:)', r, motor, o, e);
        S.acc(k) = hypot(dy(3), dy(4)); S.m(k) = aux.m; S.T(k) = aux.T;
        S.Dr(k) = aux.D; S.Cd(k) = aux.Cd; S.Mach(k) = aux.M;
    end
    [S.apogee, i] = max(S.z); S.t_apogee = t(i);
    [S.v_max, i] = max(S.V); S.M_max = S.Mach(i);
    S.a_max = max(S.acc);
    s = Y(:,1)*e(1) + Y(:,2)*e(2);
    j = find(s >= o.rail, 1);
    if isempty(j) || j == 1, S.v_rail = S.V(1); else
        S.v_rail = interp1(s(j-1:j), S.V(j-1:j), o.rail);
    end
    S.t_burnout = motor.t_burn;
    S.v_burnout = interp1(t, S.V, min(motor.t_burn, t(end)));
end

function [dy, aux] = rhs(t, y, r, motor, o, e)
    z = y(2); v = y(3:4); V = norm(v);
    h = o.h0 + max(z, 0);
    if o.const_rho, h = o.h0; end
    [rho, a] = isa_rho_a(h);

    T = o.thrust_scale*lerp(motor.t, motor.F, t);
    I = lerp(motor.t, motor.I_cum, t);
    burnt = 0; if motor.I_total > 0, burnt = motor.prop_mass*I/motor.I_total; end
    m = o.mass_scale*(r.dry_mass + motor.total_mass - burnt);

    M = V/a;
    if strcmp(o.drag, 'constant')
        Cd = o.cd_const;
    else
        tab = o.cd_table; if T > 0 && ~isempty(o.cd_table_on), tab = o.cd_table_on; end
        Cd = lerp(tab(:,1), tab(:,2), M);
    end
    Cd = o.cd_scale*Cd;
    D = 0.5*rho*V^2*Cd*r.A_ref;

    s = y(1)*e(1) + y(2)*e(2);                     % distance along the rail
    if s < o.rail
        % constrained to the rail; can't slide backwards off the pad
        acc_e = (T - D*sign(dot(v, e)) - m*o.g*e(2))/m;
        if s <= 0 && dot(v, e) <= 0 && acc_e < 0, acc_e = 0; end
        acc = acc_e*e;
        dpos = dot(v, e)*e;
    else
        if V > 1e-6, u = v/V; else, u = e; end    % flight direction (launch direction from rest)
        acc = (T - D)/m*u - [0; o.g];
        dpos = v;
    end
    dy = [dpos; acc];
    if nargout > 1, aux = struct('m', m, 'T', T, 'D', D, 'Cd', Cd, 'M', M); end
end

function yq = lerp(x, y, xq)
    % linear interpolation, held constant beyond the ends (much faster than interp1
    % for the single-point calls an ODE solver makes)
    if xq <= x(1), yq = y(1); return; end
    if xq >= x(end), yq = y(end); return; end
    i = find(x > xq, 1);
    w = (xq - x(i-1))/(x(i) - x(i-1));
    yq = (1 - w)*y(i-1) + w*y(i);
end

function [rho, a] = isa_rho_a(h)
    % ISA troposphere, scalar and fast (same formulas as isa_atmos.m)
    T = 288.15 - 0.0065*h;
    p = 101325*(T/288.15)^5.25588;
    rho = p/(287.05287*T);
    a = sqrt(1.4*287.05287*T);
end

function [val, term, dir] = apogee_event(~, y)
    val = y(4);                       % vertical velocity
    if y(2) < 0.5, val = 1; end       % ignore the pad, before lift-off
    term = 1; dir = -1;
end

function o = defaults(o, r)
    d = struct('drag', 'buildup', 'cd_table', [], 'cd_table_on', [], 'cd_const', 0.5, ...
               'cd_scale', 1, 'mass_scale', 1, 'thrust_scale', 1, 'g', 9.80665, ...
               'const_rho', false, 'v0', 0, 'RelTol', 1e-7, 'AbsTol', 1e-7, 'MaxStep', 0.02, ...
               'rail', r.launch_rail_length, 'launch_angle', r.launch_angle_deg, ...
               'h0', r.launch_altitude);
    f = fieldnames(d);
    for k = 1:numel(f)
        if ~isfield(o, f{k}) || isempty(o.(f{k}))
            if ~(strcmp(f{k}, 'cd_table') || strcmp(f{k}, 'cd_table_on')) || ~isfield(o, f{k})
                o.(f{k}) = d.(f{k});
            end
        end
    end
end
