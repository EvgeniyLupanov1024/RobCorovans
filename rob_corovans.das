require daslib/media
require random
require math
require strings

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

    if get_key_down(VK_C)
        startCorovan()

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
    initEntities()
    generateMap()

def sceneUpdate(dt: float)
    playerUpdate(dt)
    corovanUpdate(dt)

    stormUpdate(dt)
    footprintsUpdate(dt)

    InteractableUpdate(dt)
    cameraUpdate(dt)

def sceneRender()
    cameraRender()

def initEntities()
    player.distToFootprint = random_float(seed) * player.stepLen

    storm.windDir = randVec()

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

    InteractableRender()
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
    exitTextFontColor: uint = 0xFFEEDDCC
    
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
    text_out(debugTextOffset, y, "Индексы кольца: {footprints.startInd} - {footprints.endInd}", debugTextColor) 

    y += debugTextOffset
    text_out(debugTextOffset, y, "Ветер: {storm.windDir} | {storm.windForce}", debugTextColor)

def exitFromMapRender(transparent: float)
    set_font_size(exitTextFontSize)
    set_font_name("Shadower.ttf")
    text_out(getCenteringTextOffset(20, exitTextFontSize), 150, "Затеряться в песках", exitTextFontColor + floatToTransparent(transparent))

def lostInDesertRender()
    set_font_size(exitTextFontSize)
    set_font_name("Shadower.ttf")
    text_out(getCenteringTextOffset(23, exitTextFontSize), 150, "Вы затерялись в песках", exitTextFontColor)

    set_font_size(exitTextFontSize / 2)
    text_out(getCenteringTextOffset(38, exitTextFontSize / 2), 150 + exitTextFontSize * 2, "[нажмите F5, чтобы начать путишествие]", exitTextFontColor)

def getCenteringTextOffset(len: int; fontSize: int): int
    return (get_screen_width() - fontSize * (len / 2)) / 2

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
    interactTextTranparentStep: float = 16.0
    interactTextOffset: float2 = float2(0.0, 30.0)

var 
    pInteractables: array<InteractText>

struct Interactable
    position: float2
    interactText: string = "[F] interact"
    interactTextTransparent: float = 0.0
    interactTextOffset: float2 = interactTextOffset

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

def InteractableUpdate(dt: float)
    var pNearestInteractable: Interactable? = getNearestInteractable()
    var haveInteractable: bool = false

    var idx: int = length(pInteractables) - 1
    while idx >= 0
        var pInteractable: Interactable? = *pInteractables[idx]

        if pInteractable != pNearestInteractable
            *pInteractable.interactTextTransparent = max(*pInteractable.interactTextTransparent - interactTextTranparentStep, 0.0)
            if *pInteractable.interactable.interactTextTransparent == 0.0
                erase(pInteractables, idx)
        
        else if *pInteractable.interactTextTransparent == 255.0
            *pInteractable.interactTextTransparent = min(*pInteractable.interactTextTransparent + interactTextTranparentStep, 255.0)
            haveInteractable = true

        idx--

    if !haveInteractable && pNearestInteractable != null
        push(pInteractables, pNearestInteractable)

    if pNearestInteractable != null && get_key_down(VK_F)
        *pNearestInteractable.interact()

def InteractableRender()
    for pInteractable in pInteractables
        var interactable: Interactable = *pInteractable
        
        var transparent: float = interactText.transparent
        transparent = getCosLookToObject(interactable.position) * 125.0 + 125.0
        transparent *= proximityToMapBorder(interactable.position, deepTransparentArea)
        
        fill_rect(
            interactable.position.x - camera.screenPosition.x, 
            interactable.position.y - camera.screenPosition.y, 
            100.0 + interactText.offset.x,
            50.0 + interactText.offset.y, 
            0xEEDDBB + floatToTransparent(transparent)
        )

/*
 * ===============================================================================================================
 *
 * DIALOGABLE
 *
 * ===============================================================================================================
 */

struct Dialogable
    position: float2
    dialog: Dialog = Dialog()

struct Dialog


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

struct Corovaner: Interactable
    override position: float2
    wayPointIndex: int = 0
    alive: bool = true
    isRobbed: bool = false

    moveSpeed: float = 5.0
    speed: float2

    stepLen: float = 60.0
    distToFootprint: float
    leftFootprint: bool = false

    override interactText = "[F] грабить"

def startCorovan()
    if corovan.isStart
        return

    corovan.isStart = true
    corovan.isRobbed = false

    var startPosition: float2 = map.road[0]
    for i in range(5)
        var corovaner: Corovaner = Corovaner()
        corovaner.position = startPosition
        corovaner.wayPointIndex = 0
        corovaner.stepLen += (random_float(seed) - 0.5) * 5.0
        corovaner.distToFootprint = random_float(seed) * corovaner.stepLen

        push(corovan.corovaners, corovaner)
        startPosition.y += titleSize * 2.5

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
    if corovan.isRobbed
        corovan.isStart = false

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

/*
 * ===============================================================================================================
 *
 * ELF
 *
 * ===============================================================================================================
 */

