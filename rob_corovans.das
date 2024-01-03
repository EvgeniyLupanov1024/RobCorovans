require daslib/media
require random
require math
require strings
require daslib/strings_boost

options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code


/*
 * ===============================================================================================================
 *
 * MAIN FILE
 *
 * ===============================================================================================================
 */

var 
    isPause : bool = false
    seed: int4

[export]
def initialize
    set_antialiasing(4)
    set_window_title("Rob Corovans")

    randomize_seed(seed)
    sceneInit()

[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

    if get_key_down(VK_SPACE)
        isPause = !isPause

    if isPause
        return

    sceneUpdate(dt)

[export]
def draw
    enable_alpha_blend()
    sceneRender()

/*
 * ===============================================================================================================
 *
 * SCENE
 *
 * ===============================================================================================================
 */

var 
    camera: Camera <- Camera()
    player: Player <- Player()
    map: Map
    corovan: Corovan <- Corovan()
    elf: Elf <- Elf()
    storm: Storm <- Storm()
    footprints: Footprints <- Footprints()

def sceneInit()
    generateMap()

    playerInit()
    elfInit()

    stormInit()

def sceneUpdate(dt: float)
    playerUpdate(dt)
    elfUpdate(dt)
    corovanUpdate(dt)

    footprintsUpdate(dt)
    stormUpdate(dt)

    cameraUpdate(dt)

def sceneRender()
    cameraRender()

/*
 * ===============================================================================================================
 *
 * CAMERA
 *
 * ===============================================================================================================
 */

let
    halfScreenWidth: float = float(get_screen_width() / 2)
    halfScreenHeight: float = float(get_screen_height() / 2)

struct Camera
    position: float2 = float2(0, 0)
    screenPosition: float2 = float2(0, 0)

    moveSpeed: float = 3.0
    speed: float2

def cameraUpdate(dt: float)
    camera.position += camera.speed * dt
    camera.speed += (player.position - camera.position) * camera.moveSpeed

    camera.speed *= 0.8

def cameraRender() 
    camera.screenPosition = float2(camera.position.x - halfScreenWidth, camera.position.y - halfScreenHeight)

    mapRender()
    footprintsRender()
    grainsRender()

    playerRender()
    elfRender()
    corovanRender()

    dustsRender()

    guiRender()

/*
 * ===============================================================================================================
 *
 * GUI
 *
 * ===============================================================================================================
 */

let
    debugTextOffset: int = 30
    debugTextColor: uint = 0xEEDDAABB

    exitTextFontSize: int = 36
    exitTextAvrWidth: float = float(exitTextFontSize) * 0.54
    exitTextFontColor: uint = 0xFFEEDDCC

    exitTextBorder: string = "Затеряться в песках"
    exitTextLost: string = "Вы затерялись в песках"
    exitTextLostNote: string = "[нажмите F5, чтобы начать путишествие]"

    playerChoiceFontSize: int = 20

    playerChoiceOne: string = "[1] Ты свободен, как птица. Мохнатая, четырёхлапая, метр семьдесят пять в холке птица."
    playerChoiceTwo: string = "[2] Я бы хотел ещё подождать корована. С тобой."
    
def guiRender()
    debugRender()

def debugRender()
    set_font_size(16)
    set_font_name("mono")

    var y: int = debugTextOffset
    text_out(debugTextOffset, y, "Игрок: ({player.position})", debugTextColor)

    y += debugTextOffset
    text_out(debugTextOffset, y, "Взгляд: ({player.lookPoint})", debugTextColor)

    y += debugTextOffset
    text_out(debugTextOffset, y, "Ветер: {storm.windDir} | {storm.windForce}", debugTextColor)

def exitFromMapRender(transparent: float)
    set_font_size(exitTextFontSize)
    set_font_name("Shadower.ttf")
    text_out(
        getCenteringTextOffset(exitTextBorder, exitTextAvrWidth),
        150, 
        exitTextBorder, 
        exitTextFontColor + floatToTransparent(transparent)
    )

def lostInDesertRender()
    set_font_size(exitTextFontSize)
    set_font_name("Shadower.ttf")
    text_out(
        getCenteringTextOffset(exitTextLost, exitTextAvrWidth),
        150, 
        exitTextLost, 
        exitTextFontColor
    )

    set_font_size(exitTextFontSize / 2)
    text_out(
        getCenteringTextOffset(exitTextLostNote, exitTextAvrWidth / 2.0),
        150 + int(float(exitTextFontSize) * 1.7), 
        exitTextLostNote, 
        exitTextFontColor
    )

def playerChoiceRender()
    set_font_size(playerChoiceFontSize)
    set_font_name("noita.ttf")
    text_out(
        50,
        get_screen_height() - 70 - exitTextFontSize, 
        playerChoiceOne, 
        exitTextFontColor
    )

    text_out(
        50,
        get_screen_height() - 70, 
        playerChoiceTwo, 
        exitTextFontColor
    )

def getCenteringTextOffset(str: string; avr: float): int
    return (get_screen_width() - int(getStrPixelWidth(str, avr))) / 2

/*
 * ===============================================================================================================
 *
 * PLAYER
 *
 * ===============================================================================================================
 */

struct Player
    position: float2 = float2(0, 0)
    maxPositionCoord: float
    lookPoint : float2
    lookLen: float
    alive: bool = true

    maxMoveSpeed: float = 300.0
    moveSpeed: float = 30.0
    speed: float2

    stepLen: float = 60.0
    distToFootprint: float
    leftFootprint: bool = false

    pCurInteractable: Interactable? = null

    choice: bool = false

def playerInit()
    player.distToFootprint = random_float(seed) * player.stepLen

def playerUpdate(dt: float)
    if !player.alive
        return

    playerMove(dt)
    playerSpeedUpdate()
    playerLookUpdate()
    playerChoice()

    player.pCurInteractable = getNearestInteractable()

def playerMove(dt: float)
    player.position += player.speed * dt
    player.maxPositionCoord = max(abs(player.position.x), abs(player.position.y))
    if player.maxPositionCoord > deathBorderArea
        player.alive = false

    player.distToFootprint -= length(player.speed * dt)
    if player.distToFootprint <= 0.0
        var footprintOffset = normalize(float2(player.speed.y, -player.speed.x)) * 10.0
        if player.leftFootprint
            footprintOffset *= -1.0

        addFootprint(player.position + footprintOffset)
        player.leftFootprint = !player.leftFootprint
        player.distToFootprint = player.stepLen + (random_float(seed) - 0.5) * 20.0

def playerSpeedUpdate()
    var moveDir: float2 = float2(0.0, 0.0)

    if get_key(VK_W)
        moveDir += float2(0.0, -1.0)
    if get_key(VK_UP)
        moveDir += float2(0.0, -1.0)
    if get_key(VK_A)
        moveDir += float2(-1.0, 0.0)
    if get_key(VK_LEFT)
        moveDir += float2(-1.0, 0.0)
    if get_key(VK_S)
        moveDir += float2(0.0, 1.0)
    if get_key(VK_DOWN)
        moveDir += float2(0.0, 1.0)
    if get_key(VK_D)
        moveDir += float2(1.0, 0.0)
    if get_key(VK_RIGHT)
        moveDir += float2(1.0, 0.0)

    moveDir = normalize(moveDir)

    player.speed += moveDir * player.moveSpeed
    if storm.windForce > 130.0
        player.speed += storm.wind * 0.05
    if length(player.speed) > player.maxMoveSpeed
        player.speed = normalize(player.speed) * player.maxMoveSpeed
    player.speed *= 0.9

def playerLookUpdate()
    player.lookPoint = camera.screenPosition + get_mouse_position() - player.position
    player.lookLen = length(player.lookPoint)

def playerChoice()
    if !player.choice
        return

    if get_key(VK_1)
        player.choice = false

        elf.elfChoice = 1
        elf.dialogCleanTimerMax = 5.0
        elf.vanishing = true
        elf.dialogVanishing = true

    elif get_key(VK_2)
        player.choice = false

        elf.elfChoice = 2
        elf.dialogCleanTimerMax = 5.0
        elf.dialogVanishing = true

        storm.windForce = -0.0001
        storm.windForceChangeTimer = 10000.0

def getCosLookToObject(objPos: float2): float
    if player.lookLen == 0.0
        return 0.0

    let vToObj = objPos - player.position
    let distToObj = length(vToObj)
    if distToObj == 0.0
        return 0.0

    return (player.lookPoint.x * vToObj.x + player.lookPoint.y * vToObj.y)/(player.lookLen * distToObj)

def playerRender()

    if player.maxPositionCoord > deathBorderArea
        lostInDesertRender()
        return

    if player.choice
        playerChoiceRender()

    var playerProximity: float = proximityToMapBorder(player.position, deepTransparentArea)
    var playerTransparent: float = 255.0 * playerProximity
    fill_circle(player.position.x - camera.screenPosition.x, player.position.y - camera.screenPosition.y, 16.0, 0xCCCCCC + floatToTransparent(playerTransparent))

    if playerProximity < 1.0
        exitFromMapRender(256.0 - playerTransparent)

/*
 * ===============================================================================================================
 *
 * MAP
 *
 * ===============================================================================================================
 */ 

let
    mapSize: float = 4000.0
    halfMapSize: float = mapSize / 2.0
    borderArea: float = 300.0
    deepTransparentArea: float = borderArea * 0.33
    deathBorderArea: float = halfMapSize + float(get_screen_width() / 2)

    titleSize: float = 70.0
    titleNoise: float = 25.0
    titleCount: int = int(mapSize / titleSize)

    titleCountOverkill: int = 2
    titleCountOnScreenH: int = int(float(get_screen_height()) / titleSize) + titleCountOverkill * 2
    titleCountOnScreenW: int = int(float(get_screen_width()) / titleSize) + titleCountOverkill * 2

struct Map
    titles: array<array<Title>>
    road: array<float2>

struct Title
    position: float2
    color: uint

def generateMap()
    generateTitles()
    generateRoad()
    roadPaint()

def generateTitles()
    var hPosition: float = -halfMapSize

    for ih in range(titleCount + 1)
        var wPosition: float = -halfMapSize
        var rowTitles: array<Title>

        for iw in range(titleCount + 1)
            var title: Title
            title.position = float2(wPosition + random_float(seed) * titleNoise, hPosition + random_float(seed) * titleNoise) 
            title.color = 0xCC9955 + uint(random_float(seed) * 16.0) * 0x000101

            push(rowTitles, title)
            wPosition += titleSize

        emplace(map.titles, rowTitles)
        hPosition += titleSize

def generateRoad()
    var keyPoint: float2 = float2(300.0, 0.0)
    var pointHalfCount: int = int((halfMapSize + borderArea) / titleSize)
    resize(map.road, pointHalfCount * 2 + 1)
    
    map.road[pointHalfCount] = keyPoint
    
    var point: float2 = keyPoint
    for i in range(0, pointHalfCount)
        point.x += -titleSize + random_float(seed) * titleSize * 2.0
        point.y += titleSize
        map.road[pointHalfCount - 1 - i] = point

    point = keyPoint
    for i in range(pointHalfCount + 1, pointHalfCount * 2 + 1)
        point.x += -titleSize + random_float(seed) * titleSize * 2.0
        point.y -= titleSize
        map.road[i] = point

def roadPaint()
    var colorOffset: float3 = float3(0.97, 0.94, 0.96)
    for row in map.titles
        for title in row
            for wayPoint in map.road
                var dist: float = titleSize * 0.5
                if (squareDistTo(title.position, wayPoint) < dist)
                    title.color = float3ToHex(hexToFloat3(title.color) * colorOffset)

                dist = titleSize
                if (squareDistTo(title.position, wayPoint) < dist)
                    title.color = float3ToHex(hexToFloat3(title.color) * colorOffset)

                dist = titleSize * 1.5
                if (squareDistTo(title.position, wayPoint) < dist)
                    title.color = float3ToHex(hexToFloat3(title.color) * colorOffset)

def mapRender()
    var startHIndexTitleScreen: int = max(int((camera.screenPosition.y + halfMapSize) / titleSize) - titleCountOverkill, 0)
    var startWIndexTitleScreen: int = max(int((camera.screenPosition.x + halfMapSize) / titleSize) - titleCountOverkill, 0)
    var endHIndexTitleScreen: int = min(titleCount, startHIndexTitleScreen + titleCountOnScreenH)
    var endWIndexTitleScreen: int = min(titleCount, startWIndexTitleScreen + titleCountOnScreenW)

    for ih in range(startHIndexTitleScreen, endHIndexTitleScreen)
        for iw in range(startWIndexTitleScreen, endWIndexTitleScreen)
            var transparent: float = getCosLookToObject(map.titles[ih][iw].position) * 10.0 + 238.0
            var proximity: float = proximityToMapBorder(map.titles[ih][iw].position)
            transparent *= 0.5 + proximity / 2.0
            
            fill_convex_polygon([[float2[4]
                map.titles[ih][iw].position - camera.screenPosition; 
                map.titles[ih + 1][iw].position - camera.screenPosition; 
                map.titles[ih + 1][iw + 1].position - camera.screenPosition;
                map.titles[ih][iw + 1].position - camera.screenPosition
            ]], map.titles[ih][iw].color + floatToTransparent(transparent))

def proximityToMapBorder(objPos: float2; deep: float = 0.0): float
    let farthestCoord: float = max(abs(objPos.x), abs(objPos.y))
    return min(max(0.0, halfMapSize + deep - farthestCoord) / borderArea, 1.0)

def titleFromPos(pos: float2): Title
    var posInMap = pos + float2(halfMapSize, halfMapSize)
    return map.titles[int(posInMap.y / titleSize)][int(posInMap.x / titleSize)]

/*
 * ===============================================================================================================
 *
 * INTERACTABLE
 *
 * ===============================================================================================================
 */

let
    interactDist: float = titleSize * 2.5
    interactTextOffset: float2 = float2(0.0, 30.0)
    interactTextFontSize: int = 16
    interactTextAvrWidth: float = float(interactTextFontSize) * 0.66

struct Interactable
    position: float2
    interactText: string = "[F] interact"
    interactTextTransparent: float = 0.0
    interactTextOffset: float2 = interactTextOffset

    InteractableUpdate = @@InteractableUpdate
    InteractableRender = @@InteractableRender

    interact = @@defaultInteract

def defaultInteract(var interactable: Interactable)
    return

def getNearestInteractable(): Interactable?
    var minDist: float = interactDist
    var curDist: float
    var pNearestInteractable: Interactable? = null

    // corovaners
    for interactable in corovan.corovaners
        curDist = distTo(player.position, interactable.position)
        if curDist >= minDist
            continue

        minDist = curDist
        pNearestInteractable = unsafe(addr(interactable))

    // elf
    curDist = distTo(player.position, elf.position)
    if curDist < minDist
        minDist = curDist
        pNearestInteractable = unsafe(addr(elf))

    unsafe
        return pNearestInteractable

def InteractableUpdate(var interactable: Interactable; dt: float)
    if unsafe(addr(interactable)) != player.pCurInteractable
        if interactable.interactTextTransparent > 0.0
            interactable.interactTextTransparent = max(interactable.interactTextTransparent - dt * 4.0, 0.0)
        return
    
    if interactable.interactTextTransparent < 1.0
        interactable.interactTextTransparent = min(interactable.interactTextTransparent + dt * 7.0, 1.0)
    
    if get_key_down(VK_F)
        interactable->interact()

def InteractableRender(var interactable: Interactable; var transparent: float)
    transparent *= interactable.interactTextTransparent

    set_font_size(interactTextFontSize)
    set_font_name("noita.ttf")
    text_out(
        interactable.position.x - camera.screenPosition.x + interactable.interactTextOffset.x, 
        interactable.position.y - camera.screenPosition.y + interactable.interactTextOffset.y,
        interactable.interactText,
        0xEEDD77 + floatToTransparent(transparent)
    )

/*
 * ===============================================================================================================
 *
 * DIALOGABLE
 *
 * ===============================================================================================================
 */

let 
    dialogOffset: float2 = float2(0.0, -55.0)
    dialogFontSize: float = 20.0
    dialogFontAvrWidth: float = dialogFontSize * 0.6
    dialogLetterInLineMax: int = 45
    dialogLineHeight: float = dialogFontSize * 1.5

struct Dialogable: Interactable
    override position: float2

    printDialog = @@printDialog
    endPrintingDialog = @@endPrintingDialog

    dialogText: array<string>
    dialogPrinting: bool = false
    dialogOffset: float2 = dialogOffset
    
    dialogLineInd: int = 0    
    dialogLetterInd: int = 0
    dialogLetterTimer: float = 0.0
    dialogLetterTimerMax: float = 0.03

    dialogCleanTimer: float = 0.0
    dialogCleanTimerMax: float = 20.0
    dialogVanishing: bool = false
    dialogTransparent: float = 1.0

    dialogableUpdate = @@dialogableUpdate
    dialogableRender = @@dialogableRender

def printDialog(var dialogable: Dialogable; str: string)
    dialogable.dialogPrinting = true
    dialogable.dialogLineInd = 0
    dialogable.dialogLetterInd = 0

    dialogable.dialogVanishing = false
    dialogable.dialogTransparent = 1.0
    clear(dialogable.dialogText)

    var startInd: int = 0
    var lastSpaceInd: int = dialogLetterInLineMax
    var utf: bool = false
    var singCoutn: int = 0
    var singCoutnBeforeSpace: int = 0

    for ind in range(length(str))
        var ch: int = unsafe(character_uat(str, ind))
        
        if utf
            utf = false
            continue

        if ch > 128
            utf = true
        elif is_white_space(ch)
            lastSpaceInd = ind
            singCoutnBeforeSpace = singCoutn

        singCoutn++
        if singCoutn > dialogLetterInLineMax
            push(dialogable.dialogText, slice(str, startInd, lastSpaceInd))
            singCoutn -= singCoutnBeforeSpace 
            startInd = lastSpaceInd + 1

    push(dialogable.dialogText, slice(str, startInd, length(str)))
    dialogable.dialogOffset.y = dialogOffset.y - dialogLineHeight * float(length(dialogable.dialogText) - 1)
    if length(dialogable.dialogText) == 1
        dialogable.dialogOffset.x = dialogOffset.x - getStrPixelWidth(dialogable.dialogText[0], dialogFontAvrWidth) / 2.0
    else 
        dialogable.dialogOffset.x = dialogOffset.x - (dialogFontAvrWidth * float(dialogLetterInLineMax / 2))

def endPrintingDialog(var dialogable: Dialogable)
    dialogable.dialogPrinting = false
    dialogable.dialogLineInd = length(dialogable.dialogText)
    dialogable.dialogLetterInd = 0
    dialogable.dialogCleanTimer = dialogable.dialogCleanTimerMax

def dialogableUpdate(var dialogable: Dialogable; dt: float)
    if dialogable.dialogVanishing && dialogable.dialogTransparent >= 0.0
        dialogable.dialogTransparent -= dt

    if dialogable.dialogCleanTimer > 0.0
        dialogable.dialogCleanTimer -= dt
        if dialogable.dialogCleanTimer <= 0.0
            dialogable.dialogVanishing = true

    if !dialogable.dialogPrinting
        return

    dialogable.dialogLetterTimer -= dt
    if dialogable.dialogLetterTimer > 0.0
        return

    var ch: int = unsafe(character_uat(dialogable.dialogText[dialogable.dialogLineInd], dialogable.dialogLetterInd))
    if ch > 128
        dialogable.dialogLetterInd++
    elif ch == '.' || ch == '!' || ch == '?'
        dialogable.dialogLetterTimer += dialogable.dialogLetterTimerMax * 5.0

    dialogable.dialogLetterTimer += dialogable.dialogLetterTimerMax
    dialogable.dialogLetterInd++
    if dialogable.dialogLetterInd == length(dialogable.dialogText[dialogable.dialogLineInd])
        dialogable.dialogLineInd++
        dialogable.dialogLetterInd = 0
        if dialogable.dialogLineInd == length(dialogable.dialogText)
            dialogable.dialogPrinting = false
            dialogable.dialogCleanTimer = dialogable.dialogCleanTimerMax

def dialogableRender(var dialogable: Dialogable)
    var transparent: float = getCosLookToObject(dialogable.position) * 55.0 + 200.0
    transparent *= proximityToMapBorder(dialogable.position, deepTransparentArea)
    transparent *= dialogable.dialogTransparent
    
    set_font_size(dialogFontSize)
    set_font_name("noita.ttf")

    for lineInd in range(dialogable.dialogLineInd + 1)
        if lineInd == length(dialogable.dialogText)
            break

        var letterInd: int
        if lineInd == dialogable.dialogLineInd
            letterInd = dialogable.dialogLetterInd
        else 
            letterInd = length(dialogable.dialogText[lineInd])

        text_out(
            dialogable.position.x - camera.screenPosition.x + dialogable.dialogOffset.x, 
            dialogable.position.y - camera.screenPosition.y + dialogable.dialogOffset.y + dialogLineHeight * float(lineInd),
            slice(dialogable.dialogText[lineInd], 0, letterInd),
            0xEEDD77 + floatToTransparent(transparent)
        )

/*
 * ===============================================================================================================
 *
 * COROVANS
 *
 * ===============================================================================================================
 */

let
    comeRange: float = titleSize / 2.0

struct Corovan
    isStart: bool = false
    isRobbed: bool = false
    corovaners: array<Corovaner>

    corovanStoryInd: int = 0

struct Corovaner: Dialogable
    override position: float2
    wayPointIndex: int = 0
    alive: bool = true
    isRobbed: bool = false

    moveSpeed: float = 3.0
    speed: float2

    stepLen: float = 60.0
    distToFootprint: float
    leftFootprint: bool = false

    override interactText = "[F] грабить"
    override interact = @@corovanerInteract

    override dialogCleanTimerMax = 13.0
    corovanerPhrase: string

def startCorovan()
    if corovan.isStart
        return

    var startPosition: float2 = map.road[0]
    for phrase in corovanDialogos[corovan.corovanStoryInd]
        var corovaner: Corovaner <- Corovaner()
        corovaner.position = startPosition
        corovaner.wayPointIndex = 0
        corovaner.stepLen += (random_float(seed) - 0.5) * 5.0
        corovaner.distToFootprint = random_float(seed) * corovaner.stepLen

        corovaner.interactTextOffset.x -= getStrPixelWidth(corovaner.interactText, interactTextAvrWidth) / 2.0
        corovaner.corovanerPhrase = phrase

        emplace(corovan.corovaners, corovaner)
        startPosition.y += titleSize * 2.5

    corovan.isStart = true
    corovan.isRobbed = false

def corovanerInteract(var interactable: Interactable)
    var pCorovaner: Corovaner? = unsafe(addr(unsafe(upcast<Corovaner> interactable)))

    if (*pCorovaner).dialogPrinting
        pCorovaner->endPrintingDialog()
    else
        pCorovaner->printDialog((*pCorovaner).corovanerPhrase)
        (*pCorovaner).isRobbed = true

def corovanUpdate(dt: float)
    corovanersUpdate(dt)

    var isRobbedEveryone: bool = true
    var idx: int = length(corovan.corovaners) - 1
    while idx >= 0
        if !corovan.corovaners[idx].alive
            erase(corovan.corovaners, idx)
        else
            isRobbedEveryone &&= corovan.corovaners[idx].isRobbed
        idx--

    corovan.isRobbed = isRobbedEveryone

    if corovan.isRobbed && corovan.isStart
        elf.elfStoryInd++
        elf.elfPhraseInd = 0
        elf.dialogCleanTimerMax = elfDialogCleanTimer

        corovan.isStart = false
        corovan.corovanStoryInd++
        if corovan.corovanStoryInd == length(corovanDialogos)
            corovan.corovanStoryInd = 0

def corovanersUpdate(dt: float)
    for corovaner in corovan.corovaners
        if !corovaner.alive
            continue

        if corovaner.wayPointIndex == length(map.road) - 1
            corovaner.alive = false

        // position
        corovaner.position += corovaner.speed * dt        
        var moveDir: float2 = map.road[corovaner.wayPointIndex] - corovaner.position
        if length(moveDir) < comeRange
            corovaner.wayPointIndex += 1

        // footprint
        corovaner.distToFootprint -= length(corovaner.speed * dt)
        if corovaner.distToFootprint <= 0.0
            var footprintOffset = normalize(float2(corovaner.speed.y, -corovaner.speed.x)) * 10.0
            if corovaner.leftFootprint
                footprintOffset *= -1.0

            addFootprint(corovaner.position + footprintOffset)
            corovaner.leftFootprint = !corovaner.leftFootprint
            corovaner.distToFootprint = corovaner.stepLen + (random_float(seed) - 0.5) * 20.0

        // speed
        corovaner.speed += normalize(moveDir) * corovaner.moveSpeed
        corovaner.speed *= 0.9

        corovaner->dialogableUpdate(dt)
        corovaner->InteractableUpdate(dt)

def corovanRender()
    for corovaner in corovan.corovaners
        var transparent: float = getCosLookToObject(corovaner.position) * 125.0 + 125.0
        transparent *= proximityToMapBorder(corovaner.position, deepTransparentArea)

        fill_circle(
            corovaner.position.x - camera.screenPosition.x, 
            corovaner.position.y - camera.screenPosition.y, 
            16.0, 
            0xCCCCFF + floatToTransparent(transparent)
        )

        corovaner->dialogableRender()
        corovaner->InteractableRender(transparent)

/*
 * ===============================================================================================================
 *
 * ELF (NOT ELF)
 *
 * ===============================================================================================================
 */

let
    elfDialogCleanTimer: float = 100.0

struct Elf: Dialogable
    override position: float2 = float2(600.0, -titleSize)

    override interactText = "[F] говорить"
    override interact = @@elfInteract
    
    override dialogCleanTimerMax = elfDialogCleanTimer
    elfStoryInd: int = 0
    elfPhraseInd: int = 0
    elfChoice: int = 0
    vanishing: bool = false
    elfTransparent: float = 1.0
    alive: bool = true

def elfInit()
    elf.interactTextOffset.x -= getStrPixelWidth(elf.interactText, interactTextAvrWidth) / 2.0

def elfUpdate(dt: float)
    elf->dialogableUpdate(dt)

    if elf.vanishing
        elf.elfTransparent -= dt * 0.15
        if elf.elfTransparent <= 0.0
            elf.alive = false
            elf.vanishing = false

    if elf.alive
        elf->InteractableUpdate(dt)

def elfRender()
    var transparent: float = getCosLookToObject(elf.position) * 125.0 + 125.0
    transparent *= elf.elfTransparent
    fill_circle(
        elf.position.x - camera.screenPosition.x, 
        elf.position.y - camera.screenPosition.y, 
        16.0, 
        0xCCFFCC + floatToTransparent(transparent)
    )

    elf->dialogableRender()
    elf->InteractableRender(transparent)

def elfInteract(var interactable: Interactable)
    if elf.dialogPrinting
        elf->endPrintingDialog()
        return
    
    var phrase: string
    if elf.elfPhraseInd == length(elfDialogos[elf.elfStoryInd])
        if elf.elfStoryInd == 0
            phrase = "Потом договорим! Грабь КОРОВАНЫ!"
        elif elf.elfStoryInd == 1
            phrase = "Корованы не ждут."
        elif elf.elfStoryInd == 2 && elf.elfChoice == 0
            phrase = elfDialogos[elf.elfStoryInd][length(elfDialogos[elf.elfStoryInd]) - 1]
        elif elf.elfStoryInd == 2 && elf.elfChoice == 1
            phrase = "Вжух......"
        elif elf.elfStoryInd == 2 && elf.elfChoice == 2
            phrase = "Мур-мур-мяу"
        else
            phrase = "..."
    else
        phrase = elfDialogos[elf.elfStoryInd][elf.elfPhraseInd]
        elf.elfPhraseInd++
    
    elf->printDialog(phrase)
    if elf.elfPhraseInd == length(elfDialogos[elf.elfStoryInd])
        if elf.elfStoryInd == 0 || elf.elfStoryInd == 1
            startCorovan()
            elf.dialogCleanTimerMax = 10.0
        
        elif elf.elfStoryInd == 2 && elf.elfChoice == 0
            player.choice = true

/*
 * ===============================================================================================================
 *
 * STORM
 *
 * ===============================================================================================================
 */

let
    stormArea: float = float(get_screen_width()) * 0.8
    maxDustCount: int = 256
    maxGrainCount: int = 1024
    
    maxWindForce: float = 200.0
    windDirTimer: float = 7.0
    windForceTimer: float = 7.0

struct Storm
    dusts: Dust[maxDustCount]
    dustInd: int = 0
    grains: Grain[maxGrainCount]
    grainInd: int = 0

    dustPerFrame: int = 0

    windDir: float2 = float2(1.0, 0.0)
    windForce: float = 100.0
    wind: float2 = float2(100.0, 0.0)
    
    windDirChangeTimer: float = 0.0
    windForceChangeTimer: float = 0.0

def stormInit()
    storm.windDir = randVec()

def stormUpdate(dt: float)
    windUpdate(dt)

    // dust
    if random_float(seed) < 0.001 * storm.windForce
        addDust()

    // grain
    if storm.windForce > 130.0 
        addDust()
        if storm.dustPerFrame != 100
            storm.dustPerFrame++
    elif storm.windForce > 60.0 
        if storm.dustPerFrame < 10 && random_float(seed) < 0.1
            storm.dustPerFrame++
        elif storm.dustPerFrame > 10
            storm.dustPerFrame--
    else
        if storm.dustPerFrame > 0 && random_float(seed) < 0.1
            storm.dustPerFrame--
 
    for i in range(storm.dustPerFrame)
        addGrain()

    // update
    dustsUpdate(dt)
    grainsUpdate(dt)

def windUpdate(dt: float)
    storm.windDirChangeTimer -= dt
    storm.windForceChangeTimer -= dt

    if storm.windDirChangeTimer <= 0.0
        storm.windDirChangeTimer = windDirTimer + (random_float(seed) - 0.5) * windDirTimer
        storm.windDir = normalize(storm.windDir + randVec() / 3.0)
        
        storm.wind = storm.windDir * storm.windForce

    if storm.windForceChangeTimer <= 0.0
        storm.windForceChangeTimer = windForceTimer + (random_float(seed) - 0.5) * 10.0
        
        var windForceOffset: float = (random_float(seed) - 0.5) * maxWindForce
        if storm.windForce + windForceOffset > maxWindForce || storm.windForce + windForceOffset < -20.0
            storm.windForce -= windForceOffset
        else 
            storm.windForce += windForceOffset

        storm.wind = storm.windDir * storm.windForce

/*
* ===============================================================================================================
*
* DUST
*
* ===============================================================================================================
*/

struct Dust
    position: float2
    distanceWented: float = 0.0
    maxDistanceStart: float
    maxDistanceEnd: float
    speed: float2

    transparent: float = 0.0
    alive: bool = false

def addDust(): void
    var dust: Dust = Dust()
    dust.position = float2(
        player.position.x + (random_float(seed) - 0.5) * stormArea * 2.0, 
        player.position.y + (random_float(seed) - 0.5) * stormArea * 2.0
    )
    dust.maxDistanceStart = storm.windForce * (random_float(seed) + 0.5)
    dust.maxDistanceEnd = dust.maxDistanceStart * (random_float(seed) + 1.0)
    dust.speed = storm.windDir * dust.maxDistanceStart * 2.0
    dust.alive = true

    storm.dusts[storm.dustInd] = dust
    storm.dustInd++
    if storm.dustInd == maxDustCount
        storm.dustInd = 0

def dustsUpdate(dt: float): void
    for dust in storm.dusts
        if !dust.alive
            continue

        dust.position += dust.speed * dt
        dust.distanceWented += length(dust.speed * dt)

        if dust.distanceWented < dust.maxDistanceStart
            dust.transparent = dust.distanceWented / dust.maxDistanceStart

        elif dust.distanceWented > dust.maxDistanceEnd
            dust.transparent -= dt
            if dust.transparent < 0.0
                dust.alive = false
        
def dustsRender(): void
    for dust in storm.dusts
        if !dust.alive
            continue

        // var transparent: float = (getCosLookToObject(dust.position) + 1.5) * 128.0 * dust.transparent
        var transparent: float = (getCosLookToObject(dust.position) + 1.5) * 50.0 * dust.transparent
        fill_rect(
            dust.position.x - camera.screenPosition.x, 
            dust.position.y - camera.screenPosition.y, 
            100.0, 
            100.0, 
            0xEEEEBB + floatToTransparent(transparent)
        )

/*
* ===============================================================================================================
*
* GRAIN
*
* ===============================================================================================================
*/

struct Grain
    position: float2
    distanceWented: float = 0.0
    maxDistance: float
    speed: float2

    transparent: float = 0.0
    alive: bool = false

def addGrain(): void
    var grain: Grain = Grain()
    grain.position = float2(
        player.position.x + (random_float(seed) - 0.5) * stormArea * 2.0, 
        player.position.y + (random_float(seed) - 0.5) * stormArea * 2.0
    )
    grain.maxDistance = storm.windForce * (random_float(seed) + 0.5)
    grain.alive = true

    storm.grains[storm.grainInd] = grain
    storm.grainInd++
    if storm.grainInd == maxGrainCount
        storm.grainInd = 0

def grainsUpdate(dt: float): void
    var windSpeed: float2 = storm.wind * 3.0
    var dVanish: float = dt / 10.0

    for grain in storm.grains
        if !grain.alive
            continue

        grain.position += grain.speed * dt
        grain.distanceWented += length(grain.speed * dt)

        if grain.distanceWented > grain.maxDistance
            grain.speed *= 0.7
            grain.transparent -= dVanish
            if grain.transparent < 0.0
                grain.alive = false
        else
            grain.speed += windSpeed
            grain.transparent = grain.distanceWented / grain.maxDistance

def grainsRender(): void
    for grain in storm.grains
        if !grain.alive
            continue

        var transparent: float = (getCosLookToObject(grain.position) + 1.5) * 128.0 * grain.transparent
        fill_circle(
            grain.position.x - camera.screenPosition.x, 
            grain.position.y - camera.screenPosition.y, 
            2.5, 
            0xEEEEBB + floatToTransparent(transparent)
        )

/*
* ===============================================================================================================
*
* FOOTPRINTS
*
* ===============================================================================================================
*/
 
let
    maxCountFootprint: int = 1024
    maxLifetimeFootprint: float = 50.0
    footprintColorOffset: float3 = float3(20.0, 30.0, 20.0)
 
struct Footprints
    ring: Footprint[maxCountFootprint]
    startInd: int = 0
    endInd: int = 0
 
struct Footprint
    position: float2
    color: uint
 
    lifetimeStart: float
    lifetime: float
 
def addFootprint(position: float2)
    if (abs(position.x) > halfMapSize || abs(position.y) > halfMapSize)
        return

    var footprint: Footprint
    footprint.position = position
    footprint.lifetimeStart = maxLifetimeFootprint * random_float(seed)
    footprint.lifetime = footprint.lifetimeStart
    footprint.color = float3ToHex(hexToFloat3(titleFromPos(footprint.position).color) - footprintColorOffset)
 
    footprints.ring[footprints.endInd] = footprint
    footprints.endInd++
    if footprints.endInd == maxCountFootprint
        footprints.endInd = 0

    if footprints.endInd == footprints.startInd
        footprints.startInd++
        if footprints.startInd == maxCountFootprint
            footprints.startInd = 0
 
def getFootprintIndices(): iterator<int>
    var it: iterator<int>
    if footprints.startInd <= footprints.endInd
        it <- [[for ind in range(footprints.startInd, footprints.endInd); ind + 0; where true]]
    else
        it <- [[for ind in range(footprints.startInd, footprints.endInd + maxCountFootprint); ind % maxCountFootprint; where true]]
    return <- it
 
def footprintsUpdate(dt: float)
    for ind in getFootprintIndices()
        if footprints.ring[ind].lifetime <= 0.0
            if ind == footprints.startInd
                footprints.startInd++
                if footprints.startInd == maxCountFootprint
                    footprints.startInd = 0
            continue
 
        footprints.ring[ind].lifetime -= dt
 
def footprintsRender()
    for ind in getFootprintIndices()
        var footprint: Footprint = footprints.ring[ind] 
        var transparent: float = getCosLookToObject(footprint.position) * 125.0 + 105.0
        transparent *= proximityToMapBorder(footprint.position)
        transparent *= footprint.lifetime / footprint.lifetimeStart
        fill_circle(
            footprint.position.x - camera.screenPosition.x, 
            footprint.position.y - camera.screenPosition.y, 
            7.0, 
            footprint.color + floatToTransparent(transparent)
        )

/*
 * ===============================================================================================================
 *
 * HELPERS
 *
 * ===============================================================================================================
 */

def floatToTransparent(fTr: float): uint
    var fTrNorm: int = int(max(0.0, min(fTr, 255.0)))
    return uint(fTrNorm << 24)

def hexToFloat3(color: uint): float3
    return float3(
        float(int(color) >> 16 % 256),
        float((int(color) >> 8) % 256),
        float(int(color) % 256)
    )

def float3ToHex(color: float3): uint
    return uint(
        (int(color.x) << 16) +
        (int(color.y) << 8) +
        int(color.z)
    )

def distTo(pos1: float2; pos2: float2): float
    return length(pos2 - pos1)

def squareDistTo(pos1: float2; pos2: float2): float
    var resVec = pos2 - pos1
    return max(abs(resVec.x), abs(resVec.y))

def randVec(): float2
    return float2(
        (random_float(seed) - 0.5) * 2.0,
        (random_float(seed) - 0.5) * 2.0
    )
    
def getSingCount(str: string): int
    var singCoutn: int
    var utf: bool = false

    for ch in str
        if utf
            utf = false
            singCoutn++
            continue

        if ch > 128
            utf = true
            continue

        singCoutn++
    
    return singCoutn

def getStrPixelWidth(str: string; average: float): float
    return float(getSingCount(str)) * average

/*
 * ===============================================================================================================
 *
 * DIALOGOS
 *
 * ===============================================================================================================
 */

let elfDialogos <- [{array<string>
    [{string
        "Если ты пришёл грабить корованы, то ты несколько опоздал.";
        "Последний корован ушёл пять минут назад. А следующий будет только завтра.";
        "Разумеется я шучу. Я ведь тоже эльф с большой дороги и не хотел бы заиметь конкурента в твоём лице.";
        "Так что придётся тебя... взять в помощники! Будешь сигналить приближение корована.";

        "Все корованы идут с юга и стекаются в город, чтобы торговать за стеной. Так же как и сотню лет назад. С теми, кто пришёл в город с севера. В Закрах.";
        "Закрах? О-о-о! Это настоящая крепость. Звёздчатые башни, стены в пять домов высотой с выступающими карнизами. Их ещё при Золоматоре строили.";
        "Но тамошняя стража совсем отвыкла от налётов. Иногда я собираю команду и устраиваю рейд на южную стену и окрестности.";
        "Но сейчас буря отступила от стен города и укрыться больше негде. Так что приходиться грабить корованы. В дали от города.";

        "Когда-то я тоже был корованщиком. Ходил туда-обратно. С юга на север и севера на юг. Даже бывал в городах севернее Закраха.";
        "Но мысли мои были заняты не ценами на ткани, не пустынным ветром, что сбивает с ног. Нет.";
        "Я размышлял над вопросом: почему нас называют КОРОВАНЩИКИ?";
        "Знаю. Есть простой ответ. Говорящий, что название это просто ошибка или чья-то глупая шутка. Но это мещанский подход.";
        "Я же докопался до Истины. Дело в том, что слово КОРОВАН берёт свой корень от древнего слова… КОРОВА. Да, вот так просто. Корова.";

        "Раньше, когда эта пустыня зеленела, вереницы торговцев пересекали её на коровах, гружёных товарами.";
        "Это очень удобно: корова может быть как вьючным животным, так и источником пищи.";
        "Такой подход позволял древним корованерам пересекать огромные расстояния.";
        "Не смейся! Этимология — это тебе не хухры-мухры. Она может пролить свет на самые тёмные, самые древние времена человеческой цивилизации.";
        "Не эльфийской. Наша история прозрачнее воды в лесном озере. Начинается она во времена.. Погоди.. Я.. я вижу их! Вон там, за тем барханом. Это КОРОВАНЩИКИ!"
    }];

    [{string
        "Неопытный путник легко потеряется среди однообразных барханов. Думаю пару таких ты видел у себя под ногами пока возвращался.";
        "Ты много путешествовал? Хочешь расскажу про южный океан?";
        "Про тёплые воды, цветные кораллы и разнообразие рыб.";
        "Про муссоны, цунами и статистику кораблекрушений.";
        "Не смотри так. Я этим зарабатываю. На хороший мыс волна каждый день выносит обед из трёх блюд в комплекте с официантом.";
        "Правда ему в начале нужно сделать искусственное дыхание, откачать и поставить на ноги. Но в остальном всё, как в лучших трактирах континента.";

        "Иногда я завидую тем, кто живёт на одном месте.";
        "Тем у кого есть собственный дом.";
        "Своё место.";
        "А потом вспоминаю о министре Оригами с сотней верных ему големов и снова радуюсь, что свободен как ветер.";
        "Да и что это за жизнь, если нельзя все свои вещи собрать в мешок за десять минут?";

        "В конце концов за свою жизнь я смог понять такие вещи, от которых у многих бы разболелась голова. Смог узнать куда больше, чем некоторые узнают за десятки лет.";
        "Например, если дразнить акулу ногой, она способна откусить её целиком за один раз. Это же не тривиальное знание. Оно происходит из уникального опыта.";
        "Или что на деревянном протезе можно передвигаться не хуже чем на родной ноге. И это даже не будет заметно.";
        "Да не пялься ты так на мою ногу. Я учусь на чужом опыте.";

        "Следующий корован пройдёт ещё не скоро. Если хочешь можешь пока вздремнуть. Или позагорать. Я обязательно тебе скажу, когда увижу корован.";
        "Можешь взять мой плащ, а то потом ещё неделю будешь песок из себя вытряхивать.";
        "Что-то не так?";
        "Мне показалось ты стесняешься снимать при мне броню";
        "Ты же не боишься, что я тебя ограблю? только потому, что я, как и ты, граблю корованы.";
        "...";
        "Корован на горизонте."
    }];

    [{string
        "Что это у тебя тут? на воротнике.";
        "ХА! купился! у тебя и воротника-та нет.";
        "Когда ты направился ко мне во второй раз, ты напомнил мне ребёнка, спешащего показать свою новую поделку.";

        "*задумался*";
        "Вот как интересно получается: когда я только встретил тебя, я собирался тебя ограбить.";
        "Я был готов вытряхнуть тебя из твоих же сапог. Поднять за ноги и трясти как свежепойманную рыбу.";
        "Сейчас я с тобой так не поступлю.";
        "Всего два рейда, а я уже думаю о тебе как о напарнике. Мда..";
        "Напарник";
        "на-па-рник";
        "Никогда бы не подумал, что вновь произнесу это слово. После всего того, что.. ... Ну да не будем о этом.";

        "*напряжённо молчит*";
        "Знаешь, мне нужно кое в чём тебе признаться.";
        "На самом деле я не эльф. Я КАДЖИТ. И зовут меня М’Айк.";
        "Серьёзно! Мы же в пустыне! Какие тут могут быть эльфы?!";
        "Просто меня попросили побыть эльфом. Для тебя.";
        "Нет, нет, я не жалуюсь. Кто-то же должен быть эльфом. Так уж всё устроено.";
        "Я при деле. И довольно приятном. Можно было бы даже сказать “не пыльным”, если бы не... ну, ты знаешь.. песок. Он здесь повсюду. Даже в воздухе.";
        "Как-то так...";
        "Ладно. Хорошо поболтали. Я наверное пойду.";
        "Но если хочешь, я останусь. Только скажи."
    }]
}]

let corovanDialogos <- [{array<string>
    [{string
        "Что? Нет. Меня грабить нельзя. Я против и отказываюсь отдавать вам все свои ценности.";
        "Подходите! У меня Вы найдёте самые удивительные товары! Что Вам приглянулось? В смысле ничего? В смысле хотите ограбить?";
        "Конечно меня можно ограбить. У Вас ведь есть два экземпляра 142ой справки? Ну формы А142.. той, что для отчётности о проделанном грабеже.";
        "Вы точно хотите ограбить корован? Я слышал это вредно для здоровья. И вызывает привыкание.";
        "Отличная шутка) Я почти поверил, что Вы настоящий грабитель. Такие круглые глаза, такой озлобленный взгляд. Потрясающе."
    }];

    [{string
        "У нас самые низкие цены во внутреннем городе. Мы экономим на охране корована.";
        "Не утруждайте себя - мой скромный скарб трудно сбыть и он не принесёт большой прибыли";
        "Я бы с радостью дал себя ограбить, но сегодня последний вторник месяца - неприёмный день для грабителей. Увы.";
        "Я Герцог Дрешибский, Князь Выребский, и я буду оскорблён, если меня ограбит некто, не имеющий в своей титулатуре хотя бы звания барона.";
        "У меня для Вас подарок. Берите, не стесняйтесь. Я всегда рад встрече с путником. В пустыне это редкость: встреча с другим разумным существом. Доброго Вам пути."
    }]
}]
