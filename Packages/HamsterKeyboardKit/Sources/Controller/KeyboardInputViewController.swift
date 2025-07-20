//
//  KeyboardViewController.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2018-03-13.
//  Copyright © 2018-2023 Daniel Saidi. All rights reserved.
//

import Combine
import HamsterKit
import OSLog
import UIKit

/**
 This class extends `UIInputViewController` with KeyboardKit
 specific functionality.

 该类扩展了 `UIInputViewController` 的 KeyboardKit 特定功能。

 When you use KeyboardKit, simply inherit this class instead
 of `UIInputViewController` to extend your controller with a
 set of additional lifecycle functions, properties, services
 etc. such as ``viewWillSetupKeyboard()``, ``keyboardContext``
 and ``keyboardActionHandler``.

 当您使用 KeyboardKit 时，只需继承该类而非 `UIInputViewController` 类，
 即可使用一组附加的生命周期函数、属性、服务等来扩展您的控制器，
 例如 `viewWillSetupKeyboard()``、`keyboardContext`` 和 `keyboardActionHandler``。

 You may notice that KeyboardKit's own views use initializer
 parameters instead of environment objects. It's intentional,
 to better communicate the dependencies of each view.

 您可能会注意到，KeyboardKit 自己的视图使用初始化器参数而非环境对象。这是有意为之，以便更好地传达每个视图的依赖关系。
 */
open class KeyboardInputViewController: UIInputViewController, KeyboardController {
  // MARK: - View Controller Lifecycle ViewController 生命周期

  override open func viewDidLoad() {
    super.viewDidLoad()
    // setupInitialWidth()
    // setupLocaleObservation()
    // setupNextKeyboardBehavior()
    // KeyboardUrlOpener.shared.controller = self
    setupCombineRIMEInput()
  }

  override open func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setupRIME()
    viewWillSetupKeyboard()
    viewWillSyncWithContext()

    // fix: 屏幕边缘按键触摸延迟
    // https://stackoverflow.com/questions/39813245/touchesbeganwithevent-is-delayed-at-left-edge-of-screen
    // 注意：添加代码日志中会有警告
    // [Warning] Trying to set delaysTouchesBegan to NO on a system gate gesture recognizer - this is unsupported and will have undesired side effects
    // 如果后续有更好的解决方案，可以替换此方案
    view.window?.gestureRecognizers?.forEach {
      $0.delaysTouchesBegan = false
    }
  }

  override open func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
//    viewWillHandleDictationResult()
  }

  override open func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    // Logger.statistics.debug("KeyboardInputViewController: viewDidLayoutSubviews()")
    keyboardContext.syncAfterLayout(with: self)
  }

  override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    // Logger.statistics.info("controller traitCollectionDidChange()")
    super.traitCollectionDidChange(previousTraitCollection)
    viewWillSyncWithContext()
  }

  /// 内存回收
