//
//  TileView.swift
//  swift-2048
//
//  Created by Austin Zheng on 6/3/14.
//  Copyright (c) 2014 Austin Zheng. Released under the terms of the MIT license.
//

import UIKit

/// A view representing a single swift-2048 tile.
//TileView
class TileView : UIView {
    //Tile的值
  var value : Int = 0 {
    //赋值后修改颜色及显示的数字
    didSet {
      backgroundColor = delegate.tileColor(value)
      numberLabel.textColor = delegate.numberColor(value)
      numberLabel.text = "\(value)"
    }
  }
    //颜色\外观代理
  unowned let delegate : AppearanceProviderProtocol
    //上面显示的数字
  let numberLabel : UILabel

  required init(coder: NSCoder) {
    fatalError("NSCoding not supported")
  }
    //构造方法
    /**
     构造方法
     
     - parameter position: 位置
     - parameter width:    宽度\高度
     - parameter value:    值
     - parameter radius:   圆角
     - parameter d:        代理
     
     */
  init(position: CGPoint, width: CGFloat, value: Int, radius: CGFloat, delegate d: AppearanceProviderProtocol) {
    delegate = d
    numberLabel = UILabel(frame: CGRectMake(0, 0, width, width))
    numberLabel.textAlignment = NSTextAlignment.Center
    numberLabel.minimumScaleFactor = 0.5
    numberLabel.font = delegate.fontForNumbers()

    super.init(frame: CGRectMake(position.x, position.y, width, width))
    addSubview(numberLabel)
    layer.cornerRadius = radius

    self.value = value
    backgroundColor = delegate.tileColor(value)
    numberLabel.textColor = delegate.numberColor(value)
    numberLabel.text = "\(value)"
  }
}
