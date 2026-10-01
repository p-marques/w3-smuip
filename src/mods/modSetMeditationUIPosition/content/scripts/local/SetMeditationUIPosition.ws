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

    if (config.GetVarValue('SMUIP', 'HideCloseButton') == "")
        config.SetVarValue('SMUIP', 'HideCloseButton', "false");
    if (config.GetVarValue('SMUIP', 'Scale') == "")
        config.SetVarValue('SMUIP', 'Scale', "100");

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

@addField(CR4MeditationClockMenu)
private var smuipScale : float;

@addField(CR4MeditationClockMenu)
private var smuipClockScaleX : float;

@addField(CR4MeditationClockMenu)
private var smuipClockScaleY : float;

@addField(CR4MeditationClockMenu)
private var smuipBackdropScaleX : float;

@addField(CR4MeditationClockMenu)
private var smuipBackdropScaleY : float;

@wrapMethod(CR4MeditationClockMenu)
function OnConfigUI()
{
    var result : bool;
    var config : CInGameConfigWrapper;

    SMUIPInitializeDefaults();
    if (smuipReady)
    {
        if (smuipBackdrop)
        {
            smuipBackdrop.SetXScale(smuipBackdropScaleX);
            smuipBackdrop.SetYScale(smuipBackdropScaleY);
            smuipBackdrop.SetPosition(smuipBackdropNativeX, smuipBackdropNativeY);
        }
        if (smuipClock && smuipRefreshMouse)
        {
            smuipClock.SetXScale(smuipClockScaleX);
            smuipClock.SetYScale(smuipClockScaleY);
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

    smuipScale = StringToFloat(config.GetVarValue('SMUIP', 'Scale'));
    if (!(smuipScale - smuipScale == 0.0f))
        return result;
    smuipScale = ClampF(smuipScale, 50.0f, 100.0f) / 100.0f;
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
    smuipClockScaleX = smuipClock.GetXScale();
    smuipClockScaleY = smuipClock.GetYScale();
    smuipBackdropScaleX = smuipBackdrop.GetXScale();
    smuipBackdropScaleY = smuipBackdrop.GetYScale();
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

    if (!(smuipClockScaleX > 0.0f && smuipClockScaleY > 0.0f &&
        smuipBackdropScaleX > 0.0f && smuipBackdropScaleY > 0.0f &&
        smuipClockScaleX - smuipClockScaleX == 0.0f && smuipClockScaleY - smuipClockScaleY == 0.0f &&
        smuipBackdropScaleX - smuipBackdropScaleX == 0.0f && smuipBackdropScaleY - smuipBackdropScaleY == 0.0f))
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
        smuipAnchorOffsetX *= smuipScale;
        smuipAnchorOffsetY *= smuipScale;
        if (!(smuipAnchorOffsetX - smuipAnchorOffsetX == 0.0f && smuipAnchorOffsetY - smuipAnchorOffsetY == 0.0f))
            return false;
    }
    g.centerX = g.rootX + (g.clockX + smuipAnchorOffsetX) * g.rootScaleX;
    g.centerY = g.rootY + (g.clockY + smuipAnchorOffsetY) * g.rootScaleY;
    g.boundsX = bounds.GetMemberFlashNumber("x");
    g.boundsY = bounds.GetMemberFlashNumber("y");
    g.boundsWidth = bounds.GetMemberFlashNumber("width");
    g.boundsHeight = bounds.GetMemberFlashNumber("height");
    if (!smuipReady)
    {
        // Predict scaled bounds before changing Flash, so failure leaves native geometry intact.
        g.boundsX = g.rootX + g.clockX * g.rootScaleX + (g.boundsX - g.rootX - g.clockX * g.rootScaleX) * smuipScale;
        g.boundsY = g.rootY + g.clockY * g.rootScaleY + (g.boundsY - g.rootY - g.clockY * g.rootScaleY) * smuipScale;
        g.boundsWidth *= smuipScale;
        g.boundsHeight *= smuipScale;
    }
    placement = SMUIPCalculatePlacement(g, smuipX, smuipY);
    if (!placement.valid)
        return false;

    smuipClock.SetXScale(smuipClockScaleX * smuipScale);
    smuipClock.SetYScale(smuipClockScaleY * smuipScale);
    smuipBackdrop.SetXScale(smuipBackdropScaleX * smuipScale);
    smuipBackdrop.SetYScale(smuipBackdropScaleY * smuipScale);
    // Both sprites share the root; preserve their native offset without clamping the backdrop.
    smuipBackdrop.SetPosition(placement.x + (smuipBackdropNativeX - smuipNativeX) * smuipScale, placement.y + (smuipBackdropNativeY - smuipNativeY) * smuipScale);
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
        {
            smuipBackdrop.SetXScale(smuipBackdropScaleX);
            smuipBackdrop.SetYScale(smuipBackdropScaleY);
            smuipBackdrop.SetPosition(smuipBackdropNativeX, smuipBackdropNativeY);
        }
        if (smuipClock && smuipRefreshMouse)
        {
            smuipClock.SetXScale(smuipClockScaleX);
            smuipClock.SetYScale(smuipClockScaleY);
            smuipClock.SetPosition(smuipNativeX, smuipNativeY);
            smuipRefreshMouse.InvokeSelf();
        }
        smuipReady = false;
    }
    wrappedMethod(x, time);
}

@addField(CR4CommonMenu)
private var smuipCloseButton : CScriptedFlashSprite;

@addField(CR4CommonMenu)
private var smuipCloseOwner : CR4MeditationClockMenu;

@addField(CR4CommonMenu)
private var smuipCloseCaptured : bool;

