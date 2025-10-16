-- First Person Aim Assistance System with Player Highlights
-- Place in a LocalScript in StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Configuration
local HARD_LOCK_KEY = Enum.KeyCode.Z
local CLICK_LOCK_TOGGLE_KEY = Enum.KeyCode.X
local FREE_CAM_KEY = Enum.KeyCode.Period
local MOUSE_BUTTON = Enum.UserInputType.MouseButton1
local HIGHLIGHT_ENABLED = true

local currentTarget = nil
local isHardLockEnabled = false
local isMouseHeld = false
local isClickLockEnabled = false
local isFreeCamEnabled = false
local playerHighlights = {}

-- Free cam variables
local freeCamConnection = nil
local originalCameraType = nil
local originalCameraCFrame = nil
local freeCamSpeed = 5
local freeCamMouseSensitivity = 0.5
local freeCamInputs = {
    W = false,
    A = false,
    S = false,
    D = false,
    E = false,
    Q = false
}

-- Team check function (modify based on your game's team system)
local function isEnemy(otherPlayer)
    -- Method 1: Check if players are on different teams
    if player.Team and otherPlayer.Team then
        return player.Team ~= otherPlayer.Team
    end
    
    -- Method 2: Check for custom team tags (modify based on your game)
    local playerCharacter = player.Character
    local otherCharacter = otherPlayer.Character
    
    if playerCharacter and otherCharacter then
        -- Example: Check for team tags in humanoid
        local playerHumanoid = playerCharacter:FindFirstChild("Humanoid")
        local otherHumanoid = otherCharacter:FindFirstChild("Humanoid")
        
        if playerHumanoid and otherHumanoid then
            -- Check if humanoids have team properties
            if playerHumanoid:GetAttribute("Team") and otherHumanoid:GetAttribute("Team") then
                return playerHumanoid:GetAttribute("Team") ~= otherHumanoid:GetAttribute("Team")
            end
        end
        
        -- Method 3: Check for team tags in player attributes
        if player:GetAttribute("Team") and otherPlayer:GetAttribute("Team") then
            return player:GetAttribute("Team") ~= otherPlayer:GetAttribute("Team")
        end
    end
    
    -- Method 4: If no team system detected, assume all players are enemies
    -- Change this to return false if you want to only target enemies when teams are defined
    return true
end

-- Player Highlighting System Functions (moved to top)
local function removePlayerHighlight(otherPlayer)
    if playerHighlights[otherPlayer] then
        if playerHighlights[otherPlayer].Highlight then
            playerHighlights[otherPlayer].Highlight:Destroy()
        end
        if playerHighlights[otherPlayer].Billboard then
            playerHighlights[otherPlayer].Billboard:Destroy()
        end
        playerHighlights[otherPlayer] = nil
    end
end

local function updateTeamColors(otherPlayer)
    if not HIGHLIGHT_ENABLED then return end
    if not playerHighlights[otherPlayer] then return end
    if not playerHighlights[otherPlayer].Highlight then return end
    
    local highlight = playerHighlights[otherPlayer].Highlight
    
    -- Update highlight color based on team
    if otherPlayer.Team then
        highlight.FillColor = otherPlayer.Team.TeamColor.Color
        highlight.OutlineColor = otherPlayer.Team.TeamColor.Color
    else
        -- Default colors for no team
        if isEnemy(otherPlayer) then
            highlight.FillColor = Color3.fromRGB(255, 50, 50) -- Red for enemies
            highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
        else
            highlight.FillColor = Color3.fromRGB(50, 150, 255) -- Blue for allies
            highlight.OutlineColor = Color3.fromRGB(50, 150, 255)
        end
    end
end

local function createPlayerHighlight(otherPlayer)
    if not HIGHLIGHT_ENABLED then return end
    
    local character = otherPlayer.Character
    if not character then return end
    
    -- Remove existing highlight if it exists
    removePlayerHighlight(otherPlayer)
    
    -- Wait for character to fully load
    wait(0.5)
    
    -- Check if character still exists
    if not otherPlayer.Character then return end
    
    -- Create Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "PlayerHighlight"
    highlight.Parent = character
    
    -- Create BillboardGui for text display
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerInfo"
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.ExtentsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = character
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "InfoText"
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Text = "Loading..."
    textLabel.Parent = billboard
    
    -- Set initial highlight color based on team
    updateTeamColors(otherPlayer)
    
    playerHighlights[otherPlayer] = {
        Highlight = highlight,
        Billboard = billboard,
        TextLabel = textLabel
    }
end

local function updatePlayerInfo(otherPlayer)
    if not HIGHLIGHT_ENABLED then return end
    if not playerHighlights[otherPlayer] then return end
    
    local character = otherPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local head = character:FindFirstChild("Head")
    
    if humanoid and head then
        local health = math.floor(humanoid.Health)
        local maxHealth = math.floor(humanoid.MaxHealth)
        local distance = math.floor((head.Position - camera.CFrame.Position).Magnitude)
        
        local textLabel = playerHighlights[otherPlayer].TextLabel
        textLabel.Text = otherPlayer.Name .. " | " .. health .. "/" .. maxHealth .. " | " .. distance .. "m"
        
        -- Update color based on health
        if health / maxHealth < 0.3 then
            textLabel.TextColor3 = Color3.fromRGB(255, 50, 50) -- Red for low health
        elseif health / maxHealth < 0.7 then
            textLabel.TextColor3 = Color3.fromRGB(255, 255, 50) -- Yellow for medium health
        else
            textLabel.TextColor3 = Color3.fromRGB(50, 255, 50) -- Green for high health
        end
    end
end

-- Function to verify and update all ESP team colors
local function verifyAllTeamColors()
    if not HIGHLIGHT_ENABLED then return end
    
    for otherPlayer, highlightData in pairs(playerHighlights) do
        if otherPlayer and highlightData.Highlight then
            -- Update team colors
            updateTeamColors(otherPlayer)
            
            -- Also update player info to ensure everything is synchronized
            if otherPlayer.Character then
                updatePlayerInfo(otherPlayer)
            end
        end
    end
    
    print("Team color verification completed - " .. #Players:GetPlayers() .. " players checked")
end

-- Free Cam Functions
local function enableFreeCam()
    if isFreeCamEnabled then return end
    
    isFreeCamEnabled = true
    
    -- Save original camera state
    originalCameraType = camera.CameraType
    originalCameraCFrame = camera.CFrame
    
    -- Set camera to scriptable
    camera.CameraType = Enum.CameraType.Scriptable
    
    -- Reset free cam inputs
    for key, _ in pairs(freeCamInputs) do
        freeCamInputs[key] = false
    end
    
    -- Create free cam update loop
    freeCamConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not isFreeCamEnabled then return end
        
        local moveVector = Vector3.new(0, 0, 0)
        
        -- Calculate movement based on inputs
        if freeCamInputs.W then moveVector = moveVector + camera.CFrame.LookVector end
        if freeCamInputs.S then moveVector = moveVector - camera.CFrame.LookVector end
        if freeCamInputs.D then moveVector = moveVector + camera.CFrame.RightVector end
        if freeCamInputs.A then moveVector = moveVector - camera.CFrame.RightVector end
        if freeCamInputs.E then moveVector = moveVector + Vector3.new(0, 1, 0) end
        if freeCamInputs.Q then moveVector = moveVector + Vector3.new(0, -1, 0) end
        
        -- Normalize and apply speed
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit * freeCamSpeed
        end
        
        -- Apply movement
        camera.CFrame = camera.CFrame + (moveVector * deltaTime)
    end)
    
    updateStatusDisplay()
    print("Free cam enabled - Use WASD to move, Q/E for up/down, Mouse to look around")
end

local function disableFreeCam()
    if not isFreeCamEnabled then return end
    
    isFreeCamEnabled = false
    
    -- Disconnect the update loop
    if freeCamConnection then
        freeCamConnection:Disconnect()
        freeCamConnection = nil
    end
    
    -- Restore original camera state
    if originalCameraType then
        camera.CameraType = originalCameraType
    end
    if originalCameraCFrame then
        camera.CFrame = originalCameraCFrame
    end
    
    -- Reset inputs
    for key, _ in pairs(freeCamInputs) do
        freeCamInputs[key] = false
    end
    
    updateStatusDisplay()
    print("Free cam disabled")
end

local function toggleFreeCam()
    if isFreeCamEnabled then
        disableFreeCam()
    else
        enableFreeCam()
    end
end

-- Handle free cam mouse movement
local function onFreeCamInput(input, gameProcessed)
    if not isFreeCamEnabled or gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        -- Rotate camera based on mouse movement
        local delta = input.Delta * freeCamMouseSensitivity
        local currentCF = camera.CFrame
        
        -- Yaw (left/right)
        local yaw = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -delta.X * math.pi / 180)
        
        -- Pitch (up/down) - limit to avoid flipping
        local rightVector = currentCF.RightVector
        local pitch = CFrame.fromAxisAngle(rightVector, -delta.Y * math.pi / 180)
        
        camera.CFrame = currentCF * yaw * pitch
    end
