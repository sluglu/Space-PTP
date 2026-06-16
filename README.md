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
│   │   └── config_base.m       # Default simulation parameters (copy → override)
│   ├── experiments/            # Per-experiment configs  (<PROTOCOL>_exp_*.m)
│   │   └── exp_base.m          # Template — read before writing a new experiment
│   ├── protocols/              # Protocol node constructors  (protocol_*.m)
│   │   └── protocol_base.m     # Template — read before writing a new protocol
│   ├── oscillators/            # Oscillator specs  (ox_*.m)
│   │   └── ox_base.m           # Template — read before writing a new oscillator
│   └── scenarios/              # Orbital scenarios  (sc_*.m)
│       └── sc_base.m           # Template — read before writing a new scenario
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
% Add project folders to path (adjust root path to your installation)
addpath src
addpath configs/base configs/experiments configs/oscillators configs/scenarios configs/protocols
addpath clock channel FSM FSM/PTP orbit tools

cfg     = PTP_exp_perfect_inter_shell();
results = run_experiment(cfg);
save_results(results, cfg);
plot_experiment(results);
```

## Architecture

### Protocol-agnostic simulation loop

`run_experiment` knows nothing about the protocol that runs on each node. It iterates over `cfg.nodes` (a cell array built by the protocol config) and calls the same three methods on every FSM:

| Method | When called | What it does |
|--------|-------------|--------------|
| `step(ts)` | Every LOS tick | Returns outgoing messages; advances internal state |
| `receive(msg, ts)` | When a message is delivered | Updates internal state |
| `reset()` | When LOS is lost | Clears in-flight state |

Every outgoing message must have a `'to'` field containing the recipient node id. The loop stamps each message with the sender's `'from'` id before routing.

After every `step()`, the loop copies `fsm.servo_y` into `clock.servo_y` so that servo corrections take effect on the next `advance()` call without any protocol-specific code in the loop.

### Config layers

Each experiment config composes four independent layers:

```
experiment = config_base()  +  scenario  +  oscillators  +  protocol
```

```matlab
function cfg = PTP_exp_perfect_inter_shell()
    cfg          = config_base();           % simulation defaults
    cfg.exp.name = mfilename();
    cfg.scenario = sc_inter_shell();        % orbital geometry
    cfg.nodes    = protocol_ptp(ox_perfect(), ox_perfect());  % protocol + clocks
end
```

### Adding a new protocol

1. Create `FSM/<YourProtocol>/YourFSM.m` — subclass `NodeFSM`, implement `step`, `receive`, `reset`, expose `last_offset` and `last_delay`.
   - If your protocol includes a servo, set `obj.servo_y` (inherited from `NodeFSM`, fractional df/f0) whenever you have a new frequency correction. The loop applies it to the clock automatically as `servo_y * f0`.
2. Create `configs/protocols/protocol_your.m` — copy `protocol_base.m`, build and return the `nodes` cell array.
3. Create experiment configs using `protocol_your(ox_A(), ox_B())`.

`run_experiment` and `plot_experiment` require no changes.

## Key Concepts

**Clock model** — `Clock.m` implements a power-law frequency noise oscillator (IEEE 1139-2008). The `h` vector holds `[h₋₂, h₋₁, h₀, h₁, h₂]` for RWFM, Flicker FM, White FM, Flicker PM, and White PM noise.

| Component | Type | Implementation |
|-----------|------|----------------|
| h₋₂ | Random Walk FM | Scalar integrator of white noise |
| h₋₁ | Flicker FM | Kasdin-Walter FIR (64 taps, half-order integration) |
| h₀ | White FM | Direct white Gaussian draw |
| h₁ | Flicker PM | Kasdin-Walter FIR (32 taps, half-order differentiation) |
| h₂ | White PM | Direct white Gaussian draw scaled by dt⁻³ |

Phase is integrated with the trapezoid rule `(f_old + f_new)/2 · dt` to eliminate first-order bias from linear drift. Value-class semantics: always assign the return value (`obj = obj.advance(dt)`).

The `servo_y` property (fractional frequency correction, dimensionless) is set externally by the FSM servo each step and enters the frequency calculation as `servo_y * f0` alongside `delta_f0` and `alpha`. Using a fractional unit keeps the PI gains clock-frequency-independent.

**Channel** — `Channel.m` wraps precomputed satellite state and applies pluggable propagation effects. Add effects with `channel.add_effect(fn)` where `fn(state)` returns `struct('fwd', dt_s, 'bwd', dt_s)`. The base geometric delay is always included.

**FSM** — `PTPMasterFSM` and `PTPSlaveFSM` implement the IEEE 1588 4-way handshake (SYNC → FOLLOW_UP → DELAY_REQ → DELAY_RESP). Both subclass `NodeFSM`. To add a different protocol, create a new folder under `FSM/` and subclass `NodeFSM`.

The `NodeFSM` base class exposes a `servo_y` property (default 0, fractional). The simulation loop reads it after every `step()` call and writes it to the corresponding clock's `servo_y`. Protocols that implement a servo loop just update this property when they have a new estimate.

**PTP servo** — `PTPSlaveFSM` includes a PI frequency servo that engages after each completed 4-way handshake:

```
servo_integral += offset × sync_interval
servo_y = −(Kp × offset + Ki × servo_integral)
```

`servo_y` is a fractional frequency correction (dimensionless); the clock applies it as `servo_y × f0` Hz. Configure via `params.servo` in `protocol_ptp`:

```matlab
cfg.nodes = protocol_ptp(ox_ocxo(), ox_ocxo(), struct( ...
    'servo', struct('enabled', true, 'kp', 0.1, 'ki', 0.01)));
