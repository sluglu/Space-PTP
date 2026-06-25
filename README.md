# Space-PTP

A MATLAB simulator for clock synchronisation protocols (PTP and beyond) in LEO satellite scenarios.

## Structure

```
Space-PTP/
├── src/
│   ├── main.m                  # Entry point
│   ├── run_experiment.m        # Simulation loop
│   ├── save_results.m          # Save results struct to disk
│   └── plot_experiment.m       # Plot results (accepts struct or cfg)
├── configs/
│   ├── base/
│   │   └── sim_base.m          # Simulation loop parameters (starting point for experiments)
│   ├── experiments/            # Per-experiment configs  (<PROTOCOL>_exp_*.m)
│   │   └── exp_base.m          # Template
│   ├── protocols/              # Protocol + FSM constructors  (protocol_*.m)
│   │   └── protocol_base.m     # Template
│   ├── oscillators/            # Clock configs  (ox_*.m)
│   │   └── ox_base.m           # Template
│   └── scenarios/              # Orbital scenarios  (sc_*.m)
│       └── sc_base.m           # Template
├── FSM/
│   ├── NodeFSM.m               # Abstract FSM interface (subclass for any protocol)
│   └── PTP/
│       ├── PTPMasterFSM.m      # IEEE 1588 master state machine
│       └── PTPSlaveFSM.m       # IEEE 1588 slave state machine
├── clock/
│   └── Clock.m                 # Power-law oscillator (h₋₂…h₂ noise, value class)
├── channel/
│   └── Channel.m               # Pluggable propagation delay + Doppler model
├── orbit/
│   └── precompute_satellite_data.m   # Satellite Scenario Toolbox wrapper
├── tools/
│   └── ProgressTracker.m       # fprintf progress reporter (serial + parfor)
└── tests/
    ├── test_clock_model.m          # Allan deviation + phase noise validation
    ├── test_PTP_FSM.m              # PTP 4-way handshake correctness
    ├── test_PTP_servo.m            # PI servo convergence (phase + freq offset)
    ├── test_PTP_gaussian_delay.m   # PTP error vs delay asymmetry sweep
    └── test_satcom_orbit_model.m   # Propagation delay + Doppler visualisation
```

## Quick Start

```matlab
addpath src
addpath configs/base configs/experiments configs/oscillators configs/scenarios configs/protocols
addpath clock channel FSM FSM/PTP orbit tools

cfg     = PTP_exp_perfect_inter_shell();
results = run_experiment(cfg);
save_results(results, cfg);
plot_experiment(results);
```

## Config system

Every config function returns a ready object — compose them to build an experiment:

```matlab
function cfg = PTP_exp_ocxo_same_plane()
    cfg          = sim_base();            % simulation loop parameters
    cfg.exp.name = mfilename();
    cfg.scenario = sc_same_plane();       % satelliteScenario + platform handles
    cfg.nodes    = protocol_ptp(ox_perfect(), ox_ocxo());  % Clock + FSM per node
end
```

| Layer | Function | Returns |
|-------|----------|---------|
| Sim params | `sim_base()` | `cfg` with `cfg.sim` fields |
| Scenario | `sc_*()` | `struct(sc, node1, node2, name)` — call `.sc.show()` to visualise |
| Oscillator | `ox_*()` | ready `Clock` object |
| Protocol | `protocol_*(clk, clk)` | `nodes` cell array (Clock + FSM per node) |

Oscillator overrides (e.g. for tests):
```matlab
ox_ocxo(0, struct('alpha', 0, 'kw_n_neg1', 4096))
```

## Architecture

### Protocol-agnostic simulation loop

`run_experiment` knows nothing about the protocol. It calls the same three methods on every FSM each tick:

| Method | When | What it does |
|--------|------|--------------|
| `step(ts)` | Every LOS tick | Returns outgoing messages; advances internal state |
| `receive(msg, ts)` | Message delivered | Updates internal state |
| `reset()` | LOS lost | Clears in-flight state |

Every message must have a `'to'` field with the recipient node id. The loop stamps `'from'` before routing.

After every `step()`, `fsm.servo_y` (fractional frequency correction, dimensionless) is copied to `clock.servo_y` and applied on the next `advance()` call as `servo_y × f0` Hz.