//  override open func didReceiveMemoryWarning() {
//    shutdownRIME()
//    setupRIME()
//  }

  // MARK: - Keyboard View Controller Lifecycle

  /**
   This function is called whenever the keyboard view must
   be created or updated.

   每当必须创建或更新键盘视图时，都会调用该函数。

   This will by default set up a ``KeyboardRootView`` as the
   main view, but you can override it to use a custom view.

   默认情况下，这将设置一个 "KeyboardRootView"（系统键盘）作为主视图，但你可以覆盖它以使用自定义视图。
   */

  open func viewWillSetupKeyboard() {
    let keyboardRootView = KeyboardRootView(
      keyboardLayoutProvider: keyboardLayoutProvider,
      appearance: keyboardAppearance,
      actionHandler: keyboardActionHandler,
      keyboardContext: keyboardContext,
      calloutContext: calloutContext,
      rimeContext: rimeContext
    )

    // 设置键盘的View
    keyboardRootView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(keyboardRootView)
    NSLayoutConstraint.activate([
      keyboardRootView.topAnchor.constraint(equalTo: view.topAnchor),
      keyboardRootView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      keyboardRootView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      keyboardRootView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    
    // 保存键盘根视图的引用以便后续访问AI查询功能
    self.keyboardRootView = keyboardRootView
  }

  deinit {
    view.subviews.forEach { $0.removeFromSuperview() }
  }

  /**
   This function is called whenever the controller must be
   synced with its ``keyboardContext``.

   每当 controller 必须与其 ``keyboardContext`` 同步时，就会调用此函数。

   This will by default sync with keyboard contexts if the
   ``isContextSyncEnabled`` is `true`. You can override it
   to customize syncing or sync with more contexts.

   如果 ``isContextSyncEnabled`` 为 `true`，默认情况下将与 KeyboardContext 同步。
   你可以覆盖它以自定义同步或与更多上下文同步。
   */
  open func viewWillSyncWithContext() {
    keyboardContext.sync(with: self)
    keyboardTextContext.sync(with: self)
  }

  // MARK: - Combine

  var cancellables = Set<AnyCancellable>()

  // MARK: - Properties

  /**
   The original text document proxy that was used to start
   the keyboard extension.

   用于启动键盘扩展程序的原生文本文档代理。

   This stays the same even if a ``textInputProxy`` is set,
   which makes ``textDocumentProxy`` return the custom one
   instead of the original one.

   即使设置了 ``textInputProxy`` 也不会改变，这将使 ``textDocumentProxy`` 返回自定义的文档，而不是原始文档。
   */
  open var mainTextDocumentProxy: UITextDocumentProxy {
    super.textDocumentProxy
  }

  /**
   键盘根视图引用，用于访问工具栏的AI查询功能
   */
  private var keyboardRootView: KeyboardRootView?

  /**
   The text document proxy to use, which can either be the
   original text input proxy or the ``textInputProxy``, if
   it is set to a custom value.

   要使用的 document proxy，可以是原生的文本输入代理，也可以是 ``textInputProxy``（如果设置为自定义值）。
   */
  override open var textDocumentProxy: UITextDocumentProxy {
//    textInputProxy ?? mainTextDocumentProxy
    mainTextDocumentProxy
  }

  /**
   A custom text input proxy to which text can be routed.

   自定义文本输入代理，可将文本传送到该代理。

   Setting the property makes ``textDocumentProxy`` return
   the custom proxy instead of the original one.

   设置该属性可使 ``textDocumentProxy`` 返回自定义代理，而不是原始代理。
   */
//  public var textInputProxy: TextInputProxy? {
//    didSet { viewWillSyncWithContext() }
//  }

  // MARK: - Observables

  /**
   The default, observable autocomplete context.

   默认的、可观察的自动完成上下文。

   This context is used as global state for the keyboard's
   autocomplete, e.g. the current suggestions.

   该上下文用作键盘自动完成的全局状态，例如当前建议。
   */
  public lazy var autocompleteContext = AutocompleteContext()

  /**
   The default, observable callout context.

   默认的可观察呼出上下文。

   This is used as global state for the callouts that show
   the currently typed character.

   这将作为显示当前键入字符的呼出的全局状态。
   */
  public lazy var calloutContext = KeyboardCalloutContext(
    action: ActionCalloutContext(
      actionHandler: keyboardActionHandler,
      actionProvider: calloutActionProvider
    ),
    input: InputCalloutContext(
      isEnabled: UIDevice.current.userInterfaceIdiom == .phone)
  )

  /**
   The default, observable dictation context.

   默认的, 可观测听写上下文。

   This is used as global dictation state and will be used
   to communicate between an app and its keyboard.

   这是全局听写状态，将用于应用程序与其键盘之间的通信。
   */
  // public lazy var dictationContext = DictationContext()

  /**
   The default, observable keyboard context.

   默认的, 可观察键盘上下文。

   This is used as global state for the keyboard's overall
   state and configuration like locale, device, screen etc.

   这是键盘整体状态和配置（如本地、设备、屏幕等）的全局状态。
   */
  public lazy var keyboardContext = KeyboardContext(controller: self)

  /**
   The default, observable feedback settings.

   默认的，可观察的反馈设置。

   This property is used as a global configuration for the
   keyboard's feedback, e.g. audio and haptic feedback.

   该属性用作键盘反馈（如音频和触觉反馈）的全局配置。
   */
  public lazy var keyboardFeedbackSettings: KeyboardFeedbackSettings = {
    let enableAudio = keyboardContext.hamsterConfiguration?.keyboard?.enableKeySounds ?? false
    let enableHaptic = keyboardContext.hamsterConfiguration?.keyboard?.enableHapticFeedback ?? false
    let hapticFeedbackIntensity = keyboardContext.hamsterConfiguration?.keyboard?.hapticFeedbackIntensity ?? 2
    let hapticFeedback = HapticIntensity(rawValue: hapticFeedbackIntensity)?.hapticFeedback() ?? .mediumImpact
    return KeyboardFeedbackSettings(
      audioConfiguration: enableAudio ? .enabled : .noFeedback,
      hapticConfiguration: enableHaptic ? .init(
        tap: hapticFeedback,
        doubleTap: hapticFeedback,
        longPress: hapticFeedback,
        longPressOnSpace: hapticFeedback,
        repeat: .selectionChanged
      ) : .noFeedback
    )
  }()

  /**
   The default, observable keyboard text context.

   默认的、可观察到的键盘文本上下文。

   This is used as global state to let you observe text in
   the ``textDocumentProxy``.

   这将作为全局状态，让您观察 ``textDocumentProxy`` 中的文本。
   */
  public lazy var keyboardTextContext = KeyboardTextContext()

  // MARK: - Services

  /**
   The autocomplete provider that is used to provide users
   with autocomplete suggestions.

   用于向用户提供自动完成建议的自动完成 provider。

   You can replace this with a custom implementation.

   您可以用自定义实现来替代它。
   */
  public lazy var autocompleteProvider: AutocompleteProvider = DisabledAutocompleteProvider()

  /**
   The callout action provider that is used to provide the
   keyboard with secondary callout actions.

   用于为键盘提供辅助呼出操作的呼出操作 provider。

   You can replace this with a custom implementation.

   您可以用自定义实现来替代它。
   */
  public lazy var calloutActionProvider: CalloutActionProvider = StandardCalloutActionProvider(
    keyboardContext: keyboardContext
  ) {
    didSet { refreshProperties() }
  }

  /**
   The input set provider that is used to define the input
   keys of the keyboard.

   输入集提供程序，用于定义键盘的输入键。

   You can replace this with a custom implementation.

   您可以用自定义实现来替代它。
   */
  public lazy var inputSetProvider: InputSetProvider = StandardInputSetProvider(
    keyboardContext: keyboardContext
  ) {
    didSet { refreshProperties() }
  }

  /**
   The keyboard action handler to use.

   要使用的键盘动作处理程序。
   */
  public lazy var keyboardActionHandler: KeyboardActionHandler = {
    let handler = AIAwareKeyboardActionHandler(
      controller: self,
      keyboardContext: self.keyboardContext,
      rimeContext: self.rimeContext,
      keyboardBehavior: self.keyboardBehavior,
      autocompleteContext: self.autocompleteContext,
      keyboardFeedbackHandler: self.keyboardFeedbackHandler,
      spaceDragGestureHandler: self.spaceDragGestureHandler
    )
    
    // 设置AI查询输入处理回调
    if let aiHandler = handler as? AIAwareKeyboardActionHandler {
      aiHandler.aiInputHandler = { [weak self] character in
        guard let self = self,
              let rootView = self.keyboardRootView else { return false }
        
        // 将键盘输入路由到KeyboardRootView的AI查询功能
        return rootView.handleKeyInput(character)
      }
    }
    
    return handler
  }()

  /**
   The appearance that is used to customize the keyboard's
   design, such as its colors, fonts etc.

   用于自定义键盘的外观，如颜色、字体等。

   You can replace this with a custom implementation.

   您可以用自定义实现来替代它。
   */
  public lazy var keyboardAppearance: KeyboardAppearance = StandardKeyboardAppearance(keyboardContext: keyboardContext)

  /**
   The behavior that is used to determine how the keyboard
   should behave when certain things happen.

   用于确定在某些事情发生时键盘应表现的行为。

   You can replace this with a custom implementation.

   您可以用自定义实现来替代它。
   */
  public lazy var keyboardBehavior: KeyboardBehavior = StandardKeyboardBehavior(keyboardContext: keyboardContext)

  /**
   The feedback handler that is used to trigger haptic and
   audio feedback.

   用于触发触觉和音频反馈的反馈处理程序。

   You can replace this with a custom implementation.

   您可以用自定义实现来替代它。
   */
  public lazy var keyboardFeedbackHandler: KeyboardFeedbackHandler = StandardKeyboardFeedbackHandler(settings: keyboardFeedbackSettings)

  /**
   The space drag gesture handler that is used to handle space drag gestures.

   用于处理空格拖拽手势的处理程序。

   You can replace this with a custom implementation.

   您可以用自定义实现来替代它。  
   */
  public lazy var spaceDragGestureHandler: DragGestureHandler = SpaceCursorDragGestureHandler(
    feedbackHandler: keyboardFeedbackHandler,
    action: { [weak self] offset in
      self?.adjustTextPosition(byCharacterOffset: offset)
    }
  )

  /**
   This keyboard layout provider that is used to setup the
   complete set of keys and their layout.

   此键盘布局 provider 用于设置整套键盘按键及其布局。

   You can replace this with a custom implementation.

   您可以用自定义实现来替代它。
   */
  public lazy var keyboardLayoutProvider: KeyboardLayoutProvider = StandardKeyboardLayoutProvider(
    keyboardContext: keyboardContext,
    inputSetProvider: inputSetProvider
  )

  /**
   RIME 引擎上下文
   */
  public lazy var rimeContext = RimeContext()

  // MARK: - Text And Selection, Implementations UITextInputDelegate

  /// 当文档中的选择即将发生变化时，通知输入委托。
  override open func selectionWillChange(_ textInput: UITextInput?) {
    super.selectionWillChange(textInput)
    resetAutocomplete()
  }

  /// 当文档中的选择发生变化时，通知输入委托。
  override open func selectionDidChange(_ textInput: UITextInput?) {
    super.selectionDidChange(textInput)
    resetAutocomplete()
  }

  /// 当 Document 中的 text 即将发生变化时，通知输入委托。
  /// - parameters:
  ///   * textInput: 采用 UITextInput 协议的文档实例。
  override open func textWillChange(_ textInput: UITextInput?) {
    super.textWillChange(textInput)

    // fix: 键盘跟随环境显示数字键盘
    if let keyboardType = textDocumentProxy.keyboardType, keyboardType.isNumberType {
      keyboardContext.setKeyboardType(.numericNineGrid)
    }

    if keyboardContext.textDocumentProxy === textDocumentProxy { return }
    keyboardContext.textDocumentProxy = textDocumentProxy
  }

  /// 当 Document 中的 text 发生变化时，通知输入委托。
  /// - parameters:
  ///   * textInput: 采用 UITextInput 协议的文档实例。
  override open func textDidChange(_ textInput: UITextInput?) {
    super.textDidChange(textInput)
//    performAutocomplete()
//    performTextContextSync()
//    tryChangeToPreferredKeyboardTypeAfterTextDidChange()

    // fix: 输出栏点击右侧x形按钮后, 输入法候选栏内容没有跟随输入栏一同清空
    if !self.textDocumentProxy.hasText {
      self.rimeContext.reset()
    }
  }

  // MARK: - Implementations KeyboardController

  open func adjustTextPosition(byCharacterOffset offset: Int) {
    textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
  }

  open func deleteBackward() {
    guard !rimeContext.userInputKey.isEmpty else {
      // 获取光标前后上下文，用于删除需要光标居中的符号
      let beforeInput = self.textDocumentProxy.documentContextBeforeInput ?? ""
      let afterInput = self.textDocumentProxy.documentContextAfterInput ?? ""
      let text = String(beforeInput.suffix(1) + afterInput.prefix(1))
      // 光标可以居中的符号，需要成对删除
      if keyboardContext.cursorBackOfSymbols(key: text) {
        self.textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
        self.textDocumentProxy.deleteBackward(times: 2)
      } else {
        textDocumentProxy.deleteBackward(range: keyboardBehavior.backspaceRange)
      }
      return
    }

    // 拼音九宫格处理
    if keyboardContext.keyboardType.isChineseNineGrid {
      if let selectCandidatePinyin = rimeContext.selectCandidatePinyin {
        if let t9pinyin = pinyinToT9Mapping[selectCandidatePinyin.0] {
          let handled = rimeContext.tryHandleReplaceInputTexts(t9pinyin, startPos: selectCandidatePinyin.1, count: selectCandidatePinyin.2)
          Logger.statistics.info("change input text handled: \(handled)")
        }
        rimeContext.selectCandidatePinyin = nil
        return
      }
    }

    // 非九宫格处理
    rimeContext.deleteBackward()
  }

  open func deleteBackward(times: Int) {
    textDocumentProxy.deleteBackward(times: times)
  }

  open func insertSymbol(_ symbol: Symbol) {
    // 检测是否需要顶字上屏
    if !rimeContext.userInputKey.isEmpty {
      // 内嵌模式需要先清空
      if keyboardContext.enableEmbeddedInputMode {
        self.textDocumentProxy.setMarkedText("", selectedRange: NSMakeRange(0, 0))
      }
      // fix: 内嵌模式问题
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) { [weak self] in
        guard let self = self else { return }
        // 顶码上屏
        if keyboardContext.swipePaging {
          if let firstCandidate = self.rimeContext.suggestions.first {
            self.textDocumentProxy.insertText(firstCandidate.text)
          }
        } else {
          if let commit = self.rimeContext.rimeContext?.commitTextPreview {
            self.textDocumentProxy.insertText(commit)
          }
        }
        self.rimeContext.reset()
        self.insertTextPatch(symbol.char)
      }
      return
    }

    self.insertTextPatch(symbol.char)
  }

  open func insertText(_ text: String) {
    if keyboardContext.keyboardType.isAlphabetic {
      textDocumentProxy.insertText(text)
      return
    }

    // 字母输入模式，不经过 rime 引擎
    // if rimeContext.asciiMode {
    //  textDocumentProxy.insertText(text)
    //  return
    // }

    // rime 引擎处理
    let handled = rimeContext.tryHandleInputText(text)
    if !handled {
      Logger.statistics.error("try handle input text: \(text), handle false")
      insertTextPatch(text)
      return
    }
  }

  open func selectNextKeyboard() {
    // advanceToNextInputMode()
  }

  open func selectNextLocale() {
//    keyboardContext.selectNextLocale()
  }

  open func setKeyboardType(_ type: KeyboardType) {
    // TODO: 键盘切换
//    if !rimeContext.userInputKey.isEmpty, type.isCustom || type.isChinesePrimaryKeyboard || type.isChineseNineGrid || type.isAlphabetic {
//      textDocumentProxy.insertText(rimeContext.userInputKey)
//      rimeContext.reset()
//    }
    keyboardContext.setKeyboardType(type)
  }

  open func setKeyboardCase(_ casing: KeyboardCase) {
    if keyboardContext.keyboardType.isChinesePrimaryKeyboard {
      keyboardContext.setKeyboardType(.chinese(casing))
      return
    }

    if case .custom(let name, _) = keyboardContext.keyboardType {
      keyboardContext.setKeyboardType(.custom(named: name, case: casing))
      return
    }

    keyboardContext.setKeyboardType(.alphabetic(casing))
  }

  open func openUrl(_ url: URL?) {
    let selector = sel_registerName("openURL:")
    var responder = self as UIResponder?
    while let r = responder, !r.responds(to: selector) {
      responder = r.next
    }
    _ = responder?.perform(selector, with: url)
  }

  open func resetInputEngine() {
    rimeContext.reset()
  }

  open func insertRimeKeyCode(_ keyCode: Int32) {
    guard rimeContext.tryHandleInputCode(keyCode) else {
      tryHandleSpecificCode(keyCode)
      return
    }
  }

  open func returnLastKeyboard() {
    keyboardContext.setKeyboardType(keyboardContext.returnKeyboardType())
  }

  // MARK: - Syncing

  /**
   Perform a text context sync.

   执行文本上下文同步。

   This is performed anytime the text is changed to ensure
   that ``keyboardTextContext`` is synced with the current
   text document context content.

   在更改文本时执行此操作，以确保 ``keyboardTextContext`` 与当前文本文档上下文内容同步。
   */
  open func performTextContextSync() {
    keyboardTextContext.sync(with: self)
  }

  // MARK: - Autocomplete

  /**
   The text that is provided to the ``autocompleteProvider``
   when ``performAutocomplete()`` is called.

   调用 ``performAutocomplete()`` 时提供给 ``autocompleteProvider`` 的文本。

   By default, the text document proxy's current word will
   be used. You can override this property to change that.

   默认情况下，将使用文本文档代理的当前单词。
   您可以覆盖此属性来更改。
   */
  open var autocompleteText: String? {
    textDocumentProxy.currentWord
  }

  /**
   Insert an autocomplete suggestion into the document.

   在文档中插入自动完成建议。

   By default, this call the `insertAutocompleteSuggestion`
   in the text document proxy, and then triggers a release
   in the keyboard action handler.

   默认情况下，这会调用文本文档代理中的 `insertAutocompleteSuggestion`，
   然后在键盘操作 handler 中触发 .release 操作。
   */
  open func insertAutocompleteSuggestion(_ suggestion: AutocompleteSuggestion) {
    textDocumentProxy.insertAutocompleteSuggestion(suggestion)
    keyboardActionHandler.handle(.release, on: .character(""))
  }

  /**
   Whether or not autocomplete is enabled.

   是否启用自动完成功能。

   By default, autocomplete is enabled as long as
   ``AutocompleteContext/isEnabled`` is `true`.

   默认情况下，只要 ``AutocompleteContext/isEnabled`` 为 `true`，自动完成功能就会启用。
   */
  open var isAutocompleteEnabled: Bool {
    autocompleteContext.isEnabled
  }

  /**
   Perform an autocomplete operation.

   执行自动完成操作。

   You can override this function to extend or replace the
   default logic. By default, it uses the `currentWord` of
   the ``textDocumentProxy`` to perform autocomplete using
   the current ``autocompleteProvider``.

   您可以重载此函数来扩展或替换默认逻辑。
   默认情况下，它会使用 ``textDocumentProxy`` 的 `currentWord`
   来使用当前的 ``autocompleteProvider`` 执行自动完成。
   */
  open func performAutocomplete() {
    guard isAutocompleteEnabled else { return }
    guard let text = autocompleteText else { return resetAutocomplete() }
    autocompleteProvider.autocompleteSuggestions(for: text) { [weak self] result in
      self?.updateAutocompleteContext(with: result)
    }
  }

  /**
   Reset the current autocomplete state.

   重置当前的自动完成状态。

   You can override this function to extend or replace the
   default logic. By default, it resets the suggestions in
   the ``autocompleteContext``.

   您可以重载此函数来扩展或替换默认逻辑。
   默认情况下，它会重置 ``autocompleteContext`` 中的 suggestion。
   */
  open func resetAutocomplete() {
    autocompleteContext.reset()
  }

  // MARK: - Dictation 听写

  /**
   The configuration to use when performing dictation from
   the keyboard extension.

   使用键盘扩展功能进行听写时要使用的配置。

   By default, this uses the `appGroupId` and `appDeepLink`
   properties from ``dictationContext``, so make sure that
   you call ``DictationContext/setup(with:)`` before using
   the dictation features in your keyboard extension.

   默认情况下，它会使用 ``dictationContext`` 中的 `appGroupId` 和 `appDeepLink` 属性，
   因此请确保在键盘扩展中使用听写功能前调用 ``DictationContext/setup(with:)` 。
   */
//  public var dictationConfig: KeyboardDictationConfiguration {
//    .init(
//      appGroupId: dictationContext.appGroupId ?? "",
//      appDeepLink: dictationContext.appDeepLink ?? ""
//    )
//  }

  /**
   Perform a keyboard-initiated dictation operation.

   执行键盘启动的听写操作。

   > Important: ``DictationContext/appDeepLink`` must have
   been set before this is called. The link must open your
   app and start dictation. See the docs for more info.

   > 重要：必须在调用此链接之前设置``DictationContext/appDeepLink``。
   > 链接必须打开主应用程序并开始听写。更多信息请参阅文档。
   */
//  public func performDictation() {
//    Task {
//      do {
//        try await dictationService.startDictationFromKeyboard(with: dictationConfig)
//      } catch {
//        await MainActor.run {
//          dictationContext.lastError = error
//        }
//      }
//    }
//  }
}

