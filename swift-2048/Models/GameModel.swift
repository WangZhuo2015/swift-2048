//
//  GameModel.swift
//  swift-2048
//
//  Created by Austin Zheng on 6/3/14.
//  Copyright (c) 2014 Austin Zheng. Released under the terms of the MIT license.
//

import UIKit

/// A protocol that establishes a way for the game model to communicate with its parent view controller.
//负责Model与Controller间的通信的Delegate
//仅能由Class继承
protocol GameModelProtocol : class {
    //分数更新
    func scoreChanged(score: Int)
    //移动一个Tile
    func moveOneTile(from: (Int, Int), to: (Int, Int), value: Int)
    //移动两个Tiles
    func moveTwoTiles(from: ((Int, Int), (Int, Int)), to: (Int, Int), value: Int)
    //添加一个Tiles
    func insertTile(location: (Int, Int), value: Int)
}

/// A class representing the game state and game logic for swift-2048. It is owned by a NumberTileGame view controller.
class GameModel : NSObject {
    let dimension : Int
    let threshold : Int
    //分数
    var score : Int = 0 {
        didSet {
            delegate.scoreChanged(score)
        }
    }
    //游戏板容器
    var gameboard: SquareGameboard<TileObject>
    //unowned,即delegate不会被释放
    unowned let delegate : GameModelProtocol
    //移动命令队列
    var queue: [MoveCommand]
    var timer: NSTimer
    //最大指令数量
    let maxCommands = 100
    //延时
    let queueDelay = 0.3
    /**
     构造方法
     
     - parameter d:
     - parameter t:        t description
     - parameter delegate: delegate description
     */
    init(dimension d: Int, threshold t: Int, delegate: GameModelProtocol) {
        dimension                                      = d
        threshold                                      = t
        self.delegate                                  = delegate
        queue                                          = [MoveCommand]()
        timer                                          = NSTimer()
        gameboard                                      = SquareGameboard(dimension: d, initialValue: .Empty)
        super.init()
    }
    
    /// Reset the game state.
    //重置游戏状态
    func reset() {
        //分数归零
        score                                          = 0
        //清空游戏板
        gameboard.setAll(.Empty)
        //清空操作队列
        queue.removeAll(keepCapacity: true)
        //计时器归零
        timer.invalidate()
    }
    
    /// Order the game model to perform a move (because the user swiped their finger). The queue enforces a delay of a few
    /// milliseconds between each move.
    //将一步操作加入队列
    func queueMove(direction: MoveDirection, completion: (Bool) -> ()) {
        //如果操作太多则不加入
        guard queue.count <= maxCommands else {
            // Queue is wedged. This should actually never happen in practice.
            return
        }
        //加入队列
        queue.append(MoveCommand(direction: direction, completion: completion))
        //如果计时器可用
        if !timer.valid {
            // Timer isn't running, so fire the event immediately
            timerFired(timer)
        }
    }
    
    //------------------------------------------------------------------------------------------------------------------//
    