struct Elf: Interactable
    override position: float2 = float2(600.0, -titleSize)

    override interactText = "[F] говорить"

def elfRender()
    var titleTransparent: float = getCosLookToObject(elf.position) * 125.0 + 125.0
    fill_circle(
        elf.position.x - camera.screenPosition.x, 
        elf.position.y - camera.screenPosition.y, 
        16.0, 
        0xCCFFCC + floatToTransparent(titleTransparent)
    )

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
                if footprints.startInd > maxCountFootprint
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
    
/*
 * ===============================================================================================================
 *
 * DIALOGOS
 *
 * ===============================================================================================================
 */

/*
Под палящим Солнцем
Нет ничего лучше
Припекает.. Ты не находишь?

===(акт 1)
Ты тоже пришёл сюда грабить корованы?

Знаешь, а я ведь тоже когда-то был корованщиком. Ходил туда-обратно.

И мысли мои были заняты не 
Да, вот так просто. Корова.
Когда-то, когда эта пустыня зеленела …
Это очень удобно: корова может быть как вьючным животным, так и источником пищи.
Такой подход позволял древним корованерам пересекать огромные расстояния.
Не смейся! Этимология — это тебе не хухры-мухры. Она может пролить свет на самые тёмные, самые древние времена человеческой цивилизации. 

Если хочешь можешь пока вздремнуть или позагорать. Я обязательно тебе скажу, когда увижу корован.
Можешь взять мой плащ, а то потом ещё неделю будешь песок из себя вытряхивать.
Что-то не так? 
Мне показалось, или ты стесняешься снимать при мне броню?
Ты же не боишься, что я тебя ограблю? только потому, что я, как и ты, граблю корованы.

===(акт 3)
Что это у тебя тут? на воротнике.
ХА! купился! у тебя и воротника-та нет.
Когда ты направился ко мне во второй раз, ты напомнил мне ребёнка спешащего 
*задумался*
Вот как интересно получается: когда я только встретил тебя, я собирался тебя ограбить. 
Я был готов вытряхнуть тебя из твоих же сапог. Поднять за ноги и трясти как свежепойманную рыбу. 
А сейчас даже не думаю об этом.
Всего два рейда, а я уже думаю о тебе как о напарнике… Мда.
Напарник
на-па-рник
Никогда бы не подумал, что вновь произнесу это слово. После всего того, что.. … Ну да не будем о этом.

*напряжённо молчит*
Знаешь, мне нужно кое в чём тебе признаться. 
На самом деле я не эльф. Я КАДЖИТ. И зовут меня М’Айк. 
Серьёзно! Мы же в пустыне! Какие тут могут быть эльфы?!
Просто меня попросили побыть эльфом. Для тебя.
Нет, нет, я не жалуюсь. Кто-то же должен быть эльфом. Так уж всё устроено.
Я при деле. И довольно приятном. Можно было бы даже сказать “не пыльным”, если бы не… ну, ты знаешь.. песок. Он здесь повсюду. Даже в воздухе.
Мда.
Ладно. Классно поболтали. Я наверное пойду. Но если ты захочешь, я останусь. Только скажи.

Ты свободен, как птица. Мохнатая, четырёхлапая, метр семьдесят пять в холке птица.
Я бы хотел ещё подождать корована. С тобой. 

Мур-мур-мяу

===== ===== ===== ===== =====(на горизонте)
Я.. я вижу их. Вон там, за тем барханом. Это КОРОВАНЩИКИ!
Это он! Я снова его вижу! КОРОВАН на горизонте!
Потом договорим! Грабь КОРОВАНЫ!

===== ===== ===== ===== =====(корованщики)
Что? Нет. Меня грабить нельзя. Я против и отказываюсь отдавать вам все свои ценности.
Подходите! У меня Вы найдёте самые удивительные товары! Что Вам приглянулось? В смысле ничего? В смысле хотите ограбить?
Конечно меня можно ограбить. У Вас ведь есть два экземпляра 142ой справки? Ну формы А142.. той, что для отчётности о проделанном грабеже.
Вы точно хотите ограбить корован? Я слышал это вредно для здоровья.
Отличная шутка) Я почти поверил, что Вы настоящий грабитель. Такие круглые глаза, такой озлобленный взгляд исподлобья. Потрясающе.

===
У нас самые низкие цены в Анк-Морпорке, за счёт того, что мы экономим на охране корована.
Я бы с радостью дал себя ограбить, но сегодня последний четверг месяца - не приёмный день для грабителей - увы.

===== ===== ===== ===== =====(описание)
Диалоговая игра, сделанная во время хакатона по daScript по известному всем тз (https://wikireality.ru/wiki/%D0%93%D1%80%D0%B0%D0%B1%D0%B8%D1%82%D1%8C_%D0%BA%D0%BE%D1%80%D0%BE%D0%B2%D0%B0%D0%BD%D1%8B)

User Story

Фичи
можно грабить корованы
ветер влияет на скорость передвижения

Установка
*/