// MARK: - Private Functions

private extension KeyboardInputViewController {
  /// 刷新属性
  func refreshProperties() {
    refreshLayoutProvider()
    refreshCalloutActionContext()
  }

  /// 刷新呼出操作上下文
  func refreshCalloutActionContext() {
    calloutContext.action = ActionCalloutContext(
      actionHandler: keyboardActionHandler,
      actionProvider: calloutActionProvider
    )
  }

  /// 刷新布局 Provider
  func refreshLayoutProvider() {
    keyboardLayoutProvider.register(
      inputSetProvider: inputSetProvider
    )
  }

  /**
   Set up an initial width to avoid broken SwiftUI layouts.

   设置键盘初始宽度，以避免 SwiftUI 布局被破坏。
   */
  func setupInitialWidth() {
    view.frame.size.width = UIScreen.main.bounds.width
    Logger.statistics.debug("view frame width: \(UIScreen.main.bounds.width)")
  }

  /**
   Setup locale observation to handle locale-based changes.

   设置本地化观测，以处理基于本地化的更改。
   */
  func setupLocaleObservation() {
//    keyboardContext.$locale.sink { [weak self] in
//      guard let self = self else { return }
//      let locale = $0
//      self.primaryLanguage = locale.identifier
//      self.autocompleteProvider.locale = locale
//    }.store(in: &cancellables)
  }