end

-- Handle player respawns
local function setupPlayerRespawnHandler(otherPlayer)
    otherPlayer.CharacterAdded:Connect(function(character)
        wait(1) -- Wait for character to fully load
        createPlayerHighlight(otherPlayer)
    end)
    
    otherPlayer.CharacterRemoving:Connect(function(character)
        removePlayerHighlight(otherPlayer)
    end)
end

-- Create status display
local function createStatusDisplay()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimAssistStatus"
    screenGui.Parent = player.PlayerGui
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "StatusText"
    textLabel.Parent = screenGui
    textLabel.Size = UDim2.new(0, 300, 0, 40) -- Increased width for free cam status
    textLabel.Position = UDim2.new(0, 10, 1, -50) -- Bottom left
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextSize = 18
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.Text = "Hard Lock: OFF | Click Lock: OFF | Free Cam: OFF"
    
    return textLabel
end

local statusDisplay = createStatusDisplay()

-- Function to update status display
local function updateStatusDisplay()
    local statusText = "Hard Lock: "
    
    if isHardLockEnabled then
        statusText = statusText .. "ON"
    else
        statusText = statusText .. "OFF"
    end
    
    statusText = statusText .. " | Click Lock: "
    
    if isClickLockEnabled then
        statusText = statusText .. "ON"
    else
        statusText = statusText .. "OFF"
    end
    
    statusText = statusText .. " | Free Cam: "
    
    if isFreeCamEnabled then
        statusText = statusText .. "ON"
        statusDisplay.TextColor3 = Color3.fromRGB(255, 165, 0) -- Orange for free cam
    elseif isMouseHeld and isClickLockEnabled then
        statusText = statusText .. " (ACTIVE)"
        statusDisplay.TextColor3 = Color3.fromRGB(255, 255, 50) -- Yellow for active tracking
    elseif isHardLockEnabled then
        statusDisplay.TextColor3 = Color3.fromRGB(50, 255, 50) -- Green for hard lock
    elseif isClickLockEnabled then
        statusDisplay.TextColor3 = Color3.fromRGB(50, 150, 255) -- Blue for click lock
    else
        statusDisplay.TextColor3 = Color3.fromRGB(255, 50, 50) -- Red for all off
    end
    
    statusDisplay.Text = statusText
