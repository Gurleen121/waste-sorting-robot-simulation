-- ================================================================
--  Waste Sorting — COMPLETE FINAL SIMULATION
--  CoppeliaSim Edu V4.10
--
--  FULL SEQUENCE:
--    [1]  Home
--    [2]  Pick Soda_Can from Dirty_Table
--    [3]  Place Soda_Can on Cleaning_Plate
--    [4]  Return Home
--    [5]  Conveyor runs — plate + can slides to end
--    [6]  Pick Blower_Tool
--    [7]  Sweep: Pos1→Pos2→Pos1→Pos2→Pos1 (cleaning motion)
--    [8]  Return Blower_Tool
--    [9]  Home (standby)
--    [10] Pick cleaned Soda_Can from conveyor end position
--    [11] Place on Final_Tray (Clean_Table)
--    [12] Final Home
-- ================================================================

sim = require 'sim'

-- ================================================================
--  SPEED
-- ================================================================
local VEL   = 120
local ACCEL =  40
local JERK  =  80

local function vaj()
    local v = VEL   * math.pi / 180
    local a = ACCEL * math.pi / 180
    local j = JERK  * math.pi / 180
    return {v,v,v,v,v,v}, {a,a,a,a,a,a}, {j,j,j,j,j,j}
end

local function vajSlow()
    local v =  60 * math.pi / 180
    local a =  30 * math.pi / 180
    local j =  60 * math.pi / 180
    return {v,v,v,v,v,v}, {a,a,a,a,a,a}, {j,j,j,j,j,j}
end

-- ================================================================
--  ALL JOINT CONFIGS (radians from Joint Tool)
-- ================================================================

-- Home
local C_HOME = {
     0.043633,
    -0.009591,
     6.274459,
     6.187192,
    -4.79773,
     0.846485
}

-- Pick Soda_Can from Dirty_Table
local C_PICK_CAN = {
     0.20944,
    -0.184123,
     5.201081,
     5.942846,
    -4.745413,
     0.846485
}

-- Place Soda_Can on Cleaning_Plate
local C_PLACE_CAN = {
    -0.602138,
    -0.419743,
     5.174901,
     6.239552,
    -4.745413,
     0.846485
}

-- Pick Blower_Tool
local C_PICK_BLOWER = {
     0.488692,
    -0.053224,
     4.982915,
     6.056293,
    -4.684327,
     0.846485
}

-- Blower sweep position 1 (above can on cleaning plate)
local C_SWEEP_1 = {
    -0.558505,
    -0.768818,
     6.065019,
     5.80322,
    -4.686209,
     0.846485
}

-- Blower sweep position 2 (above can on cleaning plate)
local C_SWEEP_2 = {
    -0.724312,
    -0.498292,
     5.67232,
     5.80322,
    -4.686209,
     0.846485
}

-- Pick cleaned Soda_Can from conveyor end position
local C_PICK_CLEAN = {
    -1.919862,
    -0.1409,
     4.817109,
     6.283185,
    -4.710507,
     0.846485
}

-- Place Soda_Can on Final_Tray (Clean_Table)
local C_PLACE_TRAY = {
    -3.036873,
    -0.149226,
     5.061455,
     6.010914,
    -4.710644,
     0.846485
}

-- ================================================================
--  CONVEYOR
-- ================================================================
local PLATE_SPEED  = 0.10
local PLATE_END    =  0.450
local PLATE_Y      =  0.275
local PLATE_Z      =  0.210
local CAN_PLACE_X  = -0.30215
local CAN_PLACE_Y  =  0.26788
local CAN_PLACE_Z  =  0.28344
local CAN_OFFSET_X = CAN_PLACE_X - (-0.325)  -- +0.02285

-- ================================================================
--  HELPERS
-- ================================================================
local function moveToConfig(jh, config)
    local v,a,j = vaj()
    sim.moveToConfig({
        joints    = jh,
        targetPos = config,
        maxVel    = v,
        maxAccel  = a,
        maxJerk   = j,
    })
end

local function moveToConfigSlow(jh, config)
    local v,a,j = vajSlow()
    sim.moveToConfig({
        joints    = jh,
        targetPos = config,
        maxVel    = v,
        maxAccel  = a,
        maxJerk   = j,
    })
end

local function grip(obj, gripper)
    sim.setObjectParent(obj, gripper, true)
    print("  >> GRIP ON  : " .. sim.getObjectAlias(obj, 1))
end

local function release(obj)
    sim.setObjectParent(obj, sim.handle_world, true)
    print("  >> GRIP OFF : " .. sim.getObjectAlias(obj, 1))
end

local function runConveyor(convScript, sodaCan, cleaningPlate)
    pcall(function() sim.callScriptFunction('setVelocity_', convScript, 0.12) end)
    pcall(function() sim.callScriptFunction('setVelocity',  convScript, 0.12) end)
    print("  >> CONVEYOR STARTED")

    while true do
        local pos  = sim.getObjectPosition(cleaningPlate, sim.handle_world)
        local curX = pos[1]
        local diff = PLATE_END - curX

        if math.abs(diff) < 0.005 then
            sim.setObjectPosition(cleaningPlate, sim.handle_world,
                {PLATE_END, PLATE_Y, PLATE_Z})
            sim.setObjectPosition(sodaCan, sim.handle_world,
                {PLATE_END + CAN_OFFSET_X, CAN_PLACE_Y, CAN_PLACE_Z})
            break
        end

        local sign = diff > 0 and 1 or -1
        local step = sign * math.min(math.abs(diff),
            PLATE_SPEED * sim.getSimulationTimeStep())
        local newX = curX + step

        sim.setObjectPosition(cleaningPlate, sim.handle_world,
            {newX, PLATE_Y, PLATE_Z})
        sim.setObjectPosition(sodaCan, sim.handle_world,
            {newX + CAN_OFFSET_X, CAN_PLACE_Y, CAN_PLACE_Z})

        sim.switchThread()
    end

    pcall(function() sim.callScriptFunction('setVelocity_', convScript, 0) end)
    pcall(function() sim.callScriptFunction('setVelocity',  convScript, 0) end)
    print("  >> CONVEYOR STOPPED at X=" .. PLATE_END)
end

-- ================================================================
--  MAIN THREAD
-- ================================================================
function sysCall_thread()

    local jh = {}
    for i = 1, 6 do
        jh[i] = sim.getObject('../joint', {index = i-1})
    end

    local gripperHandle  = sim.getObject('../connection/BaxterVacuumCup')
    local sodaCan        = sim.getObject('/Soda_Can')
    local blowerTool     = sim.getObject('/Blower_Tool')
    local cleaningPlate  = sim.getObject('/Cleaning_Plate')
    local conveyorHandle = sim.getObject('/conveyor')
    local conveyorScript = sim.getScript(
        sim.scripttype_customizationscript, conveyorHandle)

    print("=====================================================")
    print("  Waste Sorting — COMPLETE SIMULATION")
    print("  All 3 phases loaded and ready")
    print("=====================================================")

    -- ============================================================
    --  PHASE 1 — Pick can, place on plate, run conveyor
    -- ============================================================

    print("  [01/12] Home")
    moveToConfig(jh, C_HOME)
    sim.wait(1.0)

    print("  [02/12] Pick Soda_Can")
    moveToConfig(jh, C_PICK_CAN)
    sim.wait(0.5)
    grip(sodaCan, gripperHandle)
    sim.wait(0.5)

    print("  [03/12] Place on Cleaning_Plate")
    moveToConfig(jh, C_PLACE_CAN)
    sim.wait(0.5)
    release(sodaCan)
    sim.wait(0.5)

    print("  [04/12] Return Home")
    moveToConfig(jh, C_HOME)
    sim.wait(0.5)

    -- ============================================================
    --  PHASE 2 — Pick blower, sweep over can, return blower
    --  (happens BEFORE conveyor — can is still on cleaning plate)
    -- ============================================================

    print("  [05/12] Pick Blower_Tool")
    moveToConfig(jh, C_PICK_BLOWER)
    sim.wait(0.5)
    grip(blowerTool, gripperHandle)
    sim.wait(0.5)

    print("  [06/12] Blower sweep — cleaning motion over can")
    moveToConfigSlow(jh, C_SWEEP_1)
    sim.wait(0.01)
    moveToConfigSlow(jh, C_SWEEP_2)
    sim.wait(0.01)
    moveToConfigSlow(jh, C_SWEEP_1)
    sim.wait(0.01)
    moveToConfigSlow(jh, C_SWEEP_2)
    sim.wait(0.01)
    moveToConfigSlow(jh, C_SWEEP_1)
    sim.wait(0.01)

    print("  [07/12] Return Blower_Tool")
    moveToConfig(jh, C_PICK_BLOWER)
    sim.wait(0.5)
    release(blowerTool)
    sim.wait(0.5)

    print("  [08/12] Home standby")
    moveToConfig(jh, C_HOME)
    sim.wait(1.0)

    -- ============================================================
    --  PHASE 2B — Conveyor moves cleaned can to pickup position
    -- ============================================================

    print("  [09/12] Conveyor running...")
    runConveyor(conveyorScript, sodaCan, cleaningPlate)
    sim.wait(1.0)

    -- ============================================================
    --  PHASE 3 — Pick cleaned can, place on Final_Tray
    -- ============================================================

    print("  [10/12] Pick cleaned Soda_Can from conveyor")
    moveToConfig(jh, C_PICK_CLEAN)
    sim.wait(0.5)
    grip(sodaCan, gripperHandle)
    sim.wait(0.5)

    print("  [11/12] Place on Final_Tray")
    moveToConfig(jh, C_PLACE_TRAY)
    sim.wait(0.5)
    release(sodaCan)
    sim.wait(0.5)

    print("  [12/12] Final Home")
    moveToConfig(jh, C_HOME)
    sim.wait(1.0)

    print("=====================================================")
    print("  SIMULATION COMPLETE!")
    print("  Cleaned Soda_Can is on the Final_Tray.")
    print("  Blower_Tool is back on Dirty_Table.")
    print("=====================================================")
end
