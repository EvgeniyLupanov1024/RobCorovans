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
    generateMap()

def sceneUpdate(dt: float)
    playerUpdate(dt)
    corovanUpdate(dt)

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
    moveSpeedMax: float = 800.0
    speed: float2

def cameraUpdate(dt: float)
    camera.position += camera.speed * dt
    camera.speed += (player.position - camera.position) * camera.moveSpeed
    if length(camera.speed) > camera    .moveSpeedMax
        camera.speed = normalize(camera.speed) * camera.moveSpeedMax

    camera.speed *= 0.8

def cameraRender() 
    camera.screenPosition = float2(camera.position.x - float(get_screen_width()/2), camera.position.y - float(get_screen_height()/2))

    mapRender()
    // footprintsRender()
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
    exitTextFontColor: uint = 0xEEDDCC
    
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
    text_out(debugTextOffset, y, "", debugTextColor) 

def exitFromMapRender(transparent: float)
    set_font_size(exitTextFontSize)
    set_font_name("Shadower.ttf")
    text_out(getCenteringTextOffset(20, exitTextFontSize), 150, "Затеряться в песках", exitTextFontColor + floatToTransparent(transparent))

def lostInDesertRender()
    set_font_size(exitTextFontSize)
    set_font_name("Shadower.ttf")
    text_out(getCenteringTextOffset(23, exitTextFontSize), 150, "Вы затерялись в песках", exitTextFontColor + 0xFF000000)

    set_font_size(exitTextFontSize / 2)
    text_out(getCenteringTextOffset(38, exitTextFontSize / 2), 150 + exitTextFontSize * 2, "[нажмите F5, чтобы начать путишествие]", exitTextFontColor + 0xFF000000)

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
    moveSpeedMax: float = 600.0
    speed: float2

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
    if length(player.speed) > player.moveSpeedMax
        player.speed = normalize(player.speed) * player.moveSpeedMax 

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
            var titleTransparent: float = getCosLookToObject(map.titles[ih][iw].position) * 10.0 + 238.0
            var titleProximity: float = proximityToMapBorder(map.titles[ih][iw].position)
            titleTransparent *= titleProximity + ((1.0 - titleProximity) / 2.0)
            
            fill_convex_polygon([[float2[4]
                map.titles[ih][iw].position - camera.screenPosition; 
                map.titles[ih + 1][iw].position - camera.screenPosition; 
                map.titles[ih + 1][iw + 1].position - camera.screenPosition;
                map.titles[ih][iw + 1].position - camera.screenPosition
            ]], map.titles[ih][iw].color + floatToTransparent(titleTransparent))

def proximityToMapBorder(objPos: float2; deep: float = 0.0): float
    let farthestCoord: float = max(abs(objPos.x), abs(objPos.y))
    return min(max(0.0, halfMapSize + deep - farthestCoord) / borderArea, 1.0)

def titleFromPos(pos: float2): Title
    var posInMap = pos + float2(halfMapSize, halfMapSize)
    return map.titles[int(posInMap.x / titleSize)][int(posInMap.y / titleSize)]

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

struct Corovaner
    position: float2
    wayPointIndex: int = 0
    alive: bool = true
    isRobbed: bool = false

    moveSpeed: float = 5.0
    moveSpeedMax: float = 600.0
    speed: float2

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

        push(corovan.corovaners, corovaner)
        startPosition.y += titleSize

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

        corovaner.position += corovaner.speed * dt        
        var moveDir: float2 = map.road[corovaner.wayPointIndex] - corovaner.position
        if length(moveDir) < comeRange
            corovaner.wayPointIndex += 1

        corovaner.speed += normalize(moveDir) * corovaner.moveSpeed
        corovaner.speed *= 0.9
        if length(corovaner.speed) > corovaner.moveSpeedMax
            corovaner.speed = normalize(corovaner.speed) * corovaner.moveSpeedMax

def corovanRender()
    for corovaner in corovan.corovaners
        var titleTransparent: float = getCosLookToObject(corovaner.position) * 125.0 + 125.0
        titleTransparent *= proximityToMapBorder(corovaner.position, deepTransparentArea)

        fill_circle(
            corovaner.position.x - camera.screenPosition.x, 
            corovaner.position.y - camera.screenPosition.y, 
            16.0, 
            0xCCCCFF + floatToTransparent(titleTransparent)
        )

/*
 * ===============================================================================================================
 *
 * ELF
 *
 * ===============================================================================================================
 */

struct Elf
    position: float2 = float2(600.0, -titleSize)

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

struct Storm
    swirls: Swirl[maxSwirlCount]
    swirlInd: int = 0
    windDir: float2 = float2(1.0, 0.0)
    windForce: float = 100.0

struct Swirl
    position: float2
    distanceWented: float = 0.0
    maxDistance: float
    speed: float2

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
            swirl.speed += storm.windDir * storm.windForce
            swirl.transparent = swirl.distanceWented * 255.0 / swirl.maxDistance
        

def windUpdate(dt: float)
    return

def stormRender()
    for swirl in storm.swirls
        var transparent: float = ((getCosLookToObject(swirl.position) + 1.0) / 2.0) * swirl.transparent
        fill_circle(
            swirl.position.x - camera.screenPosition.x, 
            swirl.position.y - camera.screenPosition.y, 
            6.0, 
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
    maxCountFootprint: int = 4096
    maxLifetimeFootprint: int = 50
    footprintColorOffset: float3 = float3(5.0, 10.0, 8.0)
 
struct Footprints
    ring: Footprint[maxCountFootprint]
    startInd: int = 0
    endInd: int = 0
 
struct Footprint
    position: float2
    color: float3
 
    lifetime: float
    lifeProgress: float = 1.0
 
def addFootprint(position: float2)
    if (abs(position.x) > halfMapSize || abs(position.y) > halfMapSize)
        return

    var footprint: Footprint = Footprint()
    footprint.position = position
    footprint.lifetime = float(maxLifetimeFootprint - random_int(seed) % (maxLifetimeFootprint - maxLifetimeFootprint / 3))
    footprint.color = hexToFloat3(titleFromPos(footprint.position).color)
 
    footprints.ring[footprints.endInd] = footprint
    footprints.endInd++
    if footprints.endInd == maxCountFootprint
        footprints.endInd = 0
    if footprints.endInd == footprints.startInd
        footprints.startInd++
 
def getFootprintIndexs(): iterator<int>
    var it: iterator<int>
    if footprints.startInd <= footprints.endInd
        it <- [[for ind in range(footprints.startInd, footprints.endInd); ind + 0; where true]]
    else
        it <- [[for ind in range(footprints.startInd, footprints.endInd + maxCountFootprint); ind % maxCountFootprint; where true]]
    return <- it
 
def footprintsUpdate(dt: float)
    for ind in getFootprintIndexs()
        var footprint: Footprint = footprints.ring[ind] 
        if footprint.lifetime <= 0.0
            footprints.startInd++
            if footprints.startInd > maxCountFootprint
                footprints.startInd = 0
                continue
 
        footprints.ring[ind].lifetime -= dt
        // footprints.ring[ind].lifeProgress = 
 
def footprintsRender()
    for ind in getFootprintIndexs()
        var footprint: Footprint = footprints.ring[ind] 
        var transparent: float = 255.0
        fill_circle(
            footprint.position.x - camera.screenPosition.x, 
            footprint.position.y - camera.screenPosition.y, 
            5.0, 
            float3ToHex(footprint.color - footprintColorOffset * footprint.lifeProgress) + floatToTransparent(transparent)
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