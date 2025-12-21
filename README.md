# SPACE-PTP-model
A MATLAB model for simulating PTP synchronization scheme in orbital scenarios.

Components implemented :
- clock_model + noise_injection : power law oscillator model
- FSM : PTP state machine model
- orbit_model : legacy ideal orbit model + orbit propagator from satcom toolbox
- node : parent object for clock and FSM (sattelites/ground station)
- tests : tests scripts for clock_model, FSM, orbit_model (legacy and satcom)
- experiment#1 : validation of PTP state machine model (does the model behave like the math)
- experiment#2 : Full sim (PTP FSM + clock model + legacy orbit model, no doppler shift)
- experiment#3 : Full sim (PTP FSM + clock model + satcom orbit propagator, with doppler shift)
- config system

TODO : 
- delay effect to add :
    - Ionosphere : 1 – 100 m
    - Troposphere : 2 – 25 m
    - Relativity (Clock) : ~10 m (adj. daily)
- other delay effect : 
    - Multipath : 0.5 – 10 m
    - Hardware Delay : 0.3 – 10 m


