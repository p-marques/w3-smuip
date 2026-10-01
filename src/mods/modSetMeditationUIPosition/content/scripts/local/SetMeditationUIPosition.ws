// Set Meditation UI Position 1.x - 2026, pMarK

struct SSMUIPGeometry
{
    var rootScaleX, rootScaleY, rootX, rootY : float;
    var clockX, clockY, centerX, centerY : float;
    var boundsX, boundsY, boundsWidth, boundsHeight : float;
}

struct SSMUIPPlacement
{
    var valid : bool;
    var x, y : float;
}

function SMUIPInitializeDefaults()
{
    var config : CInGameConfigWrapper;
    config = theGame.GetInGameConfigWrapper();
    if (!config)
        return;

    // An explicit zero or disabled setting must survive reopening and reloads.
    if (config.GetVarValue('SMUIP', 'Enabled') == "")
        config.SetVarValue('SMUIP', 'Enabled', "false");
    if (config.GetVarValue('SMUIP', 'X') == "")
        config.SetVarValue('SMUIP', 'X', "50");
    if (config.GetVarValue('SMUIP', 'Y') == "")
        config.SetVarValue('SMUIP', 'Y', "50");
}

function SMUIPCalculatePlacement(g : SSMUIPGeometry, percentX : float, percentY : float) : SSMUIPPlacement
{
    var result : SSMUIPPlacement;
    var canvasWidth, canvasHeight, deltaX, deltaY : float;
    var minX, maxX, minY, maxY : float;

    result.valid = false;
    canvasWidth = 1920.0f * g.rootScaleX;
    canvasHeight = 1080.0f * g.rootScaleY;
    if (!(canvasWidth > 0.0f && canvasHeight > 0.0f &&
        g.boundsWidth > 0.0f && g.boundsWidth <= canvasWidth &&
        g.boundsHeight > 0.0f && g.boundsHeight <= canvasHeight))
        return result;

    minX = g.rootX - g.boundsX;
    maxX = g.rootX + canvasWidth - g.boundsX - g.boundsWidth;
    minY = g.rootY - g.boundsY;
    maxY = g.rootY + canvasHeight - g.boundsY - g.boundsHeight;

    deltaX = g.rootX + canvasWidth * ClampF(percentX, 0.0f, 100.0f) / 100.0f - g.centerX;
    deltaY = g.rootY + canvasHeight * ClampF(percentY, 0.0f, 100.0f) / 100.0f - g.centerY;
    deltaX = ClampF(deltaX, minX, maxX);
    deltaY = ClampF(deltaY, minY, maxY);

    // Reject unusable/NaN geometry before writing either sprite coordinate.
    if (!(deltaX >= minX && deltaX <= maxX && deltaY >= minY && deltaY <= maxY))
        return result;

    result.x = g.clockX + deltaX / g.rootScaleX;
    result.y = g.clockY + deltaY / g.rootScaleY;
    result.valid = (result.x - result.x == 0.0f && result.y - result.y == 0.0f);
    return result;
}

@wrapMethod(CR4IngameMenu)
function OnConfigUI()
{
    SMUIPInitializeDefaults();
    return wrappedMethod();
}

@addField(CR4MeditationClockMenu)
private var smuipClock : CScriptedFlashSprite;

@addField(CR4MeditationClockMenu)
private var smuipBackdrop : CScriptedFlashSprite;

@addField(CR4MeditationClockMenu)
private var smuipBackdropNativeX : float;

@addField(CR4MeditationClockMenu)
private var smuipBackdropNativeY : float;

@addField(CR4MeditationClockMenu)
private var smuipAnchorOffsetX : float;

@addField(CR4MeditationClockMenu)
private var smuipAnchorOffsetY : float;

@addField(CR4MeditationClockMenu)
private var smuipRefreshMouse : CScriptedFlashFunction;

@addField(CR4MeditationClockMenu)
private var smuipEnabled : bool;

@addField(CR4MeditationClockMenu)
private var smuipReady : bool;

@addField(CR4MeditationClockMenu)
private var smuipX : float;

@addField(CR4MeditationClockMenu)
private var smuipY : float;

@addField(CR4MeditationClockMenu)
private var smuipNativeX : float;

@addField(CR4MeditationClockMenu)
private var smuipNativeY : float;

@wrapMethod(CR4MeditationClockMenu)
function OnConfigUI()
{
    var result : bool;
    var config : CInGameConfigWrapper;

    SMUIPInitializeDefaults();
    if (smuipReady)
    {
        if (smuipBackdrop)
            smuipBackdrop.SetPosition(smuipBackdropNativeX, smuipBackdropNativeY);
        if (smuipClock && smuipRefreshMouse)
        {
            smuipClock.SetPosition(smuipNativeX, smuipNativeY);
            smuipRefreshMouse.InvokeSelf();
        }
    }
    smuipReady = false;
    smuipEnabled = false;
    result = wrappedMethod();

    config = theGame.GetInGameConfigWrapper();
    if (!config || !m_flashModule || m_sleepMode || !canMeditateWait)
        return result;

    smuipEnabled = config.GetVarValue('SMUIP', 'Enabled');
    if (!smuipEnabled)
        return result;

    smuipX = StringToFloat(config.GetVarValue('SMUIP', 'X'));
    smuipY = StringToFloat(config.GetVarValue('SMUIP', 'Y'));
    smuipClock = m_flashModule.GetChildFlashSprite("meditationClock");
    smuipBackdrop = m_flashModule.GetChildFlashSprite("stBg");
    if (!smuipClock || !smuipBackdrop)
        return result;

    smuipRefreshMouse = smuipClock.GetMemberFlashFunction("calcInitStuff");
    smuipNativeX = smuipClock.GetX();
    smuipNativeY = smuipClock.GetY();
    smuipBackdropNativeX = smuipBackdrop.GetX();
    smuipBackdropNativeY = smuipBackdrop.GetY();
    smuipReady = SMUIPApplyPosition();
    return result;
}

