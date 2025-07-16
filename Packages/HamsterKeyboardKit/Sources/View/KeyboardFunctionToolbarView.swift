//
//  KeyboardFunctionToolbarView.swift
//
//
//  Created by AI on 2024/1/1.
//

import Combine
import HamsterKit
import HamsterUIKit
import UIKit

/**
 键盘功能工具栏

 用于显示常用功能按钮：
 1. 剪贴板
 2. 常用词汇
 3. 知识库
 4. 其他扩展功能
 */
class KeyboardFunctionToolbarView: NibLessView {
  private let appearance: KeyboardAppearance
  private let actionHandler: KeyboardActionHandler
  private let keyboardContext: KeyboardContext
  private var rimeContext: RimeContext
  private var style: CandidateBarStyle
  private var userInterfaceStyle: UIUserInterfaceStyle
  private var subscriptions = Set<AnyCancellable>()

  /// 剪贴板按钮
  lazy var clipboardButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "doc.on.clipboard"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 16), scale: .default), forImageIn: .normal)
    button.tintColor = style.toolbarButtonFrontColor
    button.backgroundColor = style.toolbarButtonBackgroundColor
    button.layer.cornerRadius = 4
    button.addTarget(self, action: #selector(clipboardButtonTouchDown), for: .touchDown)
    button.addTarget(self, action: #selector(clipboardButtonTouchUp), for: .touchUpInside)
    button.addTarget(self, action: #selector(buttonTouchCancel), for: .touchCancel)
    button.addTarget(self, action: #selector(buttonTouchCancel), for: .touchUpOutside)
    return button
  }()

  /// 常用词汇按钮
  lazy var commonWordsButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "text.book.closed"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 16), scale: .default), forImageIn: .normal)
    button.tintColor = style.toolbarButtonFrontColor
    button.backgroundColor = style.toolbarButtonBackgroundColor
    button.layer.cornerRadius = 4
    button.addTarget(self, action: #selector(commonWordsButtonTouchDown), for: .touchDown)
    button.addTarget(self, action: #selector(commonWordsButtonTouchUp), for: .touchUpInside)
    button.addTarget(self, action: #selector(buttonTouchCancel), for: .touchCancel)
    button.addTarget(self, action: #selector(buttonTouchCancel), for: .touchUpOutside)
    return button
  }()

  /// 知识库按钮
  lazy var knowledgeBaseButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "brain.head.profile"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 16), scale: .default), forImageIn: .normal)
    button.tintColor = style.toolbarButtonFrontColor
    button.backgroundColor = style.toolbarButtonBackgroundColor
    button.layer.cornerRadius = 4
    button.addTarget(self, action: #selector(knowledgeBaseButtonTouchDown), for: .touchDown)
    button.addTarget(self, action: #selector(knowledgeBaseButtonTouchUp), for: .touchUpInside)
    button.addTarget(self, action: #selector(buttonTouchCancel), for: .touchCancel)
    button.addTarget(self, action: #selector(buttonTouchCancel), for: .touchUpOutside)
    return button
  }()

  /// 设置按钮
  lazy var settingsButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "gearshape"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 16), scale: .default), forImageIn: .normal)
    button.tintColor = style.toolbarButtonFrontColor
    button.backgroundColor = style.toolbarButtonBackgroundColor
    button.layer.cornerRadius = 4
    button.addTarget(self, action: #selector(settingsButtonTouchDown), for: .touchDown)
    button.addTarget(self, action: #selector(settingsButtonTouchUp), for: .touchUpInside)
    button.addTarget(self, action: #selector(buttonTouchCancel), for: .touchCancel)
    button.addTarget(self, action: #selector(buttonTouchCancel), for: .touchUpOutside)
    return button
  }()

  /// 主容器
  lazy var containerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = style.backgroundColor
    return view
  }()

  /// 按钮堆栈视图
  lazy var buttonStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .horizontal
    stackView.distribution = .equalSpacing
    stackView.alignment = .center
    stackView.spacing = 12
    return stackView
  }()

  init(appearance: KeyboardAppearance, actionHandler: KeyboardActionHandler, keyboardContext: KeyboardContext, rimeContext: RimeContext) {
    self.appearance = appearance
    self.actionHandler = actionHandler
    self.keyboardContext = keyboardContext
    self.rimeContext = rimeContext
    self.style = appearance.candidateBarStyle
    self.userInterfaceStyle = keyboardContext.colorScheme

    super.init(frame: .zero)

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
    }
  }

  override func constructViewHierarchy() {
    addSubview(containerView)
    containerView.addSubview(buttonStackView)
    
    buttonStackView.addArrangedSubview(clipboardButton)
    buttonStackView.addArrangedSubview(commonWordsButton)
    buttonStackView.addArrangedSubview(knowledgeBaseButton)
    buttonStackView.addArrangedSubview(settingsButton)
  }

  override func activateViewConstraints() {
    let buttonSize: CGFloat = 36
    
    NSLayoutConstraint.activate([
      // 容器约束
      containerView.topAnchor.constraint(equalTo: topAnchor),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
      containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
      
      // 堆栈视图约束
      buttonStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      buttonStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
      buttonStackView.topAnchor.constraint(greaterThanOrEqualTo: containerView.topAnchor, constant: 8),
      containerView.bottomAnchor.constraint(greaterThanOrEqualTo: buttonStackView.bottomAnchor, constant: 8),
      
      // 按钮尺寸约束
      clipboardButton.widthAnchor.constraint(equalToConstant: buttonSize),
      clipboardButton.heightAnchor.constraint(equalToConstant: buttonSize),
      
      commonWordsButton.widthAnchor.constraint(equalToConstant: buttonSize),
      commonWordsButton.heightAnchor.constraint(equalToConstant: buttonSize),
      
      knowledgeBaseButton.widthAnchor.constraint(equalToConstant: buttonSize),
      knowledgeBaseButton.heightAnchor.constraint(equalToConstant: buttonSize),
      
      settingsButton.widthAnchor.constraint(equalToConstant: buttonSize),
      settingsButton.heightAnchor.constraint(equalToConstant: buttonSize),
    ])
  }

  override func setupAppearance() {
    self.style = appearance.candidateBarStyle
    containerView.backgroundColor = style.backgroundColor
    
    [clipboardButton, commonWordsButton, knowledgeBaseButton, settingsButton].forEach { button in
      button.tintColor = style.toolbarButtonFrontColor
      button.backgroundColor = style.toolbarButtonBackgroundColor
    }
  }

  func combine() {
    // 可以根据需要添加响应式更新逻辑
  }

  // MARK: - Button Actions

  @objc private func clipboardButtonTouchDown() {
    clipboardButton.backgroundColor = style.toolbarButtonPressedBackgroundColor
  }

  @objc private func clipboardButtonTouchUp() {
    clipboardButton.backgroundColor = style.toolbarButtonBackgroundColor
    // 处理剪贴板功能
    actionHandler.handle(.release, on: .custom(named: "showClipboard"))
  }

  @objc private func commonWordsButtonTouchDown() {
    commonWordsButton.backgroundColor = style.toolbarButtonPressedBackgroundColor
  }

  @objc private func commonWordsButtonTouchUp() {
    commonWordsButton.backgroundColor = style.toolbarButtonBackgroundColor
    // 处理常用词汇功能
    actionHandler.handle(.release, on: .custom(named: "showCommonWords"))
  }

  @objc private func knowledgeBaseButtonTouchDown() {
    knowledgeBaseButton.backgroundColor = style.toolbarButtonPressedBackgroundColor
  }

  @objc private func knowledgeBaseButtonTouchUp() {
    knowledgeBaseButton.backgroundColor = style.toolbarButtonBackgroundColor
    // 处理知识库功能
    actionHandler.handle(.release, on: .custom(named: "showKnowledgeBase"))
  }

  @objc private func settingsButtonTouchDown() {
    settingsButton.backgroundColor = style.toolbarButtonPressedBackgroundColor
  }

  @objc private func settingsButtonTouchUp() {
    settingsButton.backgroundColor = style.toolbarButtonBackgroundColor
    // 处理设置功能
    actionHandler.handle(.release, on: .custom(named: "showSettings"))
  }

  @objc private func buttonTouchCancel() {
    [clipboardButton, commonWordsButton, knowledgeBaseButton, settingsButton].forEach { button in
      button.backgroundColor = style.toolbarButtonBackgroundColor
    }
  }
}