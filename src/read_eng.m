function m = read_eng(file)
%READ_ENG  Read a RASP .eng motor file (the format ThrustCurve.org and OpenRocket use).
%
%   m = read_eng('data/motors/AeroTech_F40.eng')
%
%   m.name, m.maker, m.diameter (m), m.length (m), m.prop_mass, m.total_mass (kg)
%   m.t, m.F             thrust curve, with a (0,0) point added at the start
%   m.I_total            total impulse, N s (trapezoidal integral of the curve)
%   m.t_burn             burn time, s (last point of the curve)
%   m.F_avg              I_total / t_burn
%   m.class              motor letter from the impulse (A = 1.26-2.5 N s, each letter doubles)
%
%   Mass model used by everyone (RASP, OpenRocket, RockSim): propellant
%   burns in proportion to the impulse delivered so far.

    txt = regexp(fileread(file), '\r?\n', 'split');
    hdr = []; t = []; F = [];
    for k = 1:numel(txt)
        s = strtrim(txt{k});
        if isempty(s) || s(1) == ';', continue; end
        if isempty(hdr)
            hdr = regexp(s, '\s+', 'split');
            continue
        end
        v = sscanf(s, '%f');
        if numel(v) >= 2, t(end+1) = v(1); F(end+1) = v(2); end %#ok<AGROW>
    end
    if numel(hdr) < 7, error('Header line not recognised in %s', file); end
    m.name = hdr{1};
    m.diameter = str2double(hdr{2})/1000;
    m.length = str2double(hdr{3})/1000;
    m.delays = hdr{4};
    m.prop_mass = str2double(hdr{5});
    m.total_mass = str2double(hdr{6});
    m.maker = hdr{7};
    if t(1) > 0, t = [0 t]; F = [0 F]; end
    m.t = t(:); m.F = F(:);
    m.I_cum = [0; cumsum(0.5*(F(1:end-1) + F(2:end))'.*diff(t(:)))];   % impulse delivered by t
    m.I_total = m.I_cum(end);
    m.t_burn = t(end);
    m.F_avg = m.I_total/m.t_burn;
    letters = 'ABCDEFGHIJKLMNO';
    m.class = letters(max(1, ceil(log2(m.I_total/2.5)) + 1));
end
