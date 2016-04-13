//
//  AuxiliaryModels.swift
//  swift-2048
//
//  Created by Austin Zheng on 6/5/14.
//  Copyright (c) 2014 Austin Zheng. Released under the terms of the MIT license.
//

import Foundation

/// An enum representing directions supported by the game model.
//枚举,描述方向
enum MoveDirection {
  case Up, Down, Left, Right
}

/// An enum representing a movement command issued by the view controller as the result of the user swiping.
//每一个MoveCommand包含方向和CompletionHandle
struct MoveCommand {
  let direction : MoveDirection
  let completion : (Bool) -> ()
}

/// An enum representing a 'move order'. This is a data structure the game model uses to inform the view controller
/// which tiles on the gameboard should be moved and/or combined.
//
enum MoveOrder {
  case SingleMoveOrder(source: Int, destination: Int, value: Int, wasMerge: Bool)
  case DoubleMoveOrder(firstSource: Int, secondSource: Int, destination: Int, value: Int)
}

/// An enum representing either an empty space or a tile upon the board.
//描述tile的enum
enum TileObject {
  case Empty
  case Tile(Int)
}

/// An enum representing an intermediate result used by the game logic when figuring out how the board should change as
/// the result of a move. ActionTokens are transformed into MoveOrders before being sent to the delegate.
enum ActionToken {
  case NoAction(source: Int, value: Int)
  case Move(source: Int, value: Int)
  case SingleCombine(source: Int, value: Int)
  case DoubleCombine(source: Int, second: Int, value: Int)

  // Get the 'value', regardless of the specific type
    //获得Value
  func getValue() -> Int {
    switch self {
    case let .NoAction(_, v): return v
    case let .Move(_, v): return v
    case let .SingleCombine(_, v): return v
    case let .DoubleCombine(_, _, v): return v
    }
  }
  // Get the 'source', regardless of the specific type
    //获得Source
  func getSource() -> Int {
    switch self {
    case let .NoAction(s, _): return s
    case let .Move(s, _): return s
    case let .SingleCombine(s, _): return s
    case let .DoubleCombine(s, _, _): return s
    }
  }
}

/// A struct representing a square gameboard. Because this struct uses generics, it could conceivably be used to
/// represent state for many other games without modification.
struct SquareGameboard<T> {
    //矩阵在一个方向的最大元素数量
  let dimension : Int
    //矩阵保存在数组中
  var boardArray : [T]

    //矩阵构造方法
  init(dimension d: Int, initialValue: T) {
    dimension = d
    boardArray = [T](count:d*d, repeatedValue:initialValue)
  }

    //重载[]运算符,取矩阵元素
  subscript(row: Int, col: Int) -> T {
    get {
      assert(row >= 0 && row < dimension)
      assert(col >= 0 && col < dimension)
      return boardArray[row*dimension + col]
    }
    set {
      assert(row >= 0 && row < dimension)
      assert(col >= 0 && col < dimension)
      boardArray[row*dimension + col] = newValue
    }
  }

  // We mark this function as 'mutating' since it changes its 'parent' struct.
    //要修改struct成员的值必须加mutating标签
  mutating func setAll(item: T) {
    for i in 0..<dimension {
      for j in 0..<dimension {
        self[i, j] = item
      }
    }
  }
}
