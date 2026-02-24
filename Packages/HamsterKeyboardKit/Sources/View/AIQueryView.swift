//
//  AIQueryView.swift
//
//
//  Created by AI Assistant on 2024/12/19.
//

import Combine
import Foundation
import HamsterKit
import HamsterUIKit
import OSLog
import UIKit

/**
 AI查询视图

 用于显示AI查询界面，包含：
 1. 文本输入框：用于用户输入待查询的文本
 2. 查询按钮：点击后发送HTTP POST请求
 3. 响应内容显示框：显示AI响应结果，最多10行
 4. 插入按钮：将响应内容插入到文本输入框
 5. 重新生成按钮：重新发送请求
 */
class AIQueryView: NibLessView {
  private let appearance: KeyboardAppearance
  private let actionHandler: KeyboardActionHandler
  private let keyboardContext: KeyboardContext
  private var style: CandidateBarStyle
  private var subscriptions = Set<AnyCancellable>()

  /// AI查询结果回调
  var onInsertText: ((String) -> Void)?

  /// 当前查询任务
  private var currentTask: URLSessionDataTask?

  /// 当前响应内容
  private var currentResponse: String = ""

  /// 当前会话ID
  private var currentSessionId: String = ""

  /// AI查询模式是否激活（用于外部键盘输入处理）
  private var isAIInputActive: Bool = false

  /// 跨target共享用户管理器
  private let sharedUserManager = SharedUserManager.shared

  // MARK: - UI Components

