# SPACE-PTP-model
A MATLAB model for simulating PTP synchronization scheme in orbital scenarios.

Components implemented :
- clock_model + noise_injection : power law oscillator model
- FSM : PTP state machine model
- orbit_model : legacy ideal orbit model (currently using orbit propagator from satcom toolbox for exp3)
- node : parent object for clock and FSM (sattelites/ground station)
- tests : tests scripts for clock_model, FSM, orbit_model (ideal and propagator)
- experiment#1 : validation of PTP state machine model (does the model behave like the math)
- experiment#2 : Full sim (PTP FSM + clock model + legacy orbit model, no doppler shift)


TODO : 
- experiment#3 : Full sim (PTP FSM + clock model + satcom orbit propagator, with doppler shift)


