//
//  KeyboardToolbarView.swift
//
//
//  Created by morse on 2023/8/19.
//

import Combine
import HamsterKit
import HamsterUIKit
import OSLog
import UIKit

/**
 键盘工具栏

 用于显示：
 1. 候选文字，包含横向部分文字显示及下拉显示全部文字
 2. 常用功能视图
 3. AI查询功能视图 (新增)
 */
class KeyboardToolbarView: NibLessView {
  private let appearance: KeyboardAppearance
  private let actionHandler: KeyboardActionHandler
  private let keyboardContext: KeyboardContext
  private var rimeContext: RimeContext
  private var style: CandidateBarStyle
  private var userInterfaceStyle: UIUserInterfaceStyle
  private var oldBounds: CGRect = .zero
  private var subscriptions = Set<AnyCancellable>()

  /// AI按钮点击回调
  var onAIButtonTapped: (() -> Void)?
  
  /// AI按钮状态
  private var isAIButtonActive: Bool = false

  /// AI按钮
  lazy var aiButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "brain"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 18), scale: .default), forImageIn: .normal)
    button.tintColor = style.toolbarButtonFrontColor
    button.backgroundColor = style.toolbarButtonBackgroundColor
    button.layer.cornerRadius = 6
    button.addTarget(self, action: #selector(aiButtonTouchDownAction), for: .touchDown)
    button.addTarget(self, action: #selector(aiButtonTouchUpAction), for: .touchUpInside)
    button.addTarget(self, action: #selector(touchCancel), for: .touchCancel)
    button.addTarget(self, action: #selector(touchCancel), for: .touchUpOutside)

    Logger.statistics.debug("KeyboardToolbarView: AI按钮初始化完成")
    return button
  }()

  /// 常用功能项: 仓输入法App
  lazy var iconButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "r.circle"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 18), scale: .default), forImageIn: .normal)
    button.tintColor = style.toolbarButtonFrontColor
    button.backgroundColor = style.toolbarButtonBackgroundColor
    button.addTarget(self, action: #selector(openHamsterAppTouchDownAction), for: .touchDown)
    button.addTarget(self, action: #selector(openHamsterAppTouchUpAction), for: .touchUpInside)
    button.addTarget(self, action: #selector(touchCancel), for: .touchCancel)
    button.addTarget(self, action: #selector(touchCancel), for: .touchUpOutside)

    return button
  }()

  /// 解散键盘 Button
  lazy var dismissKeyboardButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "chevron.down.circle"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 18), scale: .default), forImageIn: .normal)
    button.tintColor = style.toolbarButtonFrontColor
    button.backgroundColor = style.toolbarButtonBackgroundColor
    button.addTarget(self, action: #selector(dismissKeyboardTouchDownAction), for: .touchDown)
    button.addTarget(self, action: #selector(dismissKeyboardTouchUpAction), for: .touchUpInside)
    button.addTarget(self, action: #selector(touchCancel), for: .touchCancel)
    button.addTarget(self, action: #selector(touchCancel), for: .touchUpOutside)
    return button
  }()

  // TODO: 常用功能栏
  lazy var commonFunctionBar: UIView = {
    let view = UIView(frame: .zero)
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  /// 候选文字视图
  lazy var candidateBarView: CandidateBarView = {
    let view = CandidateBarView(
      style: style,
      actionHandler: actionHandler,
      keyboardContext: keyboardContext,
      rimeContext: rimeContext
    )
    return view
  }()

  init(appearance: KeyboardAppearance, actionHandler: KeyboardActionHandler, keyboardContext: KeyboardContext, rimeContext: RimeContext) {
    self.appearance = appearance
    self.actionHandler = actionHandler
    self.keyboardContext = keyboardContext
    self.rimeContext = rimeContext
    // KeyboardToolbarView 为 candidateBarStyle 样式根节点, 这里生成一次，减少计算次数
    self.style = appearance.candidateBarStyle
    self.userInterfaceStyle = keyboardContext.colorScheme

    super.init(frame: .zero)

    Logger.statistics.info("KeyboardToolbarView: 初始化工具栏视图")
    setupSubview()

    combine()
  }

  func setupSubview() {
    constructViewHierarchy()
    activateViewConstraints()
    setupAppearance()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    if userInterfaceStyle != keyboardContext.colorScheme {
      userInterfaceStyle = keyboardContext.colorScheme
      setupAppearance()
      candidateBarView.setStyle(self.style)
    }
  }

  override func constructViewHierarchy() {
    Logger.statistics.debug("KeyboardToolbarView: 构建视图层次结构")

    // 添加常用功能栏
    addSubview(commonFunctionBar)

    // 添加AI按钮（最左侧）
    commonFunctionBar.addSubview(aiButton)

    if keyboardContext.displayAppIconButton {
      commonFunctionBar.addSubview(iconButton)
    }
    if keyboardContext.displayKeyboardDismissButton {
      commonFunctionBar.addSubview(dismissKeyboardButton)
    }
  }

  override func activateViewConstraints() {
    Logger.statistics.debug("KeyboardToolbarView: 激活视图约束")

    var constraints: [NSLayoutConstraint] = []
    
    // 常用功能栏约束 - 填充整个工具栏
    constraints.append(contentsOf: [
      commonFunctionBar.topAnchor.constraint(equalTo: topAnchor),
      commonFunctionBar.bottomAnchor.constraint(equalTo: bottomAnchor),
      commonFunctionBar.leadingAnchor.constraint(equalTo: leadingAnchor),
      commonFunctionBar.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])

    // AI按钮约束（最左侧）
    constraints.append(contentsOf: [
      aiButton.leadingAnchor.constraint(equalTo: commonFunctionBar.leadingAnchor, constant: 8),
      aiButton.heightAnchor.constraint(equalTo: aiButton.widthAnchor),
      aiButton.topAnchor.constraint(lessThanOrEqualTo: commonFunctionBar.topAnchor),
      commonFunctionBar.bottomAnchor.constraint(greaterThanOrEqualTo: aiButton.bottomAnchor),
      aiButton.centerYAnchor.constraint(equalTo: commonFunctionBar.centerYAnchor),
    ])

    // 计算其他按钮的起始位置（AI按钮之后）
    var previousButton = aiButton

    if keyboardContext.displayAppIconButton {
      constraints.append(contentsOf: [
        iconButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 8),
        iconButton.heightAnchor.constraint(equalTo: iconButton.widthAnchor),
        iconButton.topAnchor.constraint(lessThanOrEqualTo: commonFunctionBar.topAnchor),
        commonFunctionBar.bottomAnchor.constraint(greaterThanOrEqualTo: iconButton.bottomAnchor),
        iconButton.centerYAnchor.constraint(equalTo: commonFunctionBar.centerYAnchor),
      ])
      previousButton = iconButton
    }

    if keyboardContext.displayKeyboardDismissButton {
      constraints.append(contentsOf: [
        dismissKeyboardButton.heightAnchor.constraint(equalTo: dismissKeyboardButton.widthAnchor),
        dismissKeyboardButton.trailingAnchor.constraint(equalTo: commonFunctionBar.trailingAnchor, constant: -8),
        dismissKeyboardButton.topAnchor.constraint(lessThanOrEqualTo: commonFunctionBar.topAnchor),
        commonFunctionBar.bottomAnchor.constraint(greaterThanOrEqualTo: dismissKeyboardButton.bottomAnchor),
        dismissKeyboardButton.centerYAnchor.constraint(equalTo: commonFunctionBar.centerYAnchor),
      ])
    }

    NSLayoutConstraint.activate(constraints)
  }

  override func setupAppearance() {
    Logger.statistics.debug("KeyboardToolbarView: 设置外观样式")

    self.style = appearance.candidateBarStyle

    // 更新AI按钮样式
    updateAIButtonAppearance()

    if keyboardContext.displayAppIconButton {
      iconButton.tintColor = style.toolbarButtonFrontColor
    }
    if keyboardContext.displayKeyboardDismissButton {
      dismissKeyboardButton.tintColor = style.toolbarButtonFrontColor
    }
  }

  func combine() {
    rimeContext.userInputKeyPublished
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        guard let self = self else { return }
        let isEmpty = $0.isEmpty
        self.commonFunctionBar.isHidden = !isEmpty
        self.candidateBarView.isHidden = isEmpty

        if self.candidateBarView.superview == nil {
          self.candidateBarView.setStyle(self.style)
          // 将candidateBarView添加到工具栏中
          self.addSubview(self.candidateBarView)
          
          // 设置candidateBarView约束，使其填充工具栏
          self.candidateBarView.translatesAutoresizingMaskIntoConstraints = false
          NSLayoutConstraint.activate([
            self.candidateBarView.topAnchor.constraint(equalTo: self.topAnchor),
            self.candidateBarView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.candidateBarView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.candidateBarView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
          ])
        }

        // 检测是否启用内嵌编码
        guard !self.keyboardContext.enableEmbeddedInputMode else { return }
        if self.keyboardContext.keyboardType.isChineseNineGrid {
          // Debug
          // self.phoneticArea.text = inputKeys + " | " + self.rimeContext.t9UserInputKey
          self.candidateBarView.phoneticLabel.text = self.rimeContext.t9UserInputKey
        } else {
          self.candidateBarView.phoneticLabel.text = $0
        }
      }
      .store(in: &subscriptions)
  }

  // MARK: - 公开方法
  
  /// 处理键盘输入（供外部调用，兼容性方法）
  func handleKeyInput(_ character: String) -> Bool {
    Logger.statistics.debug("KeyboardToolbarView: 处理键盘输入: '\(character)' (兼容性方法，AI功能已移至KeyboardRootView)")
    // 由于AI功能已移至KeyboardRootView，这里只是保持兼容性
    return false
  }
  
  /// 更新AI按钮状态
  func updateAIButtonState(isActive: Bool) {
    self.isAIButtonActive = isActive
    updateAIButtonAppearance()
  }

  /// 更新AI按钮外观
  private func updateAIButtonAppearance() {
    let backgroundColor = isAIButtonActive ?
      style.toolbarButtonPressedBackgroundColor :
      style.toolbarButtonBackgroundColor

    aiButton.tintColor = style.toolbarButtonFrontColor
    aiButton.backgroundColor = backgroundColor
  }

  // MARK: - 按钮事件处理方法

  @objc func aiButtonTouchDownAction() {
    Logger.statistics.debug("KeyboardToolbarView: AI按钮按下")
    aiButton.backgroundColor = style.toolbarButtonPressedBackgroundColor
  }

  @objc func aiButtonTouchUpAction() {
    Logger.statistics.info("KeyboardToolbarView: AI按钮点击")
    onAIButtonTapped?()
  }

  @objc func dismissKeyboardTouchDownAction() {
    dismissKeyboardButton.backgroundColor = style.toolbarButtonPressedBackgroundColor
  }

  @objc func dismissKeyboardTouchUpAction() {
    dismissKeyboardButton.backgroundColor = style.toolbarButtonBackgroundColor
    actionHandler.handle(.release, on: .dismissKeyboard)
  }

  @objc func openHamsterAppTouchDownAction() {
    iconButton.backgroundColor = style.toolbarButtonPressedBackgroundColor
  }

  @objc func openHamsterAppTouchUpAction() {
    iconButton.backgroundColor = style.toolbarButtonPressedBackgroundColor
    actionHandler.handle(.release, on: .url(URL(string: "hamster://dev.fuxiao.app.hamster/main"), id: "openHamster"))
  }

  @objc func touchCancel() {
    dismissKeyboardButton.backgroundColor = style.toolbarButtonBackgroundColor
    iconButton.backgroundColor = style.toolbarButtonBackgroundColor
    updateAIButtonAppearance() // 恢复AI按钮状态
  }
}