@addMethod(CR4MeditationClockMenu)
private function SMUIPApplyPosition() : bool
{
    var rootTransform, clockTransform, backdropTransform : CScriptedFlashObject;
    var rootMatrix, backdropBounds, bounds : CScriptedFlashObject;
    var backdropWidth, backdropHeight : float;
    var g : SSMUIPGeometry;
    var placement : SSMUIPPlacement;

    if (!m_flashModule || !smuipClock || !smuipBackdrop || !smuipRefreshMouse)
        return false;

    rootTransform = m_flashModule.GetMemberFlashObject("transform");
    clockTransform = smuipClock.GetMemberFlashObject("transform");
    if (!rootTransform || !clockTransform)
        return false;

    rootMatrix = rootTransform.GetMemberFlashObject("concatenatedMatrix");
    bounds = clockTransform.GetMemberFlashObject("pixelBounds");
    if (!rootMatrix || !bounds)
        return false;

    // The native canvas is axis-aligned; don't guess at another mod's rotated layout.
    if (rootMatrix.GetMemberFlashNumber("b") != 0.0f || rootMatrix.GetMemberFlashNumber("c") != 0.0f)
        return false;

    g.rootScaleX = rootMatrix.GetMemberFlashNumber("a");
    g.rootScaleY = rootMatrix.GetMemberFlashNumber("d");
    g.rootX = rootMatrix.GetMemberFlashNumber("tx");
    g.rootY = rootMatrix.GetMemberFlashNumber("ty");
    g.clockX = smuipClock.GetX();
    g.clockY = smuipClock.GetY();
    if (!(g.rootScaleX > 0.0f && g.rootScaleY > 0.0f &&
        g.rootScaleX - g.rootScaleX == 0.0f && g.rootScaleY - g.rootScaleY == 0.0f))
        return false;

    if (!smuipReady)
    {
        backdropTransform = smuipBackdrop.GetMemberFlashObject("transform");
        if (!backdropTransform)
            return false;
        backdropBounds = backdropTransform.GetMemberFlashObject("pixelBounds");
        if (!backdropBounds)
            return false;
        backdropWidth = backdropBounds.GetMemberFlashNumber("width");
        backdropHeight = backdropBounds.GetMemberFlashNumber("height");
        if (!(backdropWidth > 0.0f && backdropHeight > 0.0f &&
            backdropWidth - backdropWidth == 0.0f && backdropHeight - backdropHeight == 0.0f))
            return false;

        // Capture once per opening so fading/clipped backdrop bounds cannot move the anchor.
        smuipAnchorOffsetX = (backdropBounds.GetMemberFlashNumber("x") + backdropWidth * 0.5f - g.rootX) / g.rootScaleX - g.clockX;
        smuipAnchorOffsetY = (backdropBounds.GetMemberFlashNumber("y") + backdropHeight * 0.5f - g.rootY) / g.rootScaleY - g.clockY;
        if (!(smuipAnchorOffsetX - smuipAnchorOffsetX == 0.0f && smuipAnchorOffsetY - smuipAnchorOffsetY == 0.0f))
            return false;
    }
    g.centerX = g.rootX + (g.clockX + smuipAnchorOffsetX) * g.rootScaleX;
    g.centerY = g.rootY + (g.clockY + smuipAnchorOffsetY) * g.rootScaleY;
    g.boundsX = bounds.GetMemberFlashNumber("x");
    g.boundsY = bounds.GetMemberFlashNumber("y");
    g.boundsWidth = bounds.GetMemberFlashNumber("width");
    g.boundsHeight = bounds.GetMemberFlashNumber("height");
    placement = SMUIPCalculatePlacement(g, smuipX, smuipY);
    if (!placement.valid)
        return false;

    // Both sprites share the root; preserve their native offset without clamping the backdrop.
    smuipBackdrop.SetPosition(smuipBackdropNativeX + placement.x - smuipNativeX, smuipBackdropNativeY + placement.y - smuipNativeY);
    smuipClock.SetPosition(placement.x, placement.y);
    // Moving the artwork alone leaves the native drag/click center stale.
    smuipRefreshMouse.InvokeSelf();
    return true;
}

@wrapMethod(CR4MeditationClockMenu)
function MovePanelXTo(x : float, time : float)
{
    if (smuipReady)
    {
        if (smuipEnabled && !m_sleepMode && canMeditateWait && SMUIPApplyPosition())
            return;

        // Restore both sprites, including Y, before native X movement resumes.
        if (smuipBackdrop)
            smuipBackdrop.SetPosition(smuipBackdropNativeX, smuipBackdropNativeY);
        if (smuipClock && smuipRefreshMouse)
        {
            smuipClock.SetPosition(smuipNativeX, smuipNativeY);
            smuipRefreshMouse.InvokeSelf();
        }
        smuipReady = false;
    }
    wrappedMethod(x, time);
}