@addField(CR4CommonMenu)
private var smuipClosePending : bool;

@addField(CR4CommonMenu)
private var smuipCloseNativeVisible : bool;

@addField(CR4CommonMenu)
private var smuipCloseNativeMouse : bool;

@addField(CR4CommonMenu)
private var smuipCloseNativeGamepad : bool;

@addMethod(CR4CommonMenu)
private function SMUIPSuppressCloseButton()
{
    var root : CScriptedFlashSprite;

    if (!smuipCloseCaptured)
    {
        root = GetMenuFlash();
        if (!root)
            return;
        smuipCloseButton = root.GetChildFlashSprite("mcCloseBtn");
        if (!smuipCloseButton)
            return;
        // ConditionalButton.visible is the requested visibility, not the device-filtered result.
        smuipCloseNativeVisible = smuipCloseButton.GetMemberFlashBool("visible");
        smuipCloseNativeMouse = smuipCloseButton.GetMemberFlashBool("showOnMouseKeyboard");
        smuipCloseNativeGamepad = smuipCloseButton.GetMemberFlashBool("showOnGamepad");
        smuipCloseCaptured = true;
    }
    smuipCloseButton.SetMemberFlashBool("showOnMouseKeyboard", false);
    smuipCloseButton.SetMemberFlashBool("showOnGamepad", false);
}

@addMethod(CR4CommonMenu)
private function SMUIPPrepareCloseButton(initData : IScriptable)
{
    var sleepInitData : W3SingleMenuInitData;
    var config : CInGameConfigWrapper;
    var enabled, hideClose : bool;

    sleepInitData = (W3SingleMenuInitData)initData;
    if (sleepInitData)
        return;
    if (!smuipClosePending && !smuipCloseOwner)
    {
        SMUIPInitializeDefaults();
        config = theGame.GetInGameConfigWrapper();
        if (!config)
            return;
        enabled = config.GetVarValue('SMUIP', 'Enabled');
        hideClose = config.GetVarValue('SMUIP', 'HideCloseButton');
        if (!enabled || !hideClose)
            return;
        smuipClosePending = true;
    }
    SMUIPSuppressCloseButton();
}

@addMethod(CR4CommonMenu)
private function SMUIPRestoreCloseButton()
{
    if (smuipCloseCaptured && smuipCloseButton)
    {
        smuipCloseButton.SetMemberFlashBool("visible", smuipCloseNativeVisible);
        smuipCloseButton.SetMemberFlashBool("showOnMouseKeyboard", smuipCloseNativeMouse);
        smuipCloseButton.SetMemberFlashBool("showOnGamepad", smuipCloseNativeGamepad);
    }
    smuipCloseCaptured = false;
    smuipClosePending = false;
    smuipCloseOwner = NULL;
    smuipCloseButton = NULL;
}

@wrapMethod(CR4CommonMenu)
function OnConfigUI()
{
    var menuName : name;
    var result : bool;

    if (thePlayer.IsAlive() && !theGame.HasBlackscreenRequested() && !theGame.IsFading())
    {
        menuName = theGame.GetMenuToOpen();
        if (menuName == '')
            menuName = thePlayer.GetDefaultCommonMenuSelection();
        if (menuName == 'MeditationClockMenu')
            SMUIPPrepareCloseButton(GetMenuInitData());
    }
    result = wrappedMethod();
    return result;
}

@wrapMethod(CR4CommonMenu)
function OnRequestMenu(MenuName : name, MenuState : string)
{
    var initData : IScriptable;
    var result : bool;

    // Match the native rejection guards before changing shared menu state.
    if (!(initFromRadialMenu && MenuName != 'MeditationClockMenu') && !(m_lastMenuName == 'MeditationClockMenu' && m_had_meditation))
    {
        if (MenuName == 'MeditationClockMenu')
        {
            initData = GetMenuInitData();
            if (!initData && tempInitDataRequest)
                initData = tempInitData;
            SMUIPPrepareCloseButton(initData);
        }
    }
    result = wrappedMethod(MenuName, MenuState);
    return result;
}

@wrapMethod(CR4CommonMenu)
function ChildMenuConfigured() : void
{
    var meditation : CR4MeditationClockMenu;
    var sleepInitData : W3SingleMenuInitData;

    meditation = (CR4MeditationClockMenu)GetSubMenu();
    if (meditation)
        sleepInitData = (W3SingleMenuInitData)meditation.GetMenuInitData();
    if (!meditation || sleepInitData)
        SMUIPRestoreCloseButton();
    else
    {
        if (smuipCloseOwner && smuipCloseOwner != meditation)
            SMUIPRestoreCloseButton();
        SMUIPPrepareCloseButton(meditation.GetMenuInitData());
        if (smuipClosePending)
        {
            // Transfer the early capture without exposing or recapturing the hidden button.
            smuipCloseOwner = meditation;
            smuipClosePending = false;
        }
    }
    wrappedMethod();
    if (smuipCloseOwner)
        SMUIPSuppressCloseButton();
}

@wrapMethod(CR4CommonMenu)
function UpdateInputDevice() : void
{
    wrappedMethod();
    if (smuipClosePending || (smuipCloseOwner && GetSubMenu() == smuipCloseOwner))
        SMUIPSuppressCloseButton();
    else
        SMUIPRestoreCloseButton();
}

@wrapMethod(CR4CommonMenu)
function OnCloseSubPanel(menuName : name)
{
    if (menuName == 'MeditationClockMenu')
        SMUIPRestoreCloseButton();
    return wrappedMethod(menuName);
}

@wrapMethod(CR4CommonMenu)
function OnClosingMenu()
{
    SMUIPRestoreCloseButton();
    return wrappedMethod();
}