% Disable servo entirely:
cfg.nodes = protocol_ptp(ox_ocxo(), ox_ocxo(), struct( ...
    'servo', struct('enabled', false)));
```

Default gains (`kp=0.1 s⁻¹`, `ki=0.01 s⁻²`) give convergence in ~10 sync cycles for small perturbations. After an LOS outage `servo_y` is preserved (so the clock keeps the last correction); the integral resets to 0.

**Simulation loop** — Adaptive time-stepping: when a message is in flight, `sim_time` snaps forward to the message delivery time instead of advancing by `dt_los`. This ensures receive timestamps are accurate — the clock is advanced to exactly the delivery time before the FSM reads it.

**Results struct** — fields returned by `run_experiment`:

| Field | Description |
|-------|-------------|
| `times` | Simulation time vector [s] |
| `los` | LOS flag (1 = in contact, 0 = no contact) |
| `fwd_delay` | Forward propagation delay [s] |
| `bwd_delay` | Backward propagation delay [s] |
| `fwd_doppler` | Forward Doppler shift [Hz] |
| `bwd_doppler` | Backward Doppler shift [Hz] |
| `nodes{k}` | Per-node struct: `id`, `real_offset`, `real_freq`, `offset_est`, `delay_est` |
| `real_offset` | True clock offset of node 2 vs node 1 [s] *(2-node alias)* |
| `offset_est` | FSM offset estimate [s] *(2-node alias)* |
| `delay_est` | FSM one-way delay estimate [s] *(2-node alias)* |
| `meta` | `exp_name`, `timestamp`, `cfg` |

## Tests

All tests live in `tests/` and are designed to be run individually from the MATLAB command window.  Each test prints a pass/fail summary to the console and produces diagnostic plots.

| Test | What it validates | Pass criterion |
|------|-------------------|----------------|
| `test_clock_model` | Power-law noise model (OCXO + CSAC) | Empirical Allan deviation within factor 3 of theory at every τ |
| `test_PTP_FSM` | IEEE 1588 4-way handshake | Delay estimate < 1 µs error; offset bias matches delay asymmetry; every sync cycle produces a new estimate |
| `test_PTP_servo` | PI servo convergence | Case 1: phase offset shrinks to < 1 % in 50 s; Case 2: freq offset residual rate < 1 ns/s; Case 3: no convergence without servo |
| `test_PTP_gaussian_delay` | PTP offset error vs delay asymmetry | Log-log slope ≈ 1.0 ± 0.15; amplitude ≈ 0.5 × σ_asym |
| `test_satcom_orbit_model` | `precompute_satellite_data` + `Channel` pipeline | Delays plausible, NaN-consistent outside LOS, `Channel.compute()` matches interpolants |

**Notes on tolerance:**
- `test_clock_model` uses a factor-of-3 tolerance because Allan deviation estimates are stochastic — a single 1-hour run has ~±50 % variance at short τ.  If multiple taus fail or the deviation is large, inspect the ADEV plot; a bias larger than 3× indicates a model bug.
- `test_PTP_gaussian_delay` fits a slope to a 60-point log-log sweep, which smooths out Monte Carlo variance.  The ±0.15 slope tolerance is tight enough to detect wrong scaling but loose enough to be deterministic.

## Delay Effects (TODO)

Add effects to `cfg.channel_effects` as function handles. Each effect receives a `state` struct and returns `struct('fwd', delta_s, 'bwd', delta_s)`.

| Effect | Magnitude | Notes |
|--------|-----------|-------|
| Ionosphere | 1–100 m / c | Frequency-dependent, TEC model needed |
| Troposphere | 2–25 m / c | Saastamoinen or similar |
| Special relativity | ~10 m/day / c | Satellite velocity |
| General relativity | ~10 m/day / c | Gravitational blueshift |
| Multipath | 0.5–10 m / c | Geometry-dependent |
| Hardware delay | 0.3–10 m / c | Calibration offset |
