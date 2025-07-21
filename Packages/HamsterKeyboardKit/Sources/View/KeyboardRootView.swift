//
//  KeyboardRootView.swift
//
//
//  Created by morse on 2023/8/14.
//

import Combine
import HamsterKit
import HamsterUIKit
import OSLog
import UIKit

/**
 键盘根视图
 */
class KeyboardRootView: NibLessView {
  public typealias KeyboardWidth = CGFloat
  public typealias KeyboardItemWidth = CGFloat

  // MARK: - Properties

  private let keyboardLayoutProvider: KeyboardLayoutProvider
  private let actionHandler: KeyboardActionHandler
  private let appearance: KeyboardAppearance
  private let layoutConfig: KeyboardLayoutConfiguration
  private var actionCalloutContext: ActionCalloutContext
  private var calloutContext: KeyboardCalloutContext
  private var inputCalloutContext: InputCalloutContext
  private var keyboardContext: KeyboardContext
  private var rimeContext: RimeContext

  private var subscriptions = Set<AnyCancellable>()

  /// 当前键盘类型
  private var currentKeyboardType: KeyboardType

  /// 当前屏幕方向
  private var interfaceOrientation: InterfaceOrientation

  /// 当前界面样式
  private var userInterfaceStyle: UIUserInterfaceStyle

  /// 键盘是否浮动
  private var isKeyboardFloating: Bool

  /// 工具栏收起时约束
  private var toolbarCollapseDynamicConstraints = [NSLayoutConstraint]()

  /// 工具栏展开时约束
  private var toolbarExpandDynamicConstraints = [NSLayoutConstraint]()

  /// 工具栏高度约束
  private var toolbarHeightConstraint: NSLayoutConstraint?

  /// 候选文字视图状态
  private var candidateViewState: CandidateBarView.State

  /// AI查询视图高度约束
  private var aiQueryViewHeightConstraint: NSLayoutConstraint?
  
  /// AI查询视图是否显示
  private var isAIQueryViewVisible: Bool = false

  /// 非主键盘的临时键盘Cache
  // private var tempKeyboardViewCache: [KeyboardType: UIView] = [:]

  // MARK: - 计算属性

//  private var actionCalloutStyle: KeyboardActionCalloutStyle {
//    var style = appearance.actionCalloutStyle
//    let insets = layoutConfig.buttonInsets
//    style.callout.buttonInset = insets
//    return style
//  }

//  private var inputCalloutStyle: KeyboardInputCalloutStyle {
//    var style = appearance.inputCalloutStyle
//    let insets = layoutConfig.buttonInsets
//    style.callout.buttonInset = insets
//    return style
//  }

  // MARK: - subview

  /// 26键键盘，包含默认中文26键及英文26键
  /// 注意：计算属性， 在 primaryKeyboardView 闭包中按需创建
  private var standerSystemKeyboard: StanderSystemKeyboard {
    let view = StanderSystemKeyboard(
      keyboardLayoutProvider: keyboardLayoutProvider,
      appearance: appearance,
      actionHandler: actionHandler,
      keyboardContext: keyboardContext,
      rimeContext: rimeContext,
      calloutContext: calloutContext
    )
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }

  /// 中文九宫格键盘
  /// 注意：计算属性， 在 primaryKeyboardView 闭包中按需创建
  private var chineseNineGridKeyboardView: ChineseNineGridKeyboard {
    let view = ChineseNineGridKeyboard(
      keyboardLayoutProvider: keyboardLayoutProvider,
      actionHandler: actionHandler,
      appearance: appearance,
      keyboardContext: keyboardContext,
      calloutContext: calloutContext,
      rimeContext: rimeContext
    )
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }

  /// 数字九宫格键盘
  /// 注意：计算属性
  private var numericNineGridKeyboardView: UIView {
    let view = NumericNineGridKeyboard(
      actionHandler: actionHandler,
      appearance: appearance,
      keyboardContext: keyboardContext,
      calloutContext: calloutContext,
      rimeContext: rimeContext
    )
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }

  /// 符号分类键盘
  /// 注意：计算属性
  private var classifySymbolicKeyboardView: ClassifySymbolicKeyboard {
    let view = ClassifySymbolicKeyboard(
      actionHandler: actionHandler,
      appearance: appearance,
      layoutProvider: keyboardLayoutProvider,
      keyboardContext: keyboardContext
    )
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }

  /// emoji键盘
  /// 注意：计算属性
  private var emojisKeyboardView: UIView {
    // TODO:
    let view = UIView()
    view.backgroundColor = .red
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }

  /// AI查询视图
  lazy var aiQueryView: AIQueryView = {
    let view = AIQueryView(
      appearance: appearance,
      actionHandler: actionHandler,
      keyboardContext: keyboardContext
    )
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isHidden = true
    view.alpha = 0

    // 设置文本插入回调
    view.onInsertText = { [weak self] text in
      guard let self = self else { return }
      Logger.statistics.info("KeyboardRootView: AI查询结果插入文本，长度: \(text.count)")
      // 关闭AI查询模式
      self.toggleAIQueryView()
      // 通过actionHandler插入文本到当前输入位置
      self.actionHandler.handle(.release, on: .character(text))
    }

    Logger.statistics.debug("KeyboardRootView: AI查询视图初始化完成")
    return view
  }()

  /// 工具栏
  public lazy var toolbarView: UIView = {
    let view = KeyboardToolbarView(appearance: appearance, actionHandler: actionHandler, keyboardContext: keyboardContext, rimeContext: rimeContext)
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // 设置AI按钮点击回调
    if let toolbarView = view as? KeyboardToolbarView {
      toolbarView.onAIButtonTapped = { [weak self] in
        self?.toggleAIQueryView()
      }
    }
    
    return view
  }()

  /// 主键盘
  private lazy var primaryKeyboardView: UIView = {
    if let view = chooseKeyboard(keyboardType: keyboardContext.keyboardType) {
      return view
    }
    return standerSystemKeyboard
  }()

  // MARK: - Initializations

  /**
   Create a system keyboard with custom button views.

   The provided `buttonView` builder will be used to build
   the full button view for every layout item.

   - Parameters:
     - keyboardLayoutProvider: The keyboard layout provider to use.
     - appearance: The keyboard appearance to use.
     - actionHandler: The action handler to use.
     - autocompleteContext: The autocomplete context to use.
     - autocompleteToolbar: The autocomplete toolbar mode to use.
     - autocompleteToolbarAction: The action to trigger when tapping an autocomplete suggestion.
     - keyboardContext: The keyboard context to use.
     - calloutContext: The callout context to use.
     - width: The keyboard width.
   */
  public init(
    keyboardLayoutProvider: KeyboardLayoutProvider,
    appearance: KeyboardAppearance,
    actionHandler: KeyboardActionHandler,
    keyboardContext: KeyboardContext,
    calloutContext: KeyboardCalloutContext?,
    rimeContext: RimeContext
  ) {
    self.keyboardLayoutProvider = keyboardLayoutProvider
    self.layoutConfig = .standard(for: keyboardContext)
    self.actionHandler = actionHandler
    self.appearance = appearance
    self.keyboardContext = keyboardContext
    self.calloutContext = calloutContext ?? .disabled
    self.actionCalloutContext = calloutContext?.action ?? .disabled
    self.inputCalloutContext = calloutContext?.input ?? .disabled
    self.rimeContext = rimeContext
    self.candidateViewState = keyboardContext.candidatesViewState
    self.currentKeyboardType = keyboardContext.keyboardType
    self.interfaceOrientation = keyboardContext.interfaceOrientation
    self.isKeyboardFloating = keyboardContext.isKeyboardFloating
    self.userInterfaceStyle = keyboardContext.colorScheme

    super.init(frame: .zero)

    // Test
//    let view = UIView()
//    view.frame = CGRect(origin: .zero, size: CGSize(width: 100, height: 100))
//    view.backgroundColor = .yellow
//    addSubview(view)

    constructViewHierarchy()
    activateViewConstraints()
    setupAppearance()

    combine()
  }

