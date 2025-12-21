function [r1, r2] = generate_position_functions(params1, params2)
% params1 and params2 are structs with fields:
% r (radius), i (inclination), theta0 (initial anomaly), RAAN (right ascension of ascending node)

mu = 3.986004418e14; % gravitational parameter [m^3/s^2]
omega1 = sqrt(mu / params1.r^3);
omega2 = sqrt(mu / params2.r^3);

r1 = @(t) params1.r * rotate_vector( ...
    [cos(omega1*t + params1.theta0); ...
     sin(omega1*t + params1.theta0); ...
     0], ...
    params1.i, params1.RAAN);

r2 = @(t) params2.r * rotate_vector( ...
    [cos(omega2*t + params2.theta0); ...
     sin(omega2*t + params2.theta0); ...
     0], ...
    params2.i, params2.RAAN);
end

function r_eci = rotate_vector(r_orb, i, RAAN)
% Apply inclination and RAAN rotations to orbital frame vector
% i and RAAN should be in radians

% Rotation about z-axis by RAAN
Rz_RAAN = [cos(RAAN), -sin(RAAN), 0;
           sin(RAAN),  cos(RAAN), 0;
           0,          0,         1];

% Rotation about x-axis by inclination
Rx_i = [1, 0,           0;
        0, cos(i), -sin(i);
        0, sin(i),  cos(i)];

% Total rotation: Rz(RAAN) * Rx(i)
r_eci = Rz_RAAN * Rx_i * r_orb;
end
