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

    pCurInteractable = getNearestInteractable()

    stormUpdate(dt)
    footprintsUpdate(dt)

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
    camera.screenPosition = float2(camera.position.x - float(get_screen_width()/2), camera.position.y - float(get_screen_height()/2))

    mapRender()
    footprintsRender()

    playerRender()
    elfRender()
    corovanRender()

    stormRender()

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

    exitTextBorder = "Затеряться в песках"
    exitTextLost = "Вы затерялись в песках"
    exitTextLostNote = "[нажмите F5, чтобы начать путишествие]"
    
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

    moveSpeed: float = 30.0
    speed: float2

    stepLen: float = 60.0
    distToFootprint: float
    leftFootprint: bool = false

def playerInit()
    player.distToFootprint = random_float(seed) * player.stepLen

def playerUpdate(dt: float)
    if !player.alive
        return

    playerMove(dt)
    playerSpeedUpdate()
    playerLookUpdate()

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
    player.speed *= 0.9

def playerLookUpdate()
    player.lookPoint = camera.screenPosition + get_mouse_position() - player.position
    player.lookLen = length(player.lookPoint)

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

var 
    pCurInteractable: Interactable? = null

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
    if unsafe(addr(interactable)) != pCurInteractable
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

    dialogableUpdate = @@dialogableUpdate
    dialogableRender = @@dialogableRender

def printDialog(var dialogable: Dialogable; str: string)
    dialogable.dialogPrinting = true
    dialogable.dialogLineInd = 0
    dialogable.dialogLetterInd = 0
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
    if dialogable.dialogCleanTimer > 0.0
        dialogable.dialogCleanTimer -= dt
        if dialogable.dialogCleanTimer <= 0.0
            clear(dialogable.dialogText)

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
        elf.dialogCleanTimer = elfDialogCleanTimer

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
 * ELF (NOT ELF!)
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

def elfInit()
    elf.interactTextOffset.x -= getStrPixelWidth(elf.interactText, interactTextAvrWidth) / 2.0

def elfUpdate(dt: float)
    elf->dialogableUpdate(dt)
    elf->InteractableUpdate(dt)

def elfRender()
    var transparent: float = getCosLookToObject(elf.position) * 125.0 + 125.0
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
            phrase = "КОРОВАНЫ! КОРОВАНЫ! Грабь КОРОВАНЫ!"
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
    if elf.elfPhraseInd == length(elfDialogos[elf.elfStoryInd]) && (elf.elfStoryInd == 0 || elf.elfStoryInd == 1)
        startCorovan()
        elf.dialogCleanTimer = 5.0
        elf.dialogCleanTimerMax = 5.0


/*
 * ===============================================================================================================
 *
 * STORM
 *
 * ===============================================================================================================
 */

let
    maxSwirlCount: int = 256
    stormArea: float = float(get_screen_width()) * 0.8
    
    maxWindForce: float = 200.0
    windDirTimer: float = 7.0
    windForceTimer: float = 37.0

struct Storm
    swirls: Swirl[maxSwirlCount]
    swirlInd: int = 0

    windDir: float2 = float2(1.0, 0.0)
    windForce: float = 100.0
    
    windDirChangeTimer: float = 0.0
    windForceChangeTimer: float = 0.0

struct Swirl
    position: float2
    distanceWented: float = 0.0
    maxDistance: float
    speed: float2
    size: float

    transparent: float = 0.0
    alive: bool = false

def stormInit()
    storm.windDir = randVec()

def stormUpdate(dt: float)
    addSwirl()
    swirlsUpdate(dt)
    windUpdate(dt)

def addSwirl()
    if random_float(seed) < 0.95
        var swirl: Swirl = Swirl()
        swirl.position = float2(
            player.position.x + (random_float(seed) * stormArea * 2.0) - stormArea, 
            player.position.y + (random_float(seed) * stormArea * 2.0) - stormArea
        )
        swirl.maxDistance = storm.windForce * (random_float(seed) + 0.5)
        swirl.size = random_float(seed) * 10.0 + 5.0
        swirl.alive = true

        storm.swirls[storm.swirlInd] = swirl
        storm.swirlInd++
        if storm.swirlInd == maxSwirlCount
            storm.swirlInd = 0

def swirlsUpdate(dt: float)
    for swirl in storm.swirls
        if !swirl.alive
            continue

        swirl.position += swirl.speed * dt
        swirl.distanceWented += length(swirl.speed * dt)

        if swirl.distanceWented > swirl.maxDistance
            swirl.speed *= 0.9
            swirl.transparent -= 5.0
            if swirl.transparent < 5.0
                swirl.alive = false
        else
            swirl.speed += storm.windDir * storm.windForce / swirl.size
            swirl.transparent = swirl.distanceWented * 255.0 / swirl.maxDistance

def windUpdate(dt: float)
    storm.windDirChangeTimer -= dt
    storm.windForceChangeTimer -= dt

    if storm.windDirChangeTimer <= 0.0
        storm.windDirChangeTimer = windDirTimer + (random_float(seed) - 0.5) * windDirTimer
        storm.windDir = normalize(storm.windDir + randVec() / 3.0)

    if storm.windForceChangeTimer <= 0.0
        storm.windForceChangeTimer = windForceTimer + (random_float(seed) - 0.5) * 10.0
        
        var windForceOffset: float = (random_float(seed) - 0.5) * maxWindForce
        if storm.windForce + windForceOffset > maxWindForce || storm.windForce + windForceOffset < -20.0
            storm.windForce -= windForceOffset
        else 
            storm.windForce += windForceOffset

def stormRender()
    for swirl in storm.swirls
        var transparent: float = ((getCosLookToObject(swirl.position) + 1.05) / 2.0) * swirl.transparent
        fill_circle(
            swirl.position.x - camera.screenPosition.x, 
            swirl.position.y - camera.screenPosition.y, 
            swirl.size, 
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
        "Rrrrr1";
        "Rrrrr2";
        "Rrrrr3";
        "Rrrrr4";
        "Rrrrr5"
    }];

    [{string
        "Ttttt1";
        "Ttttt2";
        "Ttttt3";
        "Ttttt4";
        "Ttttt5"
    }];

    [{string
        "Yyyyy1";
        "Yyyyy2";
        "Yyyyy3";
        "Yyyyy4";
        "Yyyyy5"
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
