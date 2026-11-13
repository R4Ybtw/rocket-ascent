function R = read_openrocket_csv(file)
%READ_OPENROCKET_CSV  Read an OpenRocket simulation export (File > Export simulation data).
%
%   R = read_openrocket_csv('data/openrocket/PR1_F40.csv')
%   Fields (SI, whatever units OpenRocket wrote): R.time, R.altitude, R.vz,
%   R.velocity, R.mach, R.cd, R.thrust, R.mass, R.acc — those present in the file.
%   R.names: the original column headers.
%
%   In OpenRocket, export with "comma" as separator, and tick "Include field
%   descriptions" and "Include comments". Event lines (# Event ...) are skipped.
%   Units are converted from the header, e.g. 'Altitude (ft)' -> metres.

    L = regexp(fileread(file), '\r?\n', 'split');
    names = {}; D = [];
    for k = 1:numel(L)
        s = strtrim(L{k});
        if isempty(s), continue; end
        if s(1) == '#'
            if isempty(names) && numel(strfind(s, ',')) >= 1 && ~isempty(strfind(s, '('))
                names = strtrim(regexp(s(2:end), ',', 'split'));
            end
            continue
        end
        v = str2double(regexp(s, ',', 'split'));
        if all(~isnan(v)), D(end+1, 1:numel(v)) = v; end %#ok<AGROW>
    end
    if isempty(names), error('No header line found. Export with "Include field descriptions".'); end
    R.names = names;
    map = {'time', '^Time'; 'altitude', '^Altitude'; 'vz', '^Vertical velocity';
           'velocity', '^Total velocity'; 'mach', '^Mach number'; 'cd', '^Drag coefficient';
           'thrust', '^Thrust'; 'mass', '^Mass \('; 'acc', '^Total acceleration'};
    for j = 1:size(map, 1)
        i = find(~cellfun(@isempty, regexp(names, map{j,2}, 'once')), 1);
        if isempty(i), continue; end
        u = regexp(names{i}, '\(([^)]*)\)', 'tokens', 'once');
        if isempty(u), u = {''}; end
        R.(map{j,1}) = D(:, i)*unit_factor(strtrim(u{1}));
    end
end

function f = unit_factor(u)
    switch u
        case {'ft'},               f = 0.3048;
        case {'ft/s'},             f = 0.3048;
        case {'ft/s²', 'ft/s^2'},  f = 0.3048;
        case {'g'},                f = 1e-3;     % grams (OpenRocket's default mass unit)
        case {'oz'},               f = 0.0283495;
        case {'lb'},               f = 0.453592;
        case {'lbf'},              f = 4.44822;
        case {'mm'},               f = 1e-3;
        case {'km'},               f = 1e3;
        case {'km/h'},             f = 1/3.6;
        case {'mph'},              f = 0.44704;
        otherwise,                 f = 1;        % SI or dimensionless
    end
end
