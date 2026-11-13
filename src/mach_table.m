function tab = mach_table(M, Cd)
%MACH_TABLE  Bin scattered (Mach, Cd) samples into a clean, sorted table.
%   Averages samples that fall in the same Mach bin, so interpolation in
%   ascent.m doesn't jump between noisy neighbouring points.
    M = M(:); Cd = Cd(:);
    if numel(M) < 2, tab = [0 mean(Cd); 1 mean(Cd)]; return; end
    edges = linspace(min(M), max(M), min(40, numel(M)) + 1);
    tab = [];
    for k = 1:numel(edges) - 1
        s = M >= edges(k) & M <= edges(k+1);
        if any(s), tab(end+1, :) = [mean(M(s)) mean(Cd(s))]; end %#ok<AGROW>
    end
end