  deinit {
    subviews.forEach { $0.removeFromSuperview() }
  }

  override func setupAppearance() {
    backgroundColor = appearance.backgroundStyle.backgroundColor
    contentMode = .redraw
  }

  // MARK: - Layout

  /// 构建视图层次
  override func constructViewHierarchy() {
    // 首先添加AI查询视图到最顶层
    addSubview(aiQueryView)
    
    if keyboardContext.enableToolbar {
      addSubview(toolbarView)
      addSubview(primaryKeyboardView)
    } else {
      addSubview(primaryKeyboardView)
    }
  }

  /// 激活约束
  override func activateViewConstraints() {
    // AI查询视图约束 - 在最顶部，初始高度为0
    aiQueryViewHeightConstraint = aiQueryView.heightAnchor.constraint(equalToConstant: 0)
    var aiQueryConstraints = [
      aiQueryView.topAnchor.constraint(equalTo: topAnchor),
      aiQueryView.leadingAnchor.constraint(equalTo: leadingAnchor),
      aiQueryView.trailingAnchor.constraint(equalTo: trailingAnchor),
      aiQueryViewHeightConstraint!
    ]
    
    if keyboardContext.enableToolbar {
      // 工具栏高度约束，可随配置调整高度
      toolbarHeightConstraint = toolbarView.heightAnchor.constraint(equalToConstant: keyboardContext.heightOfToolbar)

      // 工具栏静态约束 - 在AI查询视图下方
      let toolbarStaticConstraint = [
        toolbarView.topAnchor.constraint(equalTo: aiQueryView.bottomAnchor),
        toolbarView.leadingAnchor.constraint(equalTo: leadingAnchor),
        toolbarView.trailingAnchor.constraint(equalTo: trailingAnchor)
      ]

      // 工具栏收缩时动态约束
      toolbarCollapseDynamicConstraints = createToolbarCollapseDynamicConstraints()

      // 工具栏展开时动态约束
      toolbarExpandDynamicConstraints = createToolbarExpandDynamicConstraints()

      NSLayoutConstraint.activate(aiQueryConstraints + toolbarStaticConstraint + toolbarCollapseDynamicConstraints + [toolbarHeightConstraint!])
    } else {
      let noToolbarConstraints = [
        primaryKeyboardView.topAnchor.constraint(equalTo: aiQueryView.bottomAnchor),
        primaryKeyboardView.bottomAnchor.constraint(equalTo: bottomAnchor),
        primaryKeyboardView.leadingAnchor.constraint(equalTo: leadingAnchor),
        primaryKeyboardView.trailingAnchor.constraint(equalTo: trailingAnchor)
      ]
      NSLayoutConstraint.activate(aiQueryConstraints + noToolbarConstraints)
    }
  }

  /// 工具栏展开时动态约束
  func createToolbarExpandDynamicConstraints() -> [NSLayoutConstraint] {
    return [
      toolbarView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ]
  }

  /// 工具栏收缩时动态约束
  func createToolbarCollapseDynamicConstraints() -> [NSLayoutConstraint] {
    return [
      primaryKeyboardView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
      primaryKeyboardView.bottomAnchor.constraint(equalTo: bottomAnchor),
      primaryKeyboardView.leadingAnchor.constraint(equalTo: leadingAnchor),
      primaryKeyboardView.trailingAnchor.constraint(equalTo: trailingAnchor)
    ]
  }

  // MARK: - AI功能相关方法

