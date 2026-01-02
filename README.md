# Dual-Bridge Aircraft Boarding Simulation

## Overview

This MATLAB script simulates the boarding process of a commercial aircraft with **63 rows** using a **Dual-Passenger Boarding Bridge (PBB)** configuration. It compares five different boarding strategies to analyze the impact on **Group 1 (Business/Priority) completion time** and **Total Boarding time**.

The simulation utilizes a **Monte Carlo** approach with realistic physical constraints, including passenger reaction times, luggage stowage variability, and seat interference penalties.

## Configuration & Layout

### The Aircraft

* **Total Rows:** 63
* **Aisles:** 2
* **Seats:** 3 per side (Window, Middle, Aisle).

### Bridge Entry Points

* **PBB 1:** Connects at **Row 1**.
* **PBB 2:** Connects at **Row 7** (Start of Economy).

### Passenger Groups & Row Assignments

| Group | Pax Count | Row Range | Bridge Assigned | Description |
| --- | --- | --- | --- | --- |
| **1** | 24 | 1 - 6 | PBB 1 | Business / Priority |
| **4** | 80 | 7 - 24 | PBB 2 | Front Economy |
| **3** | 80 | 25 - 43 | PBB 2 | Middle Economy |
| **2** | 80 | 44 - 63 | PBB 2 | Rear Economy |

> **Note:** The simulation assumes "Back-to-Front" logic for Economy sorting (Group 2 sits in the back, Group 4 in the front).

## Simulation Scenarios

The script runs the following 5 scenarios sequentially:

1. **Sequential (G2-4 Wait):** Bridge 2 (Economy) does not open until all Group 1 passengers have finished entering Bridge 1.
2. **Parallel (Simultaneous):** Both bridges open immediately. Passengers arrive sorted perfectly by group (G1 at Bridge 1; G2  G3  G4 at Bridge 2). This mimics an optimized Back-to-Front flow.
3. **Mixed Arrival (Dual Bridge):** Passengers arrive at the airport randomly but use their correct assigned bridge. This simulates a "free-for-all" arrival pattern sorted only by the gate assignment.
4. **Random (Single Bridge):** A control scenario where the second bridge is disabled. All passengers board randomly through Row 1.
5. **Waves:** A hybrid strategy where Wave 1 consists of Group 1 (Business) and Group 2 (Rear Economy) boarding simultaneously, followed by Wave 2 (Groups 3 & 4).

## Physics & Realism Parameters

To maximize accuracy, the model includes the following variables (approx. 1 tick = 1 second):

* **Variable Stow Time:**
* 30% of pax have no bag (~2s delay).
* 70% of pax have luggage (15–45s random delay).


* **Seat Interference (The "Shuffle"):**
* If a passenger needs a Window seat but the Aisle/Middle seat is occupied, a penalty (`seat_shuffle_time = 25s`) is applied per blocking passenger to simulate standing up and stepping out.


* **Reaction Delay:**
* Passengers do not move instantly when space opens; a random reaction delay (0-2s) creates realistic "stop-and-go" traffic waves.


* **Transfer Penalty:**
* Passengers have a 2% chance of entering the wrong aisle, incurring a 15s penalty to switch.

## How to Run

1. Ensure you have MATLAB installed.
2. Open the script file.
3. Run the script.
4. The simulation will output progress to the Command Window.
5. **Final Results** will display a table comparing all 5 scenarios.

## Output Interpretation

The final table provides three metrics:

1. **Time G1 (min):** How long until the last Group 1 passenger is seated.
2. **Total (min):** How long until the entire plane is seated.
3. **Diff G1 vs S1:** The percentage difference in Group 1 boarding time compared to the Baseline (Scenario 1).
* **Negative %:** Faster than sequential.
* **Positive %:** Slower than sequential.

## Customization

You can adjust the following variables at the top of the script to test different conditions:

* `groups`: Change the number of passengers per group.
* `seat_shuffle_time`: Increase/decrease the penalty for seat interference.
* `prob_wrong_aisle`: Adjust the "confusion" factor.