### Adding a new protocol

1. Create `FSM/<Protocol>/YourFSM.m` — subclass `NodeFSM`, implement `step`, `receive`, `reset`. Set `servo_y` whenever you have a new frequency correction; leave it at 0 if your protocol has no servo.
2. Create `configs/protocols/protocol_yours.m` — see `protocol_base.m`.
3. Write experiment configs: `protocol_yours(ox_perfect(), ox_ocxo())`.

`run_experiment` and `plot_experiment` require no changes.

## Key Concepts

**Clock** — Power-law frequency noise oscillator (IEEE 1139-2008). Create with `ox_*()`.

| h coefficient | Noise type | Implementation |
|--------------|------------|----------------|
| h₋₂ | Random Walk FM | Scalar integrator |
| h₋₁ | Flicker FM | Kasdin-Walter FIR |
| h₀ | White FM | White Gaussian draw |
| h₁ | Flicker PM | Kasdin-Walter FIR |
| h₂ | White PM | White Gaussian draw |

Phase uses trapezoid integration `(f_old + f_new)/2 · dt`. Value-class: always assign the return value (`clk = clk.advance(dt)`).

**Channel** — Wraps precomputed satellite state with pluggable propagation effects. Add effects with `channel.add_effect(fn)` where `fn(state)` returns `struct('fwd', dt_s, 'bwd', dt_s)`.

**PTP servo** — PI servo in `PTPSlaveFSM`, engages after the first complete 4-way handshake:

```
servo_integral += offset × sync_interval
servo_y = −(Kp × offset + Ki × servo_integral)
```

Default gains `kp=0.1`, `ki=0.01` converge in ~10 sync cycles. `servo_y` is preserved across LOS outages; the integral resets. Configure via `protocol_ptp` params:

```matlab
cfg.nodes = protocol_ptp(ox_perfect(), ox_ocxo(), struct('servo', struct('kp', 0.2, 'ki', 0.02)));
cfg.nodes = protocol_ptp(ox_perfect(), ox_ocxo(), struct('servo', struct('enabled', false)));
```

**Results struct** — fields returned by `run_experiment`:

| Field | Description |
|-------|-------------|
| `times` | Simulation time [s] |
| `los` | LOS flag (1 / 0) |
| `fwd_delay`, `bwd_delay` | Propagation delays [s] |
| `fwd_doppler`, `bwd_doppler` | Doppler shifts [Hz] |
| `nodes{k}` | Per-node: `id`, `real_offset`, `real_freq`, `offset_est`, `delay_est` |
| `real_offset`, `offset_est`, `delay_est` | 2-node convenience aliases |
| `meta` | `exp_name`, `timestamp`, `cfg` |

## Tests

Run individually from the MATLAB command window. Each prints a pass/fail summary and produces plots.

| Test | Validates | Pass criterion |
|------|-----------|----------------|
| `test_clock_model` | OCXO + CSAC noise model | Empirical ADEV within ×3 of theory at every τ |
| `test_PTP_FSM` | IEEE 1588 4-way handshake | Delay error < 1 µs; offset bias = asymmetry; handshake on every sync cycle |
| `test_PTP_servo` | PI servo convergence | Phase: < 1 % residual in 50 s; Freq: drift < 1 ns/s; Off: no convergence without servo |
| `test_PTP_gaussian_delay` | PTP error vs delay asymmetry | Log-log slope 1.0 ± 0.15; amplitude ≈ 0.5 × σ_asym |
| `test_satcom_orbit_model` | Orbit + Channel pipeline | Delays plausible, NaN outside LOS, `Channel.compute()` matches interpolants |

`test_clock_model` uses ×3 tolerance — Allan deviation is stochastic and a single run has ~±50 % variance at short τ.

## Delay Effects (TODO)

Add to `cfg.channel_effects` as function handles: `fn(state)` → `struct('fwd', delta_s, 'bwd', delta_s)`.

| Effect | Magnitude |
|--------|-----------|
| Ionosphere | 1–100 m / c |
| Troposphere | 2–25 m / c |
| Special relativity | ~10 m/day / c |
| General relativity | ~10 m/day / c |
| Hardware delay | 0.3–10 m / c |