  /// 切换AI查询视图的显示状态
  private func toggleAIQueryView() {
    Logger.statistics.info("KeyboardRootView: 切换AI查询视图显示状态，当前状态: \(self.isAIQueryViewVisible)")

    isAIQueryViewVisible.toggle()

    // 设置合适的高度 - 增加到350pt以确保所有UI元素都能正确显示
    let targetHeight: CGFloat = isAIQueryViewVisible ? 350 : 0
    let targetAlpha: CGFloat = isAIQueryViewVisible ? 1.0 : 0.0

    // 更新AIAwareKeyboardActionHandler的AI查询模式状态
    if let aiHandler = actionHandler as? AIAwareKeyboardActionHandler {
      aiHandler.setAIQueryMode(active: isAIQueryViewVisible)
    }

    // 更新约束和透明度
    aiQueryViewHeightConstraint?.constant = targetHeight

    UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
      self.aiQueryView.alpha = targetAlpha
      self.layoutIfNeeded()
    }) { completed in
      if completed {
        self.aiQueryView.isHidden = !self.isAIQueryViewVisible
        Logger.statistics.debug("KeyboardRootView: AI查询视图动画完成，显示状态: \(self.isAIQueryViewVisible)")
        
        // 显示时激活AI查询模式
        if self.isAIQueryViewVisible {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.aiQueryView.focusTextField()
            Logger.statistics.debug("KeyboardRootView: 调用AI查询视图文本框聚焦方法")
          }
        }
      }
    }

    // 通知工具栏更新AI按钮状态
    if let toolbarView = toolbarView as? KeyboardToolbarView {
      toolbarView.updateAIButtonState(isActive: isAIQueryViewVisible)
    }
  }

  /// 处理键盘输入（供外部调用）
  func handleKeyInput(_ character: String) -> Bool {
    Logger.statistics.debug("KeyboardRootView: 处理键盘输入: '\(character)', AI查询模式: \(self.isAIQueryViewVisible)")
    
    if isAIQueryViewVisible {
      return aiQueryView.handleKeyInput(character)
    }
    
    return false // 表示输入应由正常输入法处理
  }

  func combine() {
    // 在开启工具栏的状态下，根据候选状态调节候选栏区域大小
    if keyboardContext.enableToolbar {
      keyboardContext.$candidatesViewState
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
          guard let self = self else { return }
          guard self.candidateViewState != $0 else { return }
          self.setNeedsLayout()
        }
        .store(in: &subscriptions)
    }

    // 跟踪 UIUserInterfaceStyle 变化
    keyboardContext.$traitCollection
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        guard let self = self else { return }
        guard self.userInterfaceStyle != $0.userInterfaceStyle else { return }
        self.userInterfaceStyle = $0.userInterfaceStyle
        self.setupAppearance()
        if self.keyboardContext.enableToolbar {
          self.toolbarView.setNeedsLayout()
        }
        self.primaryKeyboardView.setNeedsLayout()
      }
      .store(in: &subscriptions)

    // 屏幕方向改变调整按键高度及按键内距
    keyboardContext.$interfaceOrientation
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        guard let self = self else { return }
        guard $0 != self.interfaceOrientation else { return }
        self.interfaceOrientation = $0
        self.primaryKeyboardView.setNeedsLayout()
      }
      .store(in: &subscriptions)

    // iPad 浮动模式开启
    keyboardContext.$isKeyboardFloating
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        guard let self = self else { return }
        guard self.isKeyboardFloating != $0 else { return }
        self.isKeyboardFloating = $0
        self.primaryKeyboardView.setNeedsLayout()
      }
      .store(in: &subscriptions)

    // 跟踪键盘类型变化
    keyboardContext.keyboardTypePublished
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in
        guard let self = self else { return }
        guard $0 != self.currentKeyboardType else { return }
        self.currentKeyboardType = $0

        Logger.statistics.debug("KeyboardRootView keyboardType combine: \($0.yamlString)")

        guard let keyboardView = self.chooseKeyboard(keyboardType: $0) else {
          Logger.statistics.error("\($0.yamlString) cannot find keyboardView.")
          return
        }

        if self.keyboardContext.enableToolbar {
          // NSLayoutConstraint.deactivate(toolbarCollapseDynamicConstraints)
          self.toolbarCollapseDynamicConstraints.removeAll(keepingCapacity: true)
          self.toolbarExpandDynamicConstraints.removeAll(keepingCapacity: true)

          self.primaryKeyboardView.subviews.forEach { $0.removeFromSuperview() }
          self.primaryKeyboardView.removeFromSuperview()

          self.primaryKeyboardView = keyboardView
          self.addSubview(self.primaryKeyboardView)

          // 工具栏收缩时约束
          self.toolbarCollapseDynamicConstraints = self.createToolbarCollapseDynamicConstraints()

          // 工具栏展开时约束
          self.toolbarExpandDynamicConstraints = self.createToolbarExpandDynamicConstraints()

          NSLayoutConstraint.activate(self.toolbarCollapseDynamicConstraints)
        } else {
          NSLayoutConstraint.deactivate(self.constraints)
          self.primaryKeyboardView.removeFromSuperview()
          self.primaryKeyboardView = keyboardView
          self.addSubview(self.primaryKeyboardView)
          let noToolbarConstraints = [
            self.primaryKeyboardView.topAnchor.constraint(equalTo: self.aiQueryView.bottomAnchor),
            self.primaryKeyboardView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.primaryKeyboardView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.primaryKeyboardView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
          ]
          NSLayoutConstraint.activate(noToolbarConstraints)
        }
      }
      .store(in: &subscriptions)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Logger.statistics.debug("KeyboardRootView: layoutSubviews()")

    // 检测候选栏状态是否发生变化
    guard candidateViewState != keyboardContext.candidatesViewState else { return }
    candidateViewState = keyboardContext.candidatesViewState

    // 候选栏收起
    if candidateViewState.isCollapse() {
      // 键盘显示
      toolbarHeightConstraint?.constant = keyboardContext.heightOfToolbar
      addSubview(primaryKeyboardView)
      NSLayoutConstraint.deactivate(toolbarExpandDynamicConstraints)
      NSLayoutConstraint.activate(toolbarCollapseDynamicConstraints)
    } else {
      // 键盘隐藏
      let toolbarHeight = primaryKeyboardView.bounds.height + keyboardContext.heightOfToolbar
      primaryKeyboardView.removeFromSuperview()

      toolbarHeightConstraint?.constant = toolbarHeight
      NSLayoutConstraint.deactivate(toolbarCollapseDynamicConstraints)
      NSLayoutConstraint.activate(toolbarExpandDynamicConstraints)
    }
  }

  /// 根据键盘类型选择键盘
  func chooseKeyboard(keyboardType: KeyboardType) -> UIView? {
//    // 从 cache 中获取键盘
//    if let tempKeyboardView = tempKeyboardViewCache[keyboardType] {
//      return tempKeyboardView
//    }

    // 生成临时键盘
    var tempKeyboardView: UIView? = nil
    switch keyboardType {
    case .numericNineGrid:
      tempKeyboardView = numericNineGridKeyboardView
    case .classifySymbolic:
      tempKeyboardView = classifySymbolicKeyboardView
    case .emojis:
      tempKeyboardView = emojisKeyboardView
    case .alphabetic, .numeric, .symbolic, .chinese, .chineseNumeric, .chineseSymbolic, .custom:
      tempKeyboardView = standerSystemKeyboard
    case .chineseNineGrid:
      tempKeyboardView = chineseNineGridKeyboardView
    default:
      // 注意：非临时键盘类型外的类型直接 return
      Logger.statistics.error("keyboardType: \(keyboardType.yamlString) not match tempKeyboardType")
      return nil
    }

    // 保存 cache
//    tempKeyboardViewCache[keyboardType] = tempKeyboardView
    return tempKeyboardView
  }
  
  // MARK: - Public Methods
  
  /// 获取AI查询视图是否正在显示
  /// - Returns: 如果AI查询视图正在显示则返回true，否则返回false
  public func isAIQueryViewDisplaying() -> Bool {
    return isAIQueryViewVisible || (!aiQueryView.isHidden && aiQueryView.alpha > 0)
  }
}