# Technical Methodology
## Waste Sorting Robot — Orangewood 6-DOF Manipulator

---

## 1. System Overview

The experiment involved programming an Orangewood 6-DOF collaborative robotic manipulator to perform a simplified waste-handling workflow on a simulated conveyor line.

The manipulator was equipped with a **vacuum gripper** operating via an electro-pneumatic system — compressed air generates suction to hold objects, and vacuum venting releases them.

The robot was controlled using the **Orangewood graphical robot control interface**, supporting:
- Joint space control (individual J1–J6 control)
- Cartesian control (X, Y, Z, Rx, Ry, Rz)
- Waypoint creation and task sequencing

---

## 2. Robot Configuration

### Degrees of Freedom

| Joint | Name | Role |
|-------|------|------|
| J1 | Base | Full horizontal rotation |
| J2 | Shoulder | Arm elevation |
| J3 | Elbow | Arm extension/retraction |
| J4 | Wrist 1 | Pitch |
| J5 | Wrist 2 | Yaw |
| J6 | Wrist 3 | Roll / end-effector orientation |

6 revolute joints → full position + orientation control of TCP in 3D space.

### End Effector

```
Compressed Air → Vacuum Generator → Suction Cup Contact → Object Held by Pressure Difference
```

Suitable for flat surfaces (soda can tops, cylindrical surfaces). Irregular/angular surfaces cannot be picked reliably.

---

## 3. Kinematic Analysis — RoboAnalyzer

### 3.1 DOF Analysis

The Orangewood manipulator was studied as a 6-DOF serial robot in RoboAnalyzer. Understanding DOF helped determine reachable workspace, joint constraints, and feasible pick-and-place configurations.

### 3.2 Forward Kinematics

```
Input  : Joint angles (J1, J2, J3, J4, J5, J6)
Output : End-effector pose (X, Y, Z, Rx, Ry, Rz)
```

Forward kinematics was computed in RoboAnalyzer before hardware execution to:
- Understand how joint changes influence TCP movement
- Confirm feasible joint configurations for pick-and-place operations
- Reduce trial-and-error during physical operation

---

## 4. Control Interface

### Joint Space Control
Individual joint jogging (J1–J6) via sliders — used to **teach robot poses**.

### Cartesian Control
TCP positioning in X, Y, Z, Rx, Ry, Rz — used for **precise placement**.

### Gravity Mode
Motor resistance reduced — user physically guides arm to record poses by hand.

---

## 5. Initial Robot Setup

1. Power on controller via red power knob
2. Launch Orangewood robot control interface
3. Wait for interface to load
4. Perform joint calibration to bring robot to reference position
5. Activate system via Power On in GUI

Calibration ensures internal joint encoders match actual physical joint positions.

---

## 6. Task Application — Waste Sorting Conveyor Scenario

### Goal
Simulate a recycling conveyor line cleaning operation. In real facilities, debris on containers damages processing machines. The robot performs cleaning and sorting before recycling.

### Step-by-Step

**Step 1 — Home Position**
Robot begins in vertical upright configuration. Ensures safe startup, avoids collisions.

**Step 2 — Pick Waste Object**
Soda can placed in designated pickup area. Robot moves to pickup → activates vacuum → picks can.

**Step 3 — Transport to Cleaning Area**
Robot carries can to cleaning zone, places on designated surface.

**Step 4 — Pick Cleaning Tool**
Blower tool (paper cup) picked — represents mechanism to blow dust off container.

**Step 5 — Dust Removal Motion**
Blower moved above can. Back-and-forth sweep motion executed over can to simulate air cleaning from multiple directions.

**Step 6 — Tool Placement**
Blower tool returned to original location. Robot returns to upright standby pose.

**Step 7 — Conveyor Simulation**
Conveyor belt moves cleaned can to new position. Robot detects new location, moves to pickup, activates vacuum, picks cleaned can.

**Step 8 — Final Placement**
Robot moves object to recycling/clean output area and releases it.

---

## 7. Waypoint Programming

Each waypoint stores:
- Joint angles (J1–J6 in radians)
- End effector pose
- Gripper state (vacuum on/off)

Waypoints organized into sequential execution program.

### Measured Joint Configs (Simulation — CoppeliaSim)

| Pose | J1 | J2 | J3 | J4 | J5 | J6 |
|------|----|----|----|----|----|----|
| Home | 0.043633 | -0.009591 | 6.274459 | 6.187192 | -4.79773 | 0.846485 |
| Pick can | 0.20944 | -0.184123 | 5.201081 | 5.942846 | -4.745413 | 0.846485 |
| Place on plate | -0.602138 | -0.419743 | 5.174901 | 6.239552 | -4.745413 | 0.846485 |
| Pick blower | 0.488692 | -0.053224 | 4.982915 | 6.056293 | -4.684327 | 0.846485 |
| Sweep pos 1 | -0.558505 | -0.768818 | 6.065019 | 5.80322 | -4.686209 | 0.846485 |
| Sweep pos 2 | -0.724312 | -0.498292 | 5.67232 | 5.80322 | -4.686209 | 0.846485 |
| Pick cleaned can | -1.919862 | -0.1409 | 4.817109 | 6.283185 | -4.710507 | 0.846485 |
| Place on tray | -3.036873 | -0.149226 | 5.061455 | 6.010914 | -4.710644 | 0.846485 |

---

## 8. Trajectory Behaviour

The robot automatically determines path between waypoints using **joint-space interpolation** — the controller computes smooth joint motion between poses. If intermediate constraints are required, additional waypoints must be inserted.

---

## 9. Speed Control

Speed intentionally reduced to ~30% (120 deg/s) to:
- Observe joint movement clearly
- Prevent sudden motion
- Ensure safe operation
- Ease trajectory debugging

---

## 10. Motor Behaviour (Hardware Observation)

On power-on, brief motor torque correction occurs — motors attempt to hold calibrated joint position. Normal behavior related to servo motor torque control and encoder feedback stabilization.

---

## 11. Safety Measures

- **1-meter safety zone** maintained around robot at all times
- **Emergency Stop (E-Stop)** accessible throughout operation
- Robot powered down only after returning to calibrated home position
- Speed reduced throughout to prevent sudden motion

---

## 12. Simulation Implementation Notes

### Gripper Simulation
`sim.setObjectParent(obj, gripper, true)` — attaches object to TCP (vacuum ON)
`sim.setObjectParent(obj, sim.handle_world, true)` — releases to world (vacuum OFF)

### Conveyor Simulation
Cleaning plate and can moved programmatically along X axis each simulation frame:
```lua
sim.setObjectPosition(cleaningPlate, sim.handle_world, {newX, PLATE_Y, PLATE_Z})
sim.setObjectPosition(sodaCan, sim.handle_world, {newX + offsetX, CAN_Y, CAN_Z})
```
Belt texture animation controlled via the conveyor model's built-in customization script.

### Motion Control
```lua
sim.moveToConfig({
    joints    = jh,
    targetPos = config,   -- radians, from Joint Tool measurement
    maxVel    = {v,v,v,v,v,v},
    maxAccel  = {a,a,a,a,a,a},
    maxJerk   = {j,j,j,j,j,j},
})
```