    /// Inform the game model that the move delay timer fired. Once the timer fires, the game model tries to execute a
    /// single move that changes the game state.
    func timerFired(_: NSTimer) {
        //如果队列为空则返回
        if queue.count == 0 {
            return
        }
        // Go through the queue until a valid command is run or the queue is empty
        //标示是否改动成功的变量
        var changed = false
        //执行队列中的Command
        while queue.count > 0 {
//            //取出第一个command
//            let command = queue[0]
//            //移除第一个元素
//            queue.removeAtIndex(0)
            
            //改进
            let command = queue.removeAtIndex(0)
            //changed代表是否command执行成功
            changed  = performMove(command.direction)
            //执行completionHandle
            command.completion(changed)
            //如果有改动则跳出
            if changed {
                // If the command doesn't change anything, we immediately run the next one
                break
            }
        }
        if changed {
            timer = NSTimer.scheduledTimerWithTimeInterval(queueDelay, target: self, selector: #selector(GameModel.timerFired(_:)), userInfo: nil, repeats: false)
        }
    }
    
    //------------------------------------------------------------------------------------------------------------------//
    
    /// Insert a tile with a given value at a position upon the gameboard.
    //在gameboard上插入一个Tile
    func insertTile(position: (Int, Int), value: Int) {
        let (x, y) = position
        if case .Empty = gameboard[x, y] {
            gameboard[x, y] = TileObject.Tile(value)
            delegate.insertTile(position, value: value)
        }
    }
    
    /// Insert a tile with a given value at a random open position upon the gameboard.
    //在随机位置插入一个Tile
    func insertTileAtRandomLocation(value: Int) {
        //空闲位置坐标元组数组
        let openSpots                                  = gameboardEmptySpots()
        //如果没有空位
        if openSpots.isEmpty {
            // No more open spots; don't even bother
            return
        }
        // Randomly select an open spot, and put a new tile there
        //随机一个值
        let idx                                        = Int(arc4random_uniform(UInt32(openSpots.count-1)))
        let (x, y)                                     = openSpots[idx]
        insertTile((x, y), value: value)
    }
    
    /// Return a list of tuples describing the coordinates of empty spots remaining on the gameboard.
    //找出空格的位置
    func gameboardEmptySpots() -> [(Int, Int)] {
        var buffer : [(Int, Int)]                      = []
        //遍历矩阵
        for i in 0..<dimension {
            for j in 0..<dimension {
                if case .Empty                                 = gameboard[i, j] {
                    buffer                                         += [(i, j)]
                }
            }
        }
        return buffer
    }
    
    //------------------------------------------------------------------------------------------------------------------//
    
    func tileBelowHasSameValue(location: (Int, Int), _ value: Int) -> Bool {
        let (x, y) = location
        //如果是最底下一行则return false
        guard y != dimension - 1 else {
            return false
        }
        //如果下面的一个Tile值为value则return true
        if case let .Tile(v) = gameboard[x, y+1] {
            return v == value
        }
        return false
    }
    
    func tileToRightHasSameValue(location: (Int, Int), _ value: Int) -> Bool {
        let (x, y)                                     = location
        guard x != dimension - 1 else {
            return false
        }
        if case let .Tile(v)                           = gameboard[x+1, y] {
            return v == value
        }
        return false
    }
    //判断游戏是否结束
    func userHasLost() -> Bool {
        //如果有空位则未结束
        guard gameboardEmptySpots().isEmpty else {
            // Player can't lose before filling up the board
            return false
        }
        
        // Run through all the tiles and check for possible moves
        //遍历矩阵
        for i in 0..<dimension {
            for j in 0..<dimension {
                switch gameboard[i, j] {
                    //若出现空位则有问题
                case .Empty:
                    assert(false, "Gameboard reported itself as full, but we still found an empty tile. This is a logic error.")
                case let .Tile(v):
                    //判断旁边是否有一样的Tile
                    if tileBelowHasSameValue((i, j), v) || tileToRightHasSameValue((i, j), v) {
                        return false
                    }
                }
            }
        }
        return true
    }
    //玩家胜利
    func userHasWon() -> (Bool, (Int, Int)?) {
        //遍历矩阵寻找最大的Tile是否超过排行榜Tile最大值
        for i in 0..<dimension {
            for j in 0..<dimension {
                // Look for a tile with the winning score or greater
                if case let .Tile(v) = gameboard[i, j] where v >= threshold {
                    return (true, (i, j))
                }
            }
        }
        return (false, nil)
    }
    
    //------------------------------------------------------------------------------------------------------------------//
    
    // Perform all calculations and update state for a single move.
    //执行MoveCommand
    func performMove(direction: MoveDirection) -> Bool {
        // Prepare the generator closure. This closure differs in behavior depending on the direction of the move. It is
        // used by the method to generate a list of tiles which should be modified. Depending on the direction this list
        // may represent a single row or a single column, in either direction.
        //定义一个遍历器
        let coordinateGenerator: (Int) -> [(Int, Int)] = { (iteration: Int) -> [(Int, Int)] in
            //构建一个矩阵
            var buffer = Array<(Int, Int)>(count:self.dimension, repeatedValue: (0, 0))
            for i in 0..<self.dimension {
                switch direction {
                case .Up: buffer[i]                            = (i, iteration)
                case .Down: buffer[i]                          = (self.dimension - i - 1, iteration)
                case .Left: buffer[i]                          = (iteration, i)
                case .Right: buffer[i]                         = (iteration, self.dimension - i - 1)
                }
            }
            return buffer
        }
        
        var atLeastOneMove                             = false
        for i in 0..<dimension {
            // Get the list of coords
            let coords                                     = coordinateGenerator(i)
            
            // Get the corresponding list of tiles
            let tiles                                      = coords.map() { (c: (Int, Int)) -> TileObject in
                let (x, y)                                     = c
                return self.gameboard[x, y]
            }
            
            // Perform the operation
            let orders                                     = merge(tiles)
            atLeastOneMove                                 = orders.count > 0 ? true : atLeastOneMove
            
            // Write back the results
            for object in orders {
                switch object {
                case let MoveOrder.SingleMoveOrder(s, d, v, wasMerge):
                    // Perform a single-tile move
                    let (sx, sy)                                   = coords[s]
                    let (dx, dy)                                   = coords[d]
                    if wasMerge {
                        score                                          += v
                    }
                    gameboard[sx, sy]                              = TileObject.Empty
                    gameboard[dx, dy]                              = TileObject.Tile(v)
                    delegate.moveOneTile(coords[s], to: coords[d], value: v)
                case let MoveOrder.DoubleMoveOrder(s1, s2, d, v):
                    // Perform a simultaneous two-tile move
                    let (s1x, s1y)                                 = coords[s1]
                    let (s2x, s2y)                                 = coords[s2]
                    let (dx, dy)                                   = coords[d]
                    score                                          += v
                    gameboard[s1x, s1y]                            = TileObject.Empty
                    gameboard[s2x, s2y]                            = TileObject.Empty
                    gameboard[dx, dy]                              = TileObject.Tile(v)
                    delegate.moveTwoTiles((coords[s1], coords[s2]), to: coords[d], value: v)
                }
            }
        }
        return atLeastOneMove
    }
    
    //------------------------------------------------------------------------------------------------------------------//
    
    /// When computing the effects of a move upon a row of tiles, calculate and return a list of ActionTokens
    /// corresponding to any moves necessary to remove interstital space. For example, |[2][ ][ ][4]| will become
    /// |[2][4]|.
    func condense(group: [TileObject]) -> [ActionToken] {
        var tokenBuffer                                = [ActionToken]()
        for (idx, tile) in group.enumerate() {
            // Go through all the tiles in 'group'. When we see a tile 'out of place', create a corresponding ActionToken.
            switch tile {
            case let .Tile(value) where tokenBuffer.count == idx:
                tokenBuffer.append(ActionToken.NoAction(source: idx, value: value))
            case let .Tile(value):
                tokenBuffer.append(ActionToken.Move(source: idx, value: value))
            default:
                break
            }
        }
        return tokenBuffer;
    }
    
    class func quiescentTileStillQuiescent(inputPosition: Int, outputLength: Int, originalPosition: Int) -> Bool {
        // Return whether or not a 'NoAction' token still represents an unmoved tile
        return (inputPosition == outputLength) && (originalPosition == inputPosition)
    }
    
    /// When computing the effects of a move upon a row of tiles, calculate and return an updated list of ActionTokens
    /// corresponding to any merges that should take place. This method collapses adjacent tiles of equal value, but each
    /// tile can take part in at most one collapse per move. For example, |[1][1][1][2][2]| will become |[2][1][4]|.
    func collapse(group: [ActionToken]) -> [ActionToken] {
        
        
        var tokenBuffer                                = [ActionToken]()
        var skipNext                                   = false
        for (idx, token) in group.enumerate() {
            if skipNext {
                // Prior iteration handled a merge. So skip this iteration.
                skipNext                                       = false
                continue
            }
            switch token {
            case .SingleCombine:
                assert(false, "Cannot have single combine token in input")
            case .DoubleCombine:
                assert(false, "Cannot have double combine token in input")
            case let .NoAction(s, v)
                where (idx < group.count-1
                    && v == group[idx+1].getValue()
                    && GameModel.quiescentTileStillQuiescent(idx, outputLength: tokenBuffer.count, originalPosition: s)):
                // This tile hasn't moved yet, but matches the next tile. This is a single merge
                // The last tile is *not* eligible for a merge
                let next                                       = group[idx+1]
                let nv                                         = v + group[idx+1].getValue()
                skipNext                                       = true
                tokenBuffer.append(ActionToken.SingleCombine(source: next.getSource(), value: nv))
            case let t where (idx < group.count-1 && t.getValue() == group[idx+1].getValue()):
                // This tile has moved, and matches the next tile. This is a double merge
                // (The tile may either have moved prevously, or the tile might have moved as a result of a previous merge)
                // The last tile is *not* eligible for a merge
                let next                                       = group[idx+1]
                let nv                                         = t.getValue() + group[idx+1].getValue()
                skipNext                                       = true
                tokenBuffer.append(ActionToken.DoubleCombine(source: t.getSource(), second: next.getSource(), value: nv))
            case let .NoAction(s, v) where !GameModel.quiescentTileStillQuiescent(idx, outputLength: tokenBuffer.count, originalPosition: s):
                // A tile that didn't move before has moved (first cond.), or there was a previous merge (second cond.)
                tokenBuffer.append(ActionToken.Move(source: s, value: v))
            case let .NoAction(s, v):
                // A tile that didn't move before still hasn't moved
                tokenBuffer.append(ActionToken.NoAction(source: s, value: v))
            case let .Move(s, v):
                // Propagate a move
                tokenBuffer.append(ActionToken.Move(source: s, value: v))
            default:
                // Don't do anything
                break
            }
        }
        return tokenBuffer
    }
    
    /// When computing the effects of a move upon a row of tiles, take a list of ActionTokens prepared by the condense()
    /// and convert() methods and convert them into MoveOrders that can be fed back to the delegate.
    func convert(group: [ActionToken]) -> [MoveOrder] {
        var moveBuffer                                 = [MoveOrder]()
        for (idx, t) in group.enumerate() {
            switch t {
            case let .Move(s, v):
                moveBuffer.append(MoveOrder.SingleMoveOrder(source: s, destination: idx, value: v, wasMerge: false))
            case let .SingleCombine(s, v):
                moveBuffer.append(MoveOrder.SingleMoveOrder(source: s, destination: idx, value: v, wasMerge: true))
            case let .DoubleCombine(s1, s2, v):
                moveBuffer.append(MoveOrder.DoubleMoveOrder(firstSource: s1, secondSource: s2, destination: idx, value: v))
            default:
                // Don't do anything
                break
            }
        }
        return moveBuffer
    }
    
    /// Given an array of TileObjects, perform a collapse and create an array of move orders.
    func merge(group: [TileObject]) -> [MoveOrder] {
        // Calculation takes place in three steps:
        // 1. Calculate the moves necessary to produce the same tiles, but without any interstital space.
        // 2. Take the above, and calculate the moves necessary to collapse adjacent tiles of equal value.
        // 3. Take the above, and convert into MoveOrders that provide all necessary information to the delegate.
        return convert(collapse(condense(group)))
    }
}
