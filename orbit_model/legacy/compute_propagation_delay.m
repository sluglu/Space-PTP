function dt = compute_propagation_delay(r1, r2, t0, guess)
    c = 299792458;
    tol = 1e-12;
    max_iter = 20;

    r1_t0 = r1(t0);
    dt = max(guess, 1e-6); % avoid zero start
    h = 1e-8; % finite difference step

    for i = 1:max_iter
        r2_dt = r2(t0 + dt);
        f = norm(r2_dt - r1_t0) - c * dt;

        % Finite difference approximation of derivative
        r2_dth = r2(t0 + dt + h);
        f_prime = (norm(r2_dth - r1_t0) - norm(r2_dt - r1_t0)) / h - c;

        if abs(f_prime) < 1e-10
            break; % avoid division by near-zero
        end

        dt_new = dt - f / f_prime;
        if abs(dt_new - dt) < tol
            dt = dt_new;
            return;
        end
        dt = dt_new;
    end

    warning('Newton method did not converge. Returning NaN.');
    dt = NaN;
end