  /**
   Set up the standard next keyboard button behavior.

   设置标准的下一个键盘按钮行为。
   */
  func setupNextKeyboardBehavior() {
    NextKeyboardController.shared = self
  }

  var needNumberKeyboard: Bool {
    switch textDocumentProxy.keyboardType {
    case .numbersAndPunctuation, .numberPad, .phonePad, .decimalPad, .asciiCapableNumberPad: return true
    default: return false
    }
  }

  /**
   RIME 引擎设置
   */
  func setupRIME() {
    // 异步 RIME 引擎启动
    Task.detached { [unowned self] in
//      if await rimeContext.isRunning {
//        Logger.statistics.debug("shutdown rime engine")
//        // 这里关闭引擎是为了使 RIME 内存中的自造词落盘。
//        await shutdownRIME()
//      }

      // 检测是否需要覆盖 RIME 目录
      // let overrideRimeDirectory = UserDefaults.hamster.overrideRimeDirectory

      // 检测对 appGroup 路径下是否有写入权限，如果没有写入权限，则需要将 appGroup 下文件复制到键盘的 Sandbox 路径下
//      if await !self.hasFullAccess {
//        do {
//          try FileManager.syncAppGroupUserDataDirectoryToSandbox(override: overrideRimeDirectory)
//
//          // 注意：如果没有开启键盘完全访问权限，则无权对 UserDefaults.hamster 写入
//          UserDefaults.hamster.overrideRimeDirectory = false
//        } catch {
//          Logger.statistics.error("FileManager.syncAppGroupUserDataDirectoryToSandbox(override: \(overrideRimeDirectory)) error: \(error.localizedDescription)")
//        }
//      }

      guard await !rimeContext.isRunning else { return }

      if let maximumNumberOfCandidateWords = await keyboardContext.hamsterConfiguration?.rime?.maximumNumberOfCandidateWords {
        await rimeContext.setMaximumNumberOfCandidateWords(maximumNumberOfCandidateWords)
      }

      if let swipePaging = await keyboardContext.hamsterConfiguration?.toolbar?.swipePaging {
        await rimeContext.setUseContextPaging(swipePaging == false)
      }

      await rimeContext.start(hasFullAccess: true)

      let simplifiedModeKey = await keyboardContext.hamsterConfiguration?.rime?.keyValueOfSwitchSimplifiedAndTraditional ?? ""
      await rimeContext.syncTraditionalSimplifiedChineseMode(simplifiedModeKey: simplifiedModeKey)
    }
  }

