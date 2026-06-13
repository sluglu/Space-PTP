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
├── fsm/
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
    ├── test_PTP_FSM.m          # PTP 4-way handshake correctness
    ├── test_clock_model.m      # Allan deviation + phase noise validation
    ├── test_PTP_gaussian_delay.m  # PTP error vs delay asymmetry sweep
    └── test_satcom_orbit_model.m  # Propagation delay + Doppler visualisation
```

## Quick Start

```matlab
% Add project folders to path (adjust root path to your installation)
addpath src
addpath configs/base configs/experiments configs/oscillators configs/scenarios configs/protocols
addpath clock channel fsm fsm/PTP orbit tools

cfg     = PTP_exp_perfect_inter_shell();
results = run_experiment(cfg);
save_results(results, cfg);
plot_experiment(results);
```

## Architecture

### Protocol-agnostic simulation loop

`run_experiment` knows nothing about the protocol that run on each node. It iterates over `cfg.nodes` (a cell array built by the protocol config) and calls the same three methods on every FSM:

| Method | When called | What it does |
|--------|-------------|--------------|
| `step(ts)` | Every LOS tick | Returns outgoing messages; advances internal state |
| `receive(msg, ts)` | When a message is delivered | Updates internal state |
| `reset()` | When LOS is lost | Clears in-flight state |

Every outgoing message must have a `'to'` field containing the recipient node id. The loop stamps each message with the sender's `'from'` id before routing.

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

1. Create `fsm/<YourProtocol>/YourFSM.m` — subclass `NodeFSM`, implement `step`, `receive`, `reset`, expose `last_offset` and `last_delay`.
2. Create `configs/protocols/protocol_your.m` — copy `protocol_base.m`, build and return the `nodes` cell array.
3. Create experiment configs using `protocol_your(ox_A(), ox_B())`.

`run_experiment` and `plot_experiment` require no changes.

## Key Concepts

**Clock model** — `Clock.m` implements a power-law frequency noise oscillator (IEEE 1139-2008). The `h` vector holds `[h₋₂, h₋₁, h₀, h₁, h₂]` for RWFM, Flicker FM, White FM, Flicker PM, and White PM noise. Value-class semantics: always assign the return value (`obj = obj.advance(dt)`).

**Channel** — `Channel.m` wraps precomputed satellite state and applies pluggable propagation effects. Add effects with `channel.add_effect(fn)` where `fn(state)` returns `struct('fwd', dt_s, 'bwd', dt_s)`. The base geometric delay is always included.

**FSM** — `PTPMasterFSM` and `PTPSlaveFSM` implement the IEEE 1588 4-way handshake (SYNC → FOLLOW_UP → DELAY_REQ → DELAY_RESP). Both subclass `NodeFSM`. To add a different protocol, create a new folder under `fsm/` and subclass `NodeFSM`.

**Simulation loop** — Adaptive time-stepping: when a message is in flight, `sim_time` snaps forward to the message delivery time instead of advancing by `dt_los`. This ensures no message is delivered late regardless of the time step.

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
