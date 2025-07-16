//
//  HamsterKeyboardActionHandler.swift
//
//
//  Created by AI on 2024/1/1.
//

import Combine
import HamsterKit
import OSLog
import UIKit

/**
 仓输入法自定义动作处理器
 扩展标准动作处理器以支持功能管理视图的显示和隐藏
 */
open class HamsterKeyboardActionHandler: StandardKeyboardActionHandler {
  
  // 弱引用到KeyboardRootView，避免循环引用
  weak var keyboardRootView: KeyboardRootView?
  
  override public init(
    controller: KeyboardController?,
    keyboardContext: KeyboardContext,
    rimeContext: RimeContext,
    keyboardBehavior: KeyboardBehavior,
    autocompleteContext: AutocompleteContext,
    keyboardFeedbackHandler: KeyboardFeedbackHandler,
    spaceDragGestureHandler: DragGestureHandler
  ) {
    super.init(
      controller: controller,
      keyboardContext: keyboardContext,
      rimeContext: rimeContext,
      keyboardBehavior: keyboardBehavior,
      autocompleteContext: autocompleteContext,
      keyboardFeedbackHandler: keyboardFeedbackHandler,
      spaceDragGestureHandler: spaceDragGestureHandler
    )
  }
  
  /**
   重写动作处理方法，添加对自定义动作的处理
   */
  override open func handle(_ gesture: KeyboardGesture, on action: KeyboardAction, replaced: Bool) {
    // 首先检查是否是我们的自定义动作
    if gesture == .release, case .custom(let actionName) = action {
      handleCustomAction(actionName)
      return
    }
    
    // 如果不是自定义动作，调用父类的处理方法
    super.handle(gesture, on: action, replaced: replaced)
  }
  
  /**
   处理自定义动作
   */
  private func handleCustomAction(_ actionName: String) {
    guard let rootView = keyboardRootView else {
      Logger.statistics.warning("KeyboardRootView not set in HamsterKeyboardActionHandler")
      return
    }
    
    switch actionName {
    case "showClipboard":
      showClipboardManager(rootView)
    case "hideClipboard":
      hideClipboardManager(rootView)
    case "showCommonWords":
      showCommonWordsManager(rootView)
    case "hideCommonWords":
      hideCommonWordsManager(rootView)
    case "showKnowledgeBase":
      showKnowledgeBaseManager(rootView)
    case "hideKnowledgeBase":
      hideKnowledgeBaseManager(rootView)
    case "showSettings":
      showSettings()
    default:
      Logger.statistics.info("Unknown custom action: \(actionName)")
    }
  }
  
  // MARK: - 功能视图显示和隐藏方法
  
  private func showClipboardManager(_ rootView: KeyboardRootView) {
    hideAllFunctionViews(rootView)
    UIView.animate(withDuration: 0.25) {
      rootView.clipboardManagerView.isHidden = false
      rootView.primaryKeyboardView.isHidden = true
    }
  }
  
  private func hideClipboardManager(_ rootView: KeyboardRootView) {
    UIView.animate(withDuration: 0.25) {
      rootView.clipboardManagerView.isHidden = true
      rootView.primaryKeyboardView.isHidden = false
    }
  }
  
  private func showCommonWordsManager(_ rootView: KeyboardRootView) {
    hideAllFunctionViews(rootView)
    UIView.animate(withDuration: 0.25) {
      rootView.commonWordsManagerView.isHidden = false
      rootView.primaryKeyboardView.isHidden = true
    }
  }
  
  private func hideCommonWordsManager(_ rootView: KeyboardRootView) {
    UIView.animate(withDuration: 0.25) {
      rootView.commonWordsManagerView.isHidden = true
      rootView.primaryKeyboardView.isHidden = false
    }
  }
  
  private func showKnowledgeBaseManager(_ rootView: KeyboardRootView) {
    hideAllFunctionViews(rootView)
    UIView.animate(withDuration: 0.25) {
      rootView.knowledgeBaseManagerView.isHidden = false
      rootView.primaryKeyboardView.isHidden = true
    }
  }
  
  private func hideKnowledgeBaseManager(_ rootView: KeyboardRootView) {
    UIView.animate(withDuration: 0.25) {
      rootView.knowledgeBaseManagerView.isHidden = true
      rootView.primaryKeyboardView.isHidden = false
    }
  }
  
  private func showSettings() {
    // 这里可以打开设置界面
    Logger.statistics.info("Show settings requested")
    // 可以通过URL Scheme打开主应用的设置页面
    if let url = URL(string: "hamster://settings") {
      keyboardController?.dismissKeyboard()
      // 在iOS中，键盘扩展不能直接打开URL，需要通过其他方式
      // 这里可以考虑使用自定义协议或通知机制
    }
  }
  
  /**
   隐藏所有功能管理视图
   */
  private func hideAllFunctionViews(_ rootView: KeyboardRootView) {
    rootView.clipboardManagerView.isHidden = true
    rootView.commonWordsManagerView.isHidden = true
    rootView.knowledgeBaseManagerView.isHidden = true
  }
}

// MARK: - KeyboardRootView Extension

extension KeyboardRootView {
  /// 提供对功能管理视图的访问接口
  var clipboardManagerView: UIView {
    return subviews.first { $0 is ClipboardManagerView } ?? UIView()
  }
  
  var commonWordsManagerView: UIView {
    return subviews.first { $0 is CommonWordsManagerView } ?? UIView()
  }
  
  var knowledgeBaseManagerView: UIView {
    return subviews.first { $0 is KnowledgeBaseManagerView } ?? UIView()
  }
}