  func shutdownRIME() {
    /// 停止引擎，触发自造词等数据落盘
    rimeContext.shutdown()

    /// 重新启动引擎
    /// rimeContext.start(hasFullAccess: hasFullAccess)
  }

  /// Combine 观测 RIME 引擎中的用户输入及上屏文字
  func setupCombineRIMEInput() {
    rimeContext.userInputKeyPublished
      .receive(on: DispatchQueue.main)
      .sink { [weak self] inputText in
        guard let self = self else { return }

        // 获取与清空在一起，防止重复上屏
        var commitText = self.rimeContext.commitText
        self.rimeContext.resetCommitText()

        // 写入上屏文字
        if !commitText.isEmpty {
          // 九宫格编码转换
          if keyboardContext.keyboardType.isChineseNineGrid {
            commitText = commitText.replaceT9pinyin
          }

          // 检查是否为AI查询模式，如果是则路由到AIQueryView
          if let aiHandler = self.keyboardActionHandler as? AIAwareKeyboardActionHandler,
             let rootView = self.keyboardRootView {
            // 通过AIAwareKeyboardActionHandler的回调将文本路由到AIQueryView
            if let callback = aiHandler.aiInputHandler, callback(commitText) {
              Logger.statistics.debug("KeyboardInputViewController: RIME提交文本已路由到AIQueryView: '\(commitText)'")
              return // 已被AI查询视图处理，不再发送到主应用
            }
          }

          // 如果不是AI查询模式或AI查询视图未处理，则正常发送到主应用
          self.textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))

          // 写入 userInputKey
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
            self.insertTextPatch(commitText)
          }
        }

        // 非嵌入模式在 CandidateWordsView.swift 中处理，直接输入 Label 中
        guard self.keyboardContext.enableEmbeddedInputMode else { return }

        // 写入 userInputKey
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
          if self.keyboardContext.keyboardType.isChineseNineGrid {
            let t9UserInputKey = self.rimeContext.t9UserInputKey
            self.textDocumentProxy.setMarkedText(t9UserInputKey, selectedRange: NSMakeRange(t9UserInputKey.utf8.count, 0))
            return
          }
          self.textDocumentProxy.setMarkedText(inputText, selectedRange: NSMakeRange(inputText.utf8.count, 0))
        }
      }
      .store(in: &cancellables)