  /// 容器视图
  lazy var containerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    // 使用更协调的背景色，根据键盘主题自适应
    view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
    view.layer.cornerRadius = 12
    view.layer.shadowColor = UIColor.black.cgColor
    view.layer.shadowOffset = CGSize(width: 0, height: -2)
    view.layer.shadowRadius = 4
    view.layer.shadowOpacity = 0.1
    return view
  }()

  /// 内容堆栈视图
  lazy var contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .vertical
    stackView.spacing = 8  // 减少间距从12到8
    stackView.alignment = .fill
    stackView.distribution = .fill
    return stackView
  }()

  /// 输入区域容器
  lazy var inputContainer: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = style.toolbarButtonBackgroundColor.withAlphaComponent(0.1)
    view.layer.cornerRadius = 8
    return view
  }()

  /// 文本输入框
  lazy var queryTextField: UITextField = {
    let textField = UITextField()
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.font = UIFont.systemFont(ofSize: 16)
    textField.textColor = style.candidateTextColor
    textField.backgroundColor = .systemBackground
    textField.layer.cornerRadius = 6
    textField.layer.borderWidth = 1
    textField.layer.borderColor = style.toolbarButtonBackgroundColor.cgColor
    textField.placeholder = "请输入您要查询的问题..."
    textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
    textField.leftViewMode = .always
    textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
    textField.rightViewMode = .always
    textField.returnKeyType = .search
    textField.delegate = self
    textField.clearButtonMode = .whileEditing
    textField.isUserInteractionEnabled = true

    // 在键盘扩展中，禁用系统输入法相关功能，改为手动管理输入
    textField.autocorrectionType = .no
    textField.spellCheckingType = .no
    textField.smartQuotesType = .no
    textField.smartDashesType = .no
    textField.smartInsertDeleteType = .no

    // 禁用系统键盘，因为我们在键盘扩展中
    textField.inputView = UIView() // 设置空的inputView来禁用系统键盘

    return textField
  }()

  /// 按钮容器
  lazy var buttonContainer: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  /// 查询按钮
  lazy var queryButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("查询", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    button.setTitleColor(.white, for: .normal)
    button.backgroundColor = .systemBlue
    button.layer.cornerRadius = 8
    button.addTarget(self, action: #selector(queryButtonTapped), for: .touchUpInside)
    return button
  }()

  /// 重新生成按钮
  lazy var regenerateButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("重新生成", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    button.setTitleColor(.white, for: .normal)
    button.backgroundColor = .systemOrange
    button.layer.cornerRadius = 8
    button.addTarget(self, action: #selector(regenerateButtonTapped), for: .touchUpInside)
    button.isHidden = true // 初始隐藏
    return button
  }()

  /// 响应内容显示框
  lazy var responseTextView: UITextView = {
    let textView = UITextView()
    textView.translatesAutoresizingMaskIntoConstraints = false
    textView.font = UIFont.systemFont(ofSize: 14)
    textView.textColor = style.candidateTextColor
    textView.backgroundColor = .systemBackground
    textView.layer.cornerRadius = 8
    textView.layer.borderWidth = 1
    textView.layer.borderColor = style.toolbarButtonBackgroundColor.cgColor
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    textView.isEditable = false
    textView.isScrollEnabled = true
    textView.text = ""
    textView.isHidden = true // 初始隐藏
    return textView
  }()

  /// 插入按钮
  lazy var insertButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setTitle("插入", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    button.setTitleColor(.white, for: .normal)
    button.backgroundColor = .systemGreen
    button.layer.cornerRadius = 8
    button.addTarget(self, action: #selector(insertButtonTapped), for: .touchUpInside)
    button.isHidden = true // 初始隐藏
    return button
  }()

  /// 加载指示器
  lazy var loadingIndicator: UIActivityIndicatorView = {
    let indicator = UIActivityIndicatorView(style: .medium)
    indicator.translatesAutoresizingMaskIntoConstraints = false
    indicator.hidesWhenStopped = true
    indicator.color = style.candidateTextColor
    return indicator
  }()

  // MARK: - Initialization

  init(appearance: KeyboardAppearance, actionHandler: KeyboardActionHandler, keyboardContext: KeyboardContext) {
    self.appearance = appearance
    self.actionHandler = actionHandler
    self.keyboardContext = keyboardContext
    self.style = appearance.candidateBarStyle

    super.init(frame: .zero)

    Logger.statistics.info("AIQueryView: 初始化AI查询视图")
    setupSubview()
  }

  func setupSubview() {
    constructViewHierarchy()
    activateViewConstraints()
    setupAppearance()
  }

  override func constructViewHierarchy() {
    Logger.statistics.debug("AIQueryView: 构建视图层次结构")

    addSubview(containerView)
    containerView.addSubview(contentStackView)

    // 添加输入区域
    inputContainer.addSubview(queryTextField)
    contentStackView.addArrangedSubview(inputContainer)

    // 添加按钮容器
    buttonContainer.addSubview(queryButton)
    buttonContainer.addSubview(regenerateButton)
    buttonContainer.addSubview(loadingIndicator)
    contentStackView.addArrangedSubview(buttonContainer)

    // 添加响应区域
    contentStackView.addArrangedSubview(responseTextView)

    // 添加插入按钮
    contentStackView.addArrangedSubview(insertButton)
  }

  override func activateViewConstraints() {
    Logger.statistics.debug("AIQueryView: 激活视图约束")

    NSLayoutConstraint.activate([
      // 容器视图约束 - 填充整个视图并留出边距
      containerView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
      containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

      // 内容堆栈视图约束 - 减少边距
      contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
      contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
      contentStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
      contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),

      // 输入容器约束
      inputContainer.heightAnchor.constraint(equalToConstant: 40),

      // 文本输入框约束
      queryTextField.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 6),
      queryTextField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 8),
      queryTextField.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -8),
      queryTextField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -6),

      // 按钮容器约束
      buttonContainer.heightAnchor.constraint(equalToConstant: 36),

      // 查询按钮约束
      queryButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
      queryButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
      queryButton.widthAnchor.constraint(equalToConstant: 70),
      queryButton.heightAnchor.constraint(equalToConstant: 32),

      // 重新生成按钮约束
      regenerateButton.leadingAnchor.constraint(equalTo: queryButton.trailingAnchor, constant: 10),
      regenerateButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
      regenerateButton.widthAnchor.constraint(equalToConstant: 90),
      regenerateButton.heightAnchor.constraint(equalToConstant: 32),

      // 加载指示器约束
      loadingIndicator.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
      loadingIndicator.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),

      // 响应文本框约束 - 减少高度
      responseTextView.heightAnchor.constraint(equalToConstant: 80),

      // 插入按钮约束
      insertButton.heightAnchor.constraint(equalToConstant: 36),
    ])
  }

  override func setupAppearance() {
    Logger.statistics.debug("AIQueryView: 设置外观")

    backgroundColor = .clear

    // 更新容器样式 - 使用协调的背景色
    containerView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)

    // 更新样式依赖的UI元素
    queryTextField.textColor = style.candidateTextColor
    queryTextField.layer.borderColor = style.toolbarButtonBackgroundColor.cgColor

    responseTextView.textColor = style.candidateTextColor
    responseTextView.layer.borderColor = style.toolbarButtonBackgroundColor.cgColor

    inputContainer.backgroundColor = style.toolbarButtonBackgroundColor.withAlphaComponent(0.1)

    loadingIndicator.color = style.candidateTextColor
  }

  // MARK: - Public Methods

  func updateStyle(_ newStyle: CandidateBarStyle) {
    Logger.statistics.debug("AIQueryView: 更新样式")
    self.style = newStyle
    setupAppearance()
  }

  /// 聚焦到文本输入框
  func focusTextField() {
    Logger.statistics.debug("AIQueryView: 手动设置文本输入框焦点")
    isAIInputActive = true

    // 在键盘扩展中，让TextField成为第一响应者以获得光标，但不显示系统键盘
    DispatchQueue.main.async {
      self.queryTextField.becomeFirstResponder()
      Logger.statistics.debug("AIQueryView: AI输入模式已激活，TextField已获得焦点")
    }
  }

  /// 处理外部键盘输入（由AIAwareKeyboardActionHandler调用）
  func handleKeyInput(_ character: String) -> Bool {
    guard isAIInputActive else { return false }

    Logger.statistics.debug("AIQueryView: 处理外部键盘输入: '\(character)'")

    // 处理清空指令
    if character == "\u{1B}[2J" {
      queryTextField.text = ""
      Logger.statistics.debug("AIQueryView: 清空文本输入框")
      return true
    }

    if character == "\n" || character == "\r" {
      // 回车键执行查询
      queryButtonTapped()
      return true
    }

    if character == "\u{8}" || character == "\u{7f}" { // 退格键
      if let text = queryTextField.text, !text.isEmpty {
        queryTextField.text = String(text.dropLast())
        Logger.statistics.debug("AIQueryView: 删除字符，当前文本: '\(self.queryTextField.text ?? "")'")
      }
      return true
    }

    // 普通字符输入
    let currentText = queryTextField.text ?? ""
    queryTextField.text = currentText + character
    Logger.statistics.debug("AIQueryView: 添加字符，当前文本: '\(self.queryTextField.text ?? "")'")

    return true
  }

  // MARK: - Action Methods

  @objc private func queryButtonTapped() {
    Logger.statistics.info("AIQueryView: 用户点击查询按钮")

    guard let queryText = queryTextField.text,
          !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      Logger.statistics.warning("AIQueryView: 查询文本为空，忽略查询请求")
      return
    }

    // 收起键盘并禁用AI输入模式
    queryTextField.resignFirstResponder()
    isAIInputActive = false

    performQuery(originalQuery: queryText)
  }

  @objc private func regenerateButtonTapped() {
    Logger.statistics.info("AIQueryView: 用户点击重新生成按钮")

    guard let queryText = queryTextField.text,
          !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      Logger.statistics.warning("AIQueryView: 查询文本为空，无法重新生成")
      return
    }

    performQuery(originalQuery: queryText, isRegenerate: true)
  }

  @objc private func insertButtonTapped() {
    Logger.statistics.info("AIQueryView: 用户点击插入按钮，响应内容长度: \(self.currentResponse.count)")

    guard !currentResponse.isEmpty else {
      Logger.statistics.warning("AIQueryView: 响应内容为空，无法插入")
      return
    }

    // 通过回调插入文本
    onInsertText?(currentResponse)
  }

  // MARK: - Private Methods

  private func performQuery(originalQuery: String, isRegenerate: Bool = false) {
    Logger.statistics.info("AIQueryView: 开始执行查询，查询文本: '\(originalQuery)'，是否重新生成: \(isRegenerate)")

    // 检查用户登录状态
    guard sharedUserManager.isLoggedIn else {
      Logger.statistics.warning("AIQueryView: 用户未登录，无法执行AI查询")
      showError("请先登录")
      return
    }

    // 获取当前用户信息
    guard let currentUser = sharedUserManager.currentUser else {
      Logger.statistics.error("AIQueryView: 无法获取当前用户信息")
      showError("获取用户信息失败")
      return
    }

    // 取消之前的请求
    currentTask?.cancel()

    // 显示加载状态
    showLoadingState()

    // 创建请求 - 使用IP地址避免DNS解析问题
    let urlString = "https://www.idlab.top/userapi/knowledge/chatNew"
    guard let url = URL(string: urlString) else {
      Logger.statistics.error("AIQueryView: 无效的请求URL")
      hideLoadingState()
      showError("请求地址无效")
      return
    }

    // 为键盘扩展配置专门的 URLSession 以处理沙盒限制
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 90.0  // 增加超时时间到45秒
    sessionConfig.timeoutIntervalForResource = 90.0 // 增加资源超时到90秒
    sessionConfig.allowsCellularAccess = true
    sessionConfig.waitsForConnectivity = true
    sessionConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

    // 键盘扩展专门配置 - 解决沙盒DNS访问问题
    sessionConfig.urlCache = nil // 禁用缓存避免沙盒问题
    sessionConfig.httpShouldUsePipelining = false // 禁用管道化
    sessionConfig.httpMaximumConnectionsPerHost = 1 // 限制连接数
    sessionConfig.networkServiceType = .default

    let session = URLSession(configuration: sessionConfig)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("HamsterKeyboard/1.0", forHTTPHeaderField: "User-Agent")
    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

    // 添加认证请求头
    request.setValue(currentUser.token, forHTTPHeaderField: "Authorization")
    request.setValue(currentUser.username, forHTTPHeaderField: "openid")

    // 键盘扩展网络请求特殊配置
    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    request.timeoutInterval = 90.0

    Logger.statistics.debug("AIQueryView: 键盘扩展网络请求配置完成 - Authorization: \(currentUser.token.prefix(20))..., openid: \(currentUser.username)")

    // 构建请求体 - 根据Kotlin代码的格式
    let targetContent = isRegenerate ? "回答不满意，请重新生成" : originalQuery
    var requestBody: [String: Any] = [
      "question": targetContent
    ]

    // 添加会话ID（如果存在）
    if !currentSessionId.isEmpty {
      requestBody["lastSessionId"] = currentSessionId
        Logger.statistics.debug("AIQueryView: 添加会话ID: \(self.currentSessionId)")
    }

    // 可选：添加知识库ID（暂时注释，根据需要启用）
    // requestBody["knowledgeBaseIds"] = knowledgeBaseIds

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
      Logger.statistics.debug("AIQueryView: 请求体构建成功，包含字段: \(requestBody.keys), 大小: \(request.httpBody?.count ?? 0) bytes")
    } catch {
      Logger.statistics.error("AIQueryView: 请求体构建失败: \(error.localizedDescription)")
      hideLoadingState()
      showError("请求构建失败")
      return
    }

    Logger.statistics.info("AIQueryView: 开始发送键盘扩展网络请求到: \(url.absoluteString)")

    // 发送请求 - 使用键盘扩展优化的配置
    currentTask = session.dataTask(with: request) { [weak self] data, response, error in
      DispatchQueue.main.async {
        self?.handleQueryResponse(data: data, response: response, error: error, session: session)
      }
    }

    currentTask?.resume()
    Logger.statistics.info("AIQueryView: 键盘扩展HTTP请求已发送，用户: \(currentUser.username), URL: \(url.absoluteString)")
  }

  private func handleQueryResponse(data: Data?, response: URLResponse?, error: Error?, session: URLSession? = nil) {
    hideLoadingState()

    // 确保session被正确释放
    session?.invalidateAndCancel()

    if let error = error {
      let nsError = error as NSError
      Logger.statistics.error("AIQueryView: 键盘扩展网络请求失败 - 错误码: \(nsError.code), 域: \(nsError.domain), 描述: \(error.localizedDescription)")

      // 根据不同的网络错误提供更具体的错误信息，特别处理键盘扩展沙盒问题
      var errorMessage: String
      switch nsError.code {
      case NSURLErrorNotConnectedToInternet:
        errorMessage = "网络连接不可用，请检查网络设置"
      case NSURLErrorTimedOut:
        errorMessage = "请求超时，键盘扩展网络访问受限，请稍后重试"
      case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
        errorMessage = "无法连接到服务器，键盘扩展网络受限，请检查网络设置"
      case NSURLErrorNetworkConnectionLost:
        errorMessage = "网络连接已断开，请重新连接网络"
      case NSURLErrorDNSLookupFailed:
        errorMessage = "DNS解析失败，键盘扩展沙盒限制，请检查网络设置或稍后重试"
      case NSURLErrorSecureConnectionFailed:
        errorMessage = "安全连接失败，请检查网络设置"
      case NSURLErrorResourceUnavailable:
        errorMessage = "网络资源不可用，键盘扩展访问受限"
      default:
        // 特别处理键盘扩展沙盒相关错误
        if nsError.domain == "NSURLErrorDomain" && nsError.code == -1003 {
          errorMessage = "键盘扩展网络访问受限，DNS服务不可用，请稍后重试"
        } else {
          errorMessage = "键盘扩展网络请求失败: \(error.localizedDescription)"
        }
      }

      showError(errorMessage)
      return
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      Logger.statistics.error("AIQueryView: 无效的HTTP响应")
      showError("无效的响应")
      return
    }

    guard let data = data else {
      Logger.statistics.error("AIQueryView: 响应数据为空")
      showError("响应数据为空")
      return
    }

    Logger.statistics.info("AIQueryView: 键盘扩展收到响应，状态码: \(httpResponse.statusCode)，数据大小: \(data.count) bytes")

    // 记录响应头信息用于调试
    Logger.statistics.debug("AIQueryView: 键盘扩展响应头信息: \(httpResponse.allHeaderFields)")

    if httpResponse.statusCode == 200 {
      // 成功响应
      do {
        if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
          Logger.statistics.debug("AIQueryView: JSON解析成功，响应字段: \(jsonObject.keys)")

          // 根据Kotlin代码的响应格式解析
          if let sessionId = jsonObject["sessionId"] as? String {
            currentSessionId = sessionId
            Logger.statistics.debug("AIQueryView: 更新会话ID: \(sessionId)")
          }

          if let aiReply = jsonObject["text"] as? String {
            Logger.statistics.info("AIQueryView: 解析得到AI回复，长度: \(aiReply.count)")
            showResponse(aiReply)
          } else {
            // 如果没有找到 text 字段，尝试其他可能的字段
            var responseText = ""
            if let content = jsonObject["content"] as? String {
              responseText = content
              Logger.statistics.debug("AIQueryView: 使用 content 字段作为响应")
            } else if let answer = jsonObject["answer"] as? String {
              responseText = answer
              Logger.statistics.debug("AIQueryView: 使用 answer 字段作为响应")
            } else if let result = jsonObject["result"] as? String {
              responseText = result
              Logger.statistics.debug("AIQueryView: 使用 result 字段作为响应")
            } else {
              responseText = String(data: data, encoding: .utf8) ?? "解析响应失败"
              Logger.statistics.warning("AIQueryView: 未找到预期的响应字段，使用原始响应内容")
            }

            Logger.statistics.info("AIQueryView: 使用备用字段解析得到响应文本，长度: \(responseText.count)")
            showResponse(responseText)
          }
        } else {
          // 如果不是JSON格式，直接显示文本
          let responseText = String(data: data, encoding: .utf8) ?? "无法解析响应"
          Logger.statistics.info("AIQueryView: 非JSON响应，直接显示文本，长度: \(responseText.count)")
          showResponse(responseText)
        }
      } catch {
        Logger.statistics.error("AIQueryView: JSON解析失败: \(error.localizedDescription)")
        Logger.statistics.debug("AIQueryView: 原始响应数据: \(String(data: data, encoding: .utf8) ?? "无法转换为字符串")")
        showError("响应解析错误，请稍后重试")
      }
    } else {
      // 错误响应
      Logger.statistics.error("AIQueryView: 服务器响应错误，状态码: \(httpResponse.statusCode)")

      // 记录完整的错误响应内容用于调试
      if let errorData = String(data: data, encoding: .utf8) {
        Logger.statistics.debug("AIQueryView: 错误响应内容: \(errorData)")
      }

      // 尝试解析错误信息
      var errorMessage = "服务器响应错误"
      if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let error = errorJSON["error"] as? String {
        errorMessage = "服务器错误: \(error)"
      } else {
        switch httpResponse.statusCode {
        case 400:
          errorMessage = "请求参数错误(400)"
        case 401:
          errorMessage = "认证失败，请重新登录(401)"
        case 403:
          errorMessage = "权限不足(403)"
        case 404:
          errorMessage = "服务不存在(404)"
        case 429:
          errorMessage = "请求过于频繁，请稍后重试(429)"
        case 500:
          errorMessage = "服务器内部错误(500)"
        case 502, 503, 504:
          errorMessage = "服务器暂时不可用，请稍后重试(\(httpResponse.statusCode))"
        default:
          let statusMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
          errorMessage = "服务器响应错误: \(httpResponse.statusCode) - \(statusMessage)"
        }

        if httpResponse.statusCode == 429 || httpResponse.statusCode >= 500 {
          errorMessage += "，请检查是否还有请求配额"
        }
      }

      showError(errorMessage)
    }
  }

  private func showLoadingState() {
    Logger.statistics.debug("AIQueryView: 显示加载状态")

    loadingIndicator.startAnimating()
    queryButton.isEnabled = false
    regenerateButton.isEnabled = false
    insertButton.isEnabled = false

    queryButton.alpha = 0.6
    regenerateButton.alpha = 0.6
    insertButton.alpha = 0.6
  }

  private func hideLoadingState() {
    Logger.statistics.debug("AIQueryView: 隐藏加载状态")

    loadingIndicator.stopAnimating()
    queryButton.isEnabled = true
    regenerateButton.isEnabled = true
    insertButton.isEnabled = true

    queryButton.alpha = 1.0
    regenerateButton.alpha = 1.0
    insertButton.alpha = 1.0
  }

  private func showResponse(_ text: String) {
    Logger.statistics.info("AIQueryView: 显示响应内容，长度: \(text.count)")

    currentResponse = text

    // 处理最多10行的限制
    let lines = text.components(separatedBy: .newlines)
    let displayText: String

    if lines.count > 10 {
      let first10Lines = Array(lines.prefix(10))
      displayText = first10Lines.joined(separator: "\n") + "\n..."
      Logger.statistics.debug("AIQueryView: 响应内容超过10行，已截断显示")
    } else {
      displayText = text
    }

    responseTextView.text = displayText
    responseTextView.isHidden = false
    regenerateButton.isHidden = false
    insertButton.isHidden = false
  }

  private func showError(_ message: String) {
    Logger.statistics.error("AIQueryView: 显示错误信息: \(message)")

    currentResponse = ""
    responseTextView.text = "错误: \(message)"
    responseTextView.isHidden = false
    regenerateButton.isHidden = false
    insertButton.isHidden = true // 错误时隐藏插入按钮
  }
}

// MARK: - UITextFieldDelegate

extension AIQueryView: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    Logger.statistics.debug("AIQueryView: 用户按下回车键，执行查询")
    queryButtonTapped()
    return true
  }

  func textFieldDidBeginEditing(_ textField: UITextField) {
    Logger.statistics.debug("AIQueryView: 文本输入框获得焦点")
    isAIInputActive = true
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
    Logger.statistics.debug("AIQueryView: 文本输入框失去焦点")
    isAIInputActive = false
  }
}