end

-- Function to find target nearest to mouse and distance
local function findNearestTargetToMouse()
    local bestTarget = nil
    local bestScore = math.huge -- Lower score is better
    local mousePos = UserInputService:GetMouseLocation()
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            -- Check if this player is an enemy
            if isEnemy(otherPlayer) then
                local humanoid = otherPlayer.Character:FindFirstChild("Humanoid")
                local head = otherPlayer.Character:FindFirstChild("Head")
                
                if humanoid and humanoid.Health > 0 and head then
                    -- Convert world position to screen position
                    local screenPoint, onScreen = workspace.CurrentCamera:WorldToScreenPoint(head.Position)
                    
                    if onScreen then
                        -- Calculate distance from mouse to target on screen
                        local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
                        local screenDistance = (mousePos - screenPos).Magnitude
                        
                        -- Calculate actual world distance
                        local worldDistance = (camera.CFrame.Position - head.Position).Magnitude
                        
                        -- Combined score (screen distance weighted more heavily)
                        local score = screenDistance + (worldDistance / 100) -- Adjust weight as needed
                        
                        if score < bestScore then
                            bestScore = score
                            bestTarget = head
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- Hard lock toggle function
local function toggleHardLock()
    if isFreeCamEnabled then return end -- Disable aim assist in free cam
    
    isHardLockEnabled = not isHardLockEnabled
    
    if isHardLockEnabled then
        -- Turn on hard lock and find target nearest to mouse
        currentTarget = findNearestTargetToMouse()
        if not currentTarget then
            -- No valid target found, turn it back off
            isHardLockEnabled = false
        end
    else
        -- Turn off hard lock
        currentTarget = nil
    end
    
    updateStatusDisplay()
