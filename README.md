# Space-PTP

A MATLAB simulator for PTP like clock synchronization protocol in LEO satellite scenarios.

## Structure

```
Space-PTP/
├── src/
│   ├── main.m                  # Entry point
│   ├── run_experiment.m        # Simulate and return results struct
│   ├── save_results.m          # Save results to disk
│   └── plot_experiment.m       # Plot results (accepts struct or cfg)
├── configs/
│   ├── base/config_base.m      # Default simulation parameters
│   ├── experiments/            # Per-experiment configs (exp_*.m)
│   ├── oscillators/            # Oscillator specs (ox_perfect, ox_ocxo, ox_csac)
│   └── scenarios/              # Orbital scenarios (sc_*.m)
├── clock/
│   └── Clock.m                 # Power-law oscillator (h₋₂…h₂ noise, value class)
├── channel/
│   └── Channel.m               # Pluggable delay effect system
├── fsm/
│   ├── NodeFSM.m               # Abstract FSM interface
│   └── PTP/
│       ├── MasterFSM.m         # PTP master state machine
│       └── SlaveFSM.m          # PTP slave state machine
├── orbit/
│   └── precompute_satellite_data.m   # Satcom toolbox wrapper
├── tools/
│   └── ProgressTracker.m       # fprintf progress reporter (serial + parfor)
└── tests/
    ├── test_FSM.m              # PTP handshake correctness
    ├── test_clock_model.m      # Allan deviation + phase noise validation
    ├── test_gaussian_delay.m   # PTP error vs delay asymmetry sweep
    └── test_satcom_orbit_model.m  # Propagation delay + Doppler visualisation
```

## Quick Start

```matlab
% Add project folders to path (adjust to your installation)
addpath src configs/base configs/experiments configs/oscillators ...
        configs/scenarios clock channel fsm fsm/PTP orbit tools

cfg     = exp_perfect_inter_shell();
results = run_experiment(cfg);
save_results(results, cfg);
plot_experiment(results);
```

## Key Concepts

**Clock model** — `Clock.m` implements a power-law frequency noise oscillator (IEEE 1139-2008). The `h` vector holds coefficients `[h₋₂, h₋₁, h₀, h₁, h₂]` for RWFM, Flicker FM, White FM, Flicker PM, and White PM noise respectively. Value-class semantics: always assign the return value (`obj = obj.advance(dt)`).

**Channel** — `Channel.m` wraps precomputed satellite state (position, velocity, LOS flags, propagation delays, Doppler) and applies pluggable delay effects. Add new effects with `channel.add_effect(fn)` where `fn(state)` returns `struct('fwd', x, 'bwd', x)`.

**FSM** — `MasterFSM` and `SlaveFSM` implement the PTP 4-way handshake (SYNC → FOLLOW_UP → DELAY_REQ → DELAY_RESP). Each subclasses `NodeFSM`. To add a different protocol, create a new folder under `fsm/` and subclass `NodeFSM`.

**Simulation loop** — Adaptive time-stepping: `sim_time` snaps to the next message delivery time when a message is in flight. Clocks are advanced by `actual_dt = sim_time - prev_time` to avoid over-advancing.

**Results struct** fields: `times`, `ptp_offset`, `ptp_delay`, `ptp_rt_delay`, `real_offset`, `real_freq`, `fwd_delay`, `bwd_delay`, `fwd_doppler`, `bwd_doppler`, `los`, `scenario`, `meta`.

## Delay Effects (TODO)

The `Channel` class is structured to accept additional delay effects via `add_effect`. Candidates ranked by magnitude:

| Effect | Magnitude | Notes |
|---|---|---|
| Ionosphere | 1–100 m | Frequency-dependent, TEC model needed |
| Troposphere | 2–25 m | Saastamoinen or similar |
| Special relativity (velocity) | ~10 m/day | Satellite velocity vs ground |
| General relativity (gravity) | ~10 m/day | Gravitational blueshift |
| Multipath | 0.5–10 m | Geometry-dependent |
| Hardware delay | 0.3–10 m | Calibration offset |

Each effect needs: `function d = my_effect(state)` returning `struct('fwd', metres/c, 'bwd', metres/c)`. The `state` struct already carries `pos_master`, `vel_master`, `pos_slave`, `vel_slave` (ECI, metres).
