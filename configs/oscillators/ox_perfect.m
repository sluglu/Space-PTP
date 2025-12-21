% Perfect Oscillator
function ox = ox_perfect()
    f0 = 100e6;
    np = NoiseProfile();
    ox = struct( ...
         'f0', f0, ...
         'np', np);
end