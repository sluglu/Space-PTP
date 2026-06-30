# Space-PTP

A MATLAB simulator for clock synchronisation protocols (PTP and beyond) in LEO satellite scenarios.

## Structure

```
Space-PTP/
+-- src/
|   +-- main.m                  # Entry point
|   +-- run_experiment.m        # Simulation loop
|   +-- save_results.m          # Save results struct to disk
|   +-- plot_experiment.m       # Plot results (accepts struct or cfg)
+-- configs/
|   +-- base/
|   |   +-- sim_base.m          # Simulation loop parameters (starting point for experiments)
|   +-- experiments/            # Per-experiment configs  (<PROTOCOL>_exp_*.m)
|   |   +-- exp_base.m          # Template
|   +-- protocols/              # Protocol + FSM constructors  (protocol_*.m)
|   |   +-- protocol_base.m     # Template
|   +-- oscillators/            # Clock configs  (ox_*.m)
|   |   +-- ox_base.m           # Template
|   +-- scenarios/              # Orbital scenarios  (sc_*.m)
|       +-- sc_base.m           # Template
+-- FSM/
|   +-- NodeFSM.m               # Abstract FSM interface (subclass for any protocol)
|   +-- PTP/
|       +-- PTPMasterFSM.m      # IEEE 1588 master state machine
|       +-- PTPSlaveFSM.m       # IEEE 1588 slave state machine + PI servo
+-- clock/
|   +-- Clock.m                 # Power-law oscillator (h-2...h2 noise, value class)
+-- channel/
|   +-- Channel.m               # Pluggable propagation delay + Doppler model
+-- orbit/
|   +-- precompute_satellite_data.m   # Satellite Scenario Toolbox wrapper
+-- tools/
|   +-- ProgressTracker.m       # fprintf progress reporter (serial + parfor)
+-- tests/
    +-- test_clock_model.m          # Allan deviation + phase noise validation
    +-- test_PTP_FSM.m              # PTP 4-way handshake correctness
    +-- test_PTP_servo.m            # PI servo convergence (phase + freq offset)
    +-- test_PTP_gaussian_delay.m   # PTP error vs delay asymmetry sweep
    +-- test_satcom_orbit_model.m   # Propagation delay + Doppler validation
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

## Config System

Every config function returns a ready object. Compose them to build an experiment:

```matlab
function cfg = PTP_exp_ocxo_same_plane()
    cfg          = sim_base();            % simulation loop parameters
    cfg.exp.name = mfilename();
    cfg.scenario = sc_same_plane();       % satelliteScenario handle + name
    cfg.nodes    = protocol_ptp(ox_perfect(), ox_ocxo());  % Clock + FSM per node
end
```

| Layer | Function | What it configures |
|-------|----------|--------------------|
| Sim params | `sim_base()` | Simulation loop parameters: time step, LOS handling, message routing |
| Scenario | `sc_*()` | The orbital geometry: satellite orbits, ground station positions, simulation duration |
| Oscillator | `ox_*()` | A single `Clock` object: noise coefficients, initial frequency offset |
| Protocol | `protocol_*(clk, clk)` | `nodes` cell array: one Clock + one FSM per node, plus servo and timing parameters |

All config functions accept name-value overrides for IDE autocomplete:

```matlab
% Oscillator overrides
ox_ocxo(0, 'alpha', 0, 'kw_n_neg1', 4096*4)
ox_perfect(0, 'delta_f0', 1e-3)

% Scenario overrides
sc_same_plane('sim_duration_h', 2, 'dt_orbital', 0.5)

% Simulation loop overrides
sim_base('dt_los', 0.05, 'min_los_duration', 5)

% Protocol overrides (servo, timing, verbosity)
protocol_ptp(clk1, clk2, 'servo_kp', 0.2, 'servo_ki', 0.02)
protocol_ptp(clk1, clk2, 'servo_enabled', false)
```

## Architecture

### Protocol-agnostic simulation loop

`run_experiment` knows nothing about the protocol. It calls the same three methods on every FSM each tick:

| Method | When | What it does |
|--------|------|--------------|
| `step(ts)` | Every LOS tick | Returns outgoing messages; advances internal state |
| `receive(msg, ts)` | Message delivered | Updates internal state |
| `reset()` | LOS lost | Clears in-flight state |

Every message must have a `'to'` field with the recipient node id. The loop stamps `'from'` before routing. This keeps the FSM unaware of addressing, so the same FSM code works for any topology.

After every `step()`, `fsm.servo_y` (fractional frequency correction, dimensionless) is copied to `clock.servo_y` and applied on the next `advance()` call as `servo_y x f0` Hz. The FSM is responsible for keeping `servo_y = 0` until a valid estimate is available; the loop applies it unconditionally.

Results are accumulated per-tick into a results struct. `plot_experiment` and `save_results` only depend on that struct, not on the protocol, so they work unchanged for any new protocol.

### Adding a new protocol

1. Create `FSM/<Protocol>/YourFSM.m` — subclass `NodeFSM`, implement `step`, `receive`, `reset`. Set `servo_y` whenever you have a new frequency estimate; leave at 0 if no servo.
2. Create `configs/protocols/protocol_yours.m` — see `protocol_base.m`.
3. Write experiment configs: `protocol_yours(ox_perfect(), ox_ocxo())`.

`run_experiment` and `plot_experiment` require no changes.

## Key Concepts

### Clock

Power-law frequency noise oscillator (IEEE 1139-2008). Create with `ox_*()`. Value-class: always assign the return value (`clk = clk.advance(dt)`).

| h coefficient | Noise type | Implementation |
|--------------|------------|----------------|
| h-2 | Random Walk FM | Scalar integrator |
| h-1 | Flicker FM | Kasdin-Walter FIR |
| h0 | White FM | White Gaussian draw |
| h1 | Flicker PM | Kasdin-Walter FIR |
| h2 | White PM | White Gaussian draw |

Phase uses trapezoid integration `(f_old + f_new)/2 * dt`. The `kw_n_neg1` parameter sets the FIR filter length for the Flicker FM (h-1) and Flicker PM (h1) noise processes. A longer filter produces accurate flicker noise over a wider range of averaging times: the rule of thumb is `kw_n_neg1 * dt > 2 * tau_max`. In the Allan deviation test (`test_clock_model`), `kw_n_neg1` is increased well above the default so that the simulated ADEV matches theory at long averaging times.

### Channel

Wraps precomputed satellite geometry with pluggable propagation effects.

**Default effects by link type:**

The geometric propagation delay is computed by the MATLAB Satellite Communications Toolbox `latency()` function:

- Space-to-space link: geometric delay only (straight-line light travel time in inertial frame).
- Space-to-ground link: geometric delay plus Sagnac correction. The toolbox accounts for Earth rotation when computing signal travel time to a ground station, so the Sagnac effect is included automatically.

Doppler is computed by the toolbox `dopplershift()` function. It returns fractional df/f0 = v_r/c (dimensionless). Multiply by the carrier frequency to get Hz. Both forward (master to slave) and backward (slave to master) Doppler are stored separately because they differ when the geometry is changing.

**Adding a new channel effect:**

```matlab
ch = Channel(sat_data);
ch = ch.add_effect(@my_effect);
```

An effect function receives a `state` struct with the current geometry and returns delay corrections:

```matlab
function delta = my_effect(state)
    % state.t              simulation time [s]
    % state.fwd_geometric  geometric forward delay [s]
    % state.bwd_geometric  geometric backward delay [s]
    % state.fwd_doppler    fractional forward Doppler [df/f0]
    % state.bwd_doppler    fractional backward Doppler [df/f0]
    % state.pos_master     ECI position of master [3x1, m]
    % state.vel_master     ECI velocity of master [3x1, m/s]
    % state.pos_slave      ECI position of slave  [3x1, m]
    % state.vel_slave      ECI velocity of slave  [3x1, m/s]
    delta = struct('fwd', fwd_delay_correction_s, 'bwd', bwd_delay_correction_s);
end
```

Effects are additive: all registered effects sum into the total forward and backward delay. The `cfg.channel_effects` field is a cell array of such function handles.

### Servo

Any `NodeFSM` subclass can drive the clock servo by writing to `servo_y` (the fractional frequency correction, defined in `NodeFSM`). The simulation loop copies `servo_y` to the clock after every tick. A protocol that has no frequency estimation simply leaves `servo_y = 0`.

`PTPSlaveFSM` implements this using a PI controller that engages after the first complete 4-way handshake:

```
servo_integral += offset * sync_interval
servo_y = -(Kp * offset + Ki * servo_integral)
```

Default gains `kp=0.1`, `ki=0.01` converge in roughly 10 sync cycles. `servo_y` is preserved across LOS outages so the clock continues at its last correction rate during a gap; the integral resets on `reset()` because accumulated state from before the outage is no longer valid.

Configure via `protocol_ptp`:

```matlab
protocol_ptp(clk1, clk2, 'servo_kp', 0.2, 'servo_ki', 0.02)
protocol_ptp(clk1, clk2, 'servo_enabled', false)
```

### Results Struct

Fields returned by `run_experiment`:

| Field | Description |
|-------|-------------|
| `times` | Simulation time [s] |
| `los` | LOS flag (1 / 0) |
| `fwd_delay`, `bwd_delay` | Propagation delays [s] |
| `fwd_doppler`, `bwd_doppler` | Fractional Doppler [df/f0, dimensionless] |
| `nodes{k}` | Per-node: `id`, `real_offset`, `real_freq`, `offset_est`, `delay_est` |
| `real_offset`, `offset_est`, `delay_est` | 2-node convenience aliases |
| `meta` | `exp_name`, `timestamp`, `cfg` |

## Tests

Run individually from the MATLAB command window. Each prints a pass/fail summary and produces plots.

| Test | Validates | Pass criterion |
|------|-----------|----------------|
| `test_clock_model` | OCXO + CSAC noise model | Empirical ADEV within x3 of theory at every tau (soft -- stochastic) |
| `test_PTP_FSM` | IEEE 1588 4-way handshake | >= 10 valid exchanges; delay error < 10%; offset tracking RMS < 10 us |
| `test_PTP_servo` | PI servo convergence | Servo ON: residual drift < 1 ns/s; Servo OFF: offset grows at open-loop rate |
| `test_PTP_gaussian_delay` | PTP error vs delay asymmetry | Log-log slope 1.0 +/- 0.15; amplitude ratio in [0.3, 3.0] |
| `test_satcom_orbit_model` | Orbit + Channel pipeline | Delays plausible, NaN outside LOS, `Channel.compute()` matches interpolants |

`test_clock_model` prints PASS/FAIL per tau but does not call `assert` because ADEV has high Monte Carlo variance at long tau and a single run is not deterministic.

## Delay Effects (TODO)

Add to `cfg.channel_effects` as function handles: `fn(state)` returns `struct('fwd', delta_s, 'bwd', delta_s)`.

| Effect | Magnitude |
|--------|-----------|
| Ionosphere | 1-100 m / c |
| Troposphere | 2-25 m / c |
| Special relativity | ~10 m/day / c |
| General relativity | ~10 m/day / c |
| Hardware delay | 0.3-10 m / c |