//    rimeContext.registryHandleUserInputKeyChanged { [weak self] inputText in
//      guard let self = self else { return }
//
//      // 获取与清空在一起，防止重复上屏
//      let commitText = self.rimeContext.commitText
//      self.rimeContext.resetCommitText()
//
//      // 写入上屏文字
//      if !commitText.isEmpty {
//        self.textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
//
//        // 写入 userInputKey
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
//          self.insertTextPatch(commitText)
//        }
//      }
//
//      // 非嵌入模式在 CandidateWordsView.swift 中处理，直接输入 Label 中
//      guard self.keyboardContext.enableEmbeddedInputMode else { return }
//
//      // 写入 userInputKey
//      DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
//        if self.keyboardContext.keyboardType.isChineseNineGrid {
//          let t9UserInputKey = self.rimeContext.t9UserInputKey
//          self.textDocumentProxy.setMarkedText(t9UserInputKey, selectedRange: NSMakeRange(t9UserInputKey.utf8.count, 0))
//          return
//        }
//        self.textDocumentProxy.setMarkedText(inputText, selectedRange: NSMakeRange(inputText.utf8.count, 0))
//      }
//    }
  }

  /// 在 ``textDocumentProxy`` 的文本发生变化后，尝试更改为首选键盘类型
  func tryChangeToPreferredKeyboardTypeAfterTextDidChange() {
    let context = keyboardContext
    let shouldSwitch = keyboardBehavior.shouldSwitchToPreferredKeyboardTypeAfterTextDidChange()
    guard shouldSwitch else { return }
    setKeyboardType(context.preferredKeyboardType)
  }

  /**
   Update the autocomplete context with a certain result.

   根据特定结果更新自动完成的上下文。

   This is performed async to avoid that any network-based
   operations update the context from a background thread.

   这是同步执行的，需要避免任何基于网络的操作从后台线程更新上下文。
   */
  func updateAutocompleteContext(with result: AutocompleteResult) {
    DispatchQueue.main.async { [weak self] in
      guard let context = self?.autocompleteContext else { return }
      switch result {
      case .failure(let error): context.lastError = error
      case .success(let result): context.suggestions = result
      }
    }
  }

  /// 上屏补丁：增加了成对符号/光标回退/返回主键盘的支持
  func insertTextPatch(_ insertText: String) {
    // 替换为成对符号
    let text = keyboardContext.getPairSymbols(insertText)

    // 检测光标是否需要回退
    if keyboardContext.cursorBackOfSymbols(key: text) {
      // 检测是否有选中的文字，可以居中的光标将自动包裹选中的文本
      if text.count > 0, text.count % 2 == 0 {
        let selectText = textDocumentProxy.selectedText ?? ""
        let halfLength = text.count / 2
        let firstHalf = String(text.prefix(halfLength))
        let secondHalf = String(text.suffix(halfLength))
        textDocumentProxy.insertText("\(firstHalf)\(selectText)\(secondHalf)")
        // 如果选中的文字为空，将光标挪到中间，否则不用移动
        let offset = selectText.count == 0 ? halfLength : 0
        self.adjustTextPosition(byCharacterOffset: -offset)
      } else {
        textDocumentProxy.insertText(text)
        self.adjustTextPosition(byCharacterOffset: -1)
      }
    } else {
      textDocumentProxy.insertText(text)
    }

    // 检测是否需要返回主键盘
    let returnToPrimaryKeyboard = keyboardContext.returnToPrimaryKeyboardOfSymbols(key: insertText)
    if returnToPrimaryKeyboard {
      keyboardContext.setKeyboardType(keyboardContext.returnKeyboardType())
    }
  }
}

extension UIKeyboardType {
  var isNumberType: Bool {
    switch self {
    // 数字键盘
    case .numberPad, .numbersAndPunctuation, .phonePad, .decimalPad, .asciiCapableNumberPad: return true
    default: return false
    }
  }
}