end

-- Click lock toggle function
local function toggleClickLock()
    if isFreeCamEnabled then return end -- Disable aim assist in free cam
    
    isClickLockEnabled = not isClickLockEnabled
    
    if not isClickLockEnabled then
        -- If turning off click lock, also release mouse hold
        isMouseHeld = false
        if not isHardLockEnabled then
            currentTarget = nil
        end
    end
    
    updateStatusDisplay()
end

-- Mouse hold functions
local function startMouseHold()
    if isFreeCamEnabled then return end -- Disable aim assist in free cam
    
    if isClickLockEnabled then
        isMouseHeld = true
        if not isHardLockEnabled then
            -- Only find target if hard lock isn't already active
            currentTarget = findNearestTargetToMouse()
        end
        updateStatusDisplay()
    end
end

local function stopMouseHold()
    if isFreeCamEnabled then return end -- Disable aim assist in free cam
    
    if isClickLockEnabled then
        isMouseHeld = false
        if not isHardLockEnabled then
            -- Only clear target if hard lock isn't active
            currentTarget = nil
        end
        updateStatusDisplay()
    end
end

-- Hard aim function
local function hardAimToTarget(targetPart)
    if not targetPart or isFreeCamEnabled then return end -- Disable aim assist in free cam
    
    local currentCFrame = camera.CFrame
    local targetPosition = targetPart.Position
    
    -- Calculate direction to target and instantly aim
    local direction = (targetPosition - currentCFrame.Position).Unit
    local targetCFrame = CFrame.lookAt(currentCFrame.Position, currentCFrame.Position + direction)
    camera.CFrame = targetCFrame
end

-- Initialize highlights for existing players
for _, otherPlayer in pairs(Players:GetPlayers()) do
    if otherPlayer ~= player then
        if otherPlayer.Character then
            createPlayerHighlight(otherPlayer)
        end
        setupPlayerRespawnHandler(otherPlayer)
    end
end

-- Handle new players joining
Players.PlayerAdded:Connect(function(otherPlayer)
    if otherPlayer ~= player then
        otherPlayer.CharacterAdded:Connect(function(character)
            wait(1) -- Wait for character to fully load
            createPlayerHighlight(otherPlayer)
        end)
        setupPlayerRespawnHandler(otherPlayer)
    end
end)

-- Handle players leaving
Players.PlayerRemoving:Connect(function(otherPlayer)
    removePlayerHighlight(otherPlayer)
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == HARD_LOCK_KEY then
        toggleHardLock()
    elseif input.KeyCode == CLICK_LOCK_TOGGLE_KEY then
        toggleClickLock()
    elseif input.KeyCode == FREE_CAM_KEY then
        toggleFreeCam()
    elseif input.UserInputType == MOUSE_BUTTON then
        startMouseHold()
    end
    
    -- Free cam movement inputs
    if isFreeCamEnabled then
        if input.KeyCode == Enum.KeyCode.W then
            freeCamInputs.W = true
        elseif input.KeyCode == Enum.KeyCode.A then
            freeCamInputs.A = true
        elseif input.KeyCode == Enum.KeyCode.S then
            freeCamInputs.S = true
        elseif input.KeyCode == Enum.KeyCode.D then
            freeCamInputs.D = true
        elseif input.KeyCode == Enum.KeyCode.E then
            freeCamInputs.E = true
        elseif input.KeyCode == Enum.KeyCode.Q then
            freeCamInputs.Q = true
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == MOUSE_BUTTON then
        stopMouseHold()
    end
    
    -- Free cam movement inputs
    if isFreeCamEnabled then
        if input.KeyCode == Enum.KeyCode.W then
            freeCamInputs.W = false
        elseif input.KeyCode == Enum.KeyCode.A then
            freeCamInputs.A = false
        elseif input.KeyCode == Enum.KeyCode.S then
            freeCamInputs.S = false
        elseif input.KeyCode == Enum.KeyCode.D then
            freeCamInputs.D = false
        elseif input.KeyCode == Enum.KeyCode.E then
            freeCamInputs.E = false
        elseif input.KeyCode == Enum.KeyCode.Q then
            freeCamInputs.Q = false
        end
    end
end)

-- Free cam mouse movement
UserInputService.InputChanged:Connect(onFreeCamInput)

-- Main update loops
RunService.RenderStepped:Connect(function()
    updateStatusDisplay()
    
    -- Check if we should be tracking (only if not in free cam)
    if not isFreeCamEnabled then
        local shouldTrack = isHardLockEnabled or (isMouseHeld and isClickLockEnabled)
        
        if shouldTrack then
            if currentTarget and currentTarget.Parent then
                hardAimToTarget(currentTarget)
            else
                -- Target became invalid or we need to find initial target for mouse hold
                currentTarget = findNearestTargetToMouse()
                if not currentTarget then
                    -- No valid targets
                    if isMouseHeld and not isHardLockEnabled then
                        isMouseHeld = false
                    end
                    updateStatusDisplay()
                end
            end
        end
    end
    
    -- Update player info displays
    for otherPlayer, highlightData in pairs(playerHighlights) do
        if otherPlayer.Character and highlightData.TextLabel then
            updatePlayerInfo(otherPlayer)
        end
    end
end)

-- Clean up if target becomes invalid
RunService.Heartbeat:Connect(function()
    if not isFreeCamEnabled then
        local shouldTrack = isHardLockEnabled or (isMouseHeld and isClickLockEnabled)
        if shouldTrack and currentTarget and not currentTarget.Parent then
            currentTarget = findNearestTargetToMouse()
            if not currentTarget then
                if isMouseHeld and not isHardLockEnabled then
                    isMouseHeld = false
                end
                updateStatusDisplay()
            end
        end
    end
end)

-- 5-second team color verification loop
spawn(function()
    while true do
        wait(5) -- Wait 5 seconds between checks
        verifyAllTeamColors()
    end
end)

print("Dual Aim Assist System with ESP and Free Cam loaded:")
print("- Press Z to toggle hard lock (automatic targeting)")
print("- Press X to toggle click lock (hold left click to track)")
print("- Press . to toggle free cam mode")
print("- Free Cam: WASD to move, Q/E for up/down, Mouse to look around")
print("- Player highlights show team colors, health, and distance")
print("- Team colors verified every 5 seconds")
print("- System will only target enemies, not teammates")