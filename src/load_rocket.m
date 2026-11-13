function r = load_rocket(file)
%LOAD_ROCKET  Read data/rocket.json and add derived geometry.
%
%   r = load_rocket()                    % default file
%   r = load_rocket('data/rocket.json')
%
%   Derived fields:
%     r.A_ref        reference area pi D^2/4 (all drag coefficients use this)
%     r.length       total length
%     r.wet_body     wetted area of nose + body tube
%     r.wet_fins     wetted area of all fins (both sides)
%     r.fin_mac      mean aerodynamic chord of one fin

    if nargin < 1
        file = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'rocket.json');
    end
    r = jsondecode(fileread(file));
    D = r.body_diameter; R = D/2; Ln = r.nose_length;

    r.A_ref  = pi*D^2/4;
    r.length = Ln + r.body_length;

    % Tangent-ogive nose: wetted area by integrating the radius profile
    rho_o = (R^2 + Ln^2)/(2*R);                         % ogive radius
    x = linspace(0, Ln, 2001);
    y = sqrt(rho_o^2 - (Ln - x).^2) + R - rho_o;        % local radius, 0 at tip -> R at base
    dydx = gradient(y, x);
    nose_wet = trapz(x, 2*pi*y.*sqrt(1 + dydx.^2));
    r.wet_body = nose_wet + pi*D*r.body_length;

    cr = r.fin_root_chord; ct = r.fin_tip_chord;
    fin_area = 0.5*(cr + ct)*r.fin_span;                 % planform area of one fin
    r.wet_fins = 2*r.fin_count*fin_area;
    r.fin_mac  = (2/3)*(cr + ct - cr*ct/(cr + ct));
    r.fin_planform_area = fin_area;
end
