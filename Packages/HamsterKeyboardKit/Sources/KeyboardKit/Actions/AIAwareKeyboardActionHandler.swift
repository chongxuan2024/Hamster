//
//  AIAwareKeyboardActionHandler.swift
//
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import OSLog
import UIKit

/**
 支持AI查询功能的键盘动作处理器

 这个处理器包装了StandardKeyboardActionHandler，并添加了对AI查询视图的键盘输入路由功能。
 当AI查询模式激活时，字符输入会被路由到AI查询视图，而不是正常的文本输入。
 */
public class AIAwareKeyboardActionHandler: StandardKeyboardActionHandler {

  /// AI查询视图的键盘输入处理回调
  public var aiInputHandler: ((String) -> Bool)?

  /// AI查询模式是否激活
  private var isAIQueryModeActive: Bool = false

  /// RIME上下文引用
  private let rimeContextRef: RimeContext

  public override init(
    controller: KeyboardController?,
    keyboardContext: KeyboardContext,
    rimeContext: RimeContext,
    keyboardBehavior: KeyboardBehavior,
    autocompleteContext: AutocompleteContext,
    keyboardFeedbackHandler: KeyboardFeedbackHandler,
    spaceDragGestureHandler: DragGestureHandler
  ) {
    self.rimeContextRef = rimeContext
    super.init(
      controller: controller,
      keyboardContext: keyboardContext,
      rimeContext: rimeContext,
      keyboardBehavior: keyboardBehavior,
      autocompleteContext: autocompleteContext,
      keyboardFeedbackHandler: keyboardFeedbackHandler,
      spaceDragGestureHandler: spaceDragGestureHandler
    )
    Logger.statistics.debug("AIAwareKeyboardActionHandler: 初始化AI感知键盘动作处理器")
  }

  /// 设置AI查询模式状态
  public func setAIQueryMode(active: Bool) {
    isAIQueryModeActive = active
    Logger.statistics.debug("AIAwareKeyboardActionHandler: AI查询模式状态: \(active)")
  }

  public override func handle(_ gesture: KeyboardGesture, on action: KeyboardAction, replaced: Bool) {
//    Logger.statistics.debug("AIAwareKeyboardActionHandler: 处理手势 \(gesture) 操作 \(action)")

    // 如果是退格键且AI查询模式激活，优先路由到AI查询视图
    if gesture == .release, action == .backspace, isAIQueryModeActive {
        
        guard !rimeContext.userInputKey.isEmpty else {
            if let handler = aiInputHandler, handler("\u{8}") {
              Logger.statistics.debug("AIAwareKeyboardActionHandler: 退格键已被AI查询视图处理")
              return // 输入已被AI查询视图处理，不再继续正常流程
            }

          return
        }
        
    }
      
      // 如果是空格键且AI查询模式激活，优先路由到AI查询视图
      if gesture == .release, action == .space, isAIQueryModeActive {
          
          guard !rimeContext.userInputKey.isEmpty else {
              if let handler = aiInputHandler, handler(" ") {
                Logger.statistics.debug("AIAwareKeyboardActionHandler: 空格键已被AI查询视图处理")
                return // 输入已被AI查询视图处理，不再继续正常流程
              }
              return 
          }
      }
      
      

    // 继续正常的键盘处理流程
    super.handle(gesture, on: action, replaced: replaced)

    // TODO 处理swapUp、swapDown的gesture

    // 处理完成后，如果是字符输入且AI查询模式激活，尝试将RIME处理后的结果传递给AI查询视图
    if gesture == .release, case let .character(char) = action, isAIQueryModeActive {
      // 通过延迟调用确保RIME引擎已经处理完成
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
        guard let self = self else { return }

        // 获取RIME处理后的提交文本，如果有的话传递给AI查询视图
        let commitText = self.rimeContextRef.commitText
        if !commitText.isEmpty {
          self.rimeContextRef.resetCommitText()
          _ = self.aiInputHandler?(commitText)
          Logger.statistics.debug("AIAwareKeyboardActionHandler: RIME提交文本 '\(commitText)' 已传递给AI查询视图")
        } else if !self.rimeContextRef.userInputKey.isEmpty {
          // 如果有用户输入但还没有提交文本，说明正在输入中文，暂时不处理
          Logger.statistics.debug("AIAwareKeyboardActionHandler: 中文输入进行中，用户输入: '\(self.rimeContextRef.userInputKey)'")
        } else {
          // 如果没有RIME处理，直接传递原始字符（处理英文输入）
          _ = self.aiInputHandler?(char)
          Logger.statistics.debug("AIAwareKeyboardActionHandler: 原始字符 '\(char)' 已传递给AI查询视图")
        }
      }
    }

      // TODO 处理完成后，如果是字符输入且AI查询模式激活，尝试将RIME处理后的结果传递给AI查询视图
      if gesture == .release, case let .symbol(char) = action, isAIQueryModeActive {
        // 通过延迟调用确保RIME引擎已经处理完成
          // 如果没有RIME处理，直接传递原始字符（处理英文输入）
          _ = self.aiInputHandler?(char.char)
          Logger.statistics.debug("AIAwareKeyboardActionHandler: 原始字符 '\(char.char)' 已传递给AI查询视图")
      }

  }
}
