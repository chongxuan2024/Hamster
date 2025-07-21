//
//  UserProfileRootView.swift
//  Hamster
//
//  Created by AI Assistant on 2024/12/19.
//

import Combine
import HamsterUIKit
import UIKit

/// 用户资料页面根视图
public class UserProfileRootView: NibLessView {
  private let userProfileViewModel: UserProfileViewModel
  private var subscriptions = Set<AnyCancellable>()
  
  // MARK: - UI Components
  
  private lazy var scrollView: UIScrollView = {
    let scrollView = UIScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.keyboardDismissMode = .onDrag
    return scrollView
  }()
  
  private lazy var contentView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()
  
  // MARK: - Login/Register Views
  
  private lazy var loginContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()
  
  private lazy var loginTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "账号登录"
    label.font = UIFont.boldSystemFont(ofSize: 24)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  private lazy var usernameTextField: UITextField = {
    let textField = UITextField()
    textField.placeholder = "用户名"
    textField.borderStyle = .roundedRect
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no
    textField.translatesAutoresizingMaskIntoConstraints = false
    return textField
  }()
  
  private lazy var passwordTextField: UITextField = {
    let textField = UITextField()
    textField.placeholder = "密码"
    textField.borderStyle = .roundedRect
    textField.isSecureTextEntry = true
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no
    textField.translatesAutoresizingMaskIntoConstraints = false
    return textField
  }()
  
  private lazy var loginButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("登录", for: .normal)
    button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    button.backgroundColor = .systemBlue
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 8
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
    return button
  }()
  
  private lazy var registerButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("没有账号？立即注册", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(registerButtonTapped), for: .touchUpInside)
    return button
  }()
  
  // MARK: - Register Views
  
  private lazy var registerContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isHidden = true
    return view
  }()
  
  private lazy var registerTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "账号注册"
    label.font = UIFont.boldSystemFont(ofSize: 24)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  private lazy var registerUsernameTextField: UITextField = {
    let textField = UITextField()
    textField.placeholder = "用户名"
    textField.borderStyle = .roundedRect
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no
    textField.translatesAutoresizingMaskIntoConstraints = false
    return textField
  }()
  
  private lazy var registerEmailTextField: UITextField = {
    let textField = UITextField()
    textField.placeholder = "邮箱"
    textField.borderStyle = .roundedRect
    textField.keyboardType = .emailAddress
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no
    textField.translatesAutoresizingMaskIntoConstraints = false
    return textField
  }()
  
  private lazy var registerPasswordTextField: UITextField = {
    let textField = UITextField()
    textField.placeholder = "密码"
    textField.borderStyle = .roundedRect
    textField.isSecureTextEntry = true
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no
    textField.translatesAutoresizingMaskIntoConstraints = false
    return textField
  }()
  
  private lazy var confirmRegisterButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("注册", for: .normal)
    button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    button.backgroundColor = .systemGreen
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 8
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(confirmRegisterButtonTapped), for: .touchUpInside)
    return button
  }()
  
  private lazy var backToLoginButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("已有账号？返回登录", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(backToLoginButtonTapped), for: .touchUpInside)
    return button
  }()
  
  // MARK: - User Info Views
  
  private lazy var userInfoContainerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isHidden = true
    return view
  }()
  
  private lazy var userInfoTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "个人信息"
    label.font = UIFont.boldSystemFont(ofSize: 24)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  private lazy var usernameInfoLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 18)
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  private lazy var emailInfoLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 16)
    label.textColor = .secondaryLabel
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()
  
  // MARK: - Loading and Error Views
  
  private lazy var loadingIndicator: UIActivityIndicatorView = {
    let indicator = UIActivityIndicatorView(style: .medium)
    indicator.translatesAutoresizingMaskIntoConstraints = false
    indicator.hidesWhenStopped = true
    return indicator
  }()
  
  private lazy var errorLabel: UILabel = {
    let label = UILabel()
    label.textColor = .systemRed
    label.font = UIFont.systemFont(ofSize: 14)
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    label.isHidden = true
    return label
  }()
  
  // MARK: - Initialization
  
  public init(frame: CGRect = .zero, userProfileViewModel: UserProfileViewModel) {
    self.userProfileViewModel = userProfileViewModel
    super.init(frame: frame)
    
    setupViews()
    setupConstraints()
    bindViewModel()
  }
  
  // MARK: - Setup
  
  private func setupViews() {
    backgroundColor = .systemBackground
    
    addSubview(scrollView)
    scrollView.addSubview(contentView)
    
    // Add all container views
    contentView.addSubview(loginContainerView)
    contentView.addSubview(registerContainerView)
    contentView.addSubview(userInfoContainerView)
    contentView.addSubview(loadingIndicator)
    contentView.addSubview(errorLabel)
    
    setupLoginViews()
    setupRegisterViews()
    setupUserInfoViews()
  }
  
  private func setupLoginViews() {
    loginContainerView.addSubview(loginTitleLabel)
    loginContainerView.addSubview(usernameTextField)
    loginContainerView.addSubview(passwordTextField)
    loginContainerView.addSubview(loginButton)
    loginContainerView.addSubview(registerButton)
  }
  
  private func setupRegisterViews() {
    registerContainerView.addSubview(registerTitleLabel)
    registerContainerView.addSubview(registerUsernameTextField)
    registerContainerView.addSubview(registerEmailTextField)
    registerContainerView.addSubview(registerPasswordTextField)
    registerContainerView.addSubview(confirmRegisterButton)
    registerContainerView.addSubview(backToLoginButton)
  }
  
  private func setupUserInfoViews() {
    userInfoContainerView.addSubview(userInfoTitleLabel)
    userInfoContainerView.addSubview(usernameInfoLabel)
    userInfoContainerView.addSubview(emailInfoLabel)
  }
  
  private func setupConstraints() {
    NSLayoutConstraint.activate([
      // ScrollView constraints
      scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      // ContentView constraints
      contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      
      // Loading indicator
      loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      loadingIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 100),
      
      // Error label
      errorLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
      errorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
      errorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
    ])
    
    setupLoginConstraints()
    setupRegisterConstraints()
    setupUserInfoConstraints()
  }
  
  private func setupLoginConstraints() {
    NSLayoutConstraint.activate([
      // Login container
      loginContainerView.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
      loginContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
      loginContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
      loginContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
      
      // Login views
      loginTitleLabel.topAnchor.constraint(equalTo: loginContainerView.topAnchor, constant: 40),
      loginTitleLabel.leadingAnchor.constraint(equalTo: loginContainerView.leadingAnchor),
      loginTitleLabel.trailingAnchor.constraint(equalTo: loginContainerView.trailingAnchor),
      
      usernameTextField.topAnchor.constraint(equalTo: loginTitleLabel.bottomAnchor, constant: 40),
      usernameTextField.leadingAnchor.constraint(equalTo: loginContainerView.leadingAnchor),
      usernameTextField.trailingAnchor.constraint(equalTo: loginContainerView.trailingAnchor),
      usernameTextField.heightAnchor.constraint(equalToConstant: 44),
      
      passwordTextField.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 16),
      passwordTextField.leadingAnchor.constraint(equalTo: loginContainerView.leadingAnchor),
      passwordTextField.trailingAnchor.constraint(equalTo: loginContainerView.trailingAnchor),
      passwordTextField.heightAnchor.constraint(equalToConstant: 44),
      
      loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 32),
      loginButton.leadingAnchor.constraint(equalTo: loginContainerView.leadingAnchor),
      loginButton.trailingAnchor.constraint(equalTo: loginContainerView.trailingAnchor),
      loginButton.heightAnchor.constraint(equalToConstant: 50),
      
      registerButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 20),
      registerButton.centerXAnchor.constraint(equalTo: loginContainerView.centerXAnchor),
      registerButton.bottomAnchor.constraint(equalTo: loginContainerView.bottomAnchor),
    ])
  }
  
  private func setupRegisterConstraints() {
    NSLayoutConstraint.activate([
      // Register container
      registerContainerView.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
      registerContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
      registerContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
      registerContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
      
      // Register views
      registerTitleLabel.topAnchor.constraint(equalTo: registerContainerView.topAnchor, constant: 40),
      registerTitleLabel.leadingAnchor.constraint(equalTo: registerContainerView.leadingAnchor),
      registerTitleLabel.trailingAnchor.constraint(equalTo: registerContainerView.trailingAnchor),
      
      registerUsernameTextField.topAnchor.constraint(equalTo: registerTitleLabel.bottomAnchor, constant: 40),
      registerUsernameTextField.leadingAnchor.constraint(equalTo: registerContainerView.leadingAnchor),
      registerUsernameTextField.trailingAnchor.constraint(equalTo: registerContainerView.trailingAnchor),
      registerUsernameTextField.heightAnchor.constraint(equalToConstant: 44),
      
      registerEmailTextField.topAnchor.constraint(equalTo: registerUsernameTextField.bottomAnchor, constant: 16),
      registerEmailTextField.leadingAnchor.constraint(equalTo: registerContainerView.leadingAnchor),
      registerEmailTextField.trailingAnchor.constraint(equalTo: registerContainerView.trailingAnchor),
      registerEmailTextField.heightAnchor.constraint(equalToConstant: 44),
      
      registerPasswordTextField.topAnchor.constraint(equalTo: registerEmailTextField.bottomAnchor, constant: 16),
      registerPasswordTextField.leadingAnchor.constraint(equalTo: registerContainerView.leadingAnchor),
      registerPasswordTextField.trailingAnchor.constraint(equalTo: registerContainerView.trailingAnchor),
      registerPasswordTextField.heightAnchor.constraint(equalToConstant: 44),
      
      confirmRegisterButton.topAnchor.constraint(equalTo: registerPasswordTextField.bottomAnchor, constant: 32),
      confirmRegisterButton.leadingAnchor.constraint(equalTo: registerContainerView.leadingAnchor),
      confirmRegisterButton.trailingAnchor.constraint(equalTo: registerContainerView.trailingAnchor),
      confirmRegisterButton.heightAnchor.constraint(equalToConstant: 50),
      
      backToLoginButton.topAnchor.constraint(equalTo: confirmRegisterButton.bottomAnchor, constant: 20),
      backToLoginButton.centerXAnchor.constraint(equalTo: registerContainerView.centerXAnchor),
      backToLoginButton.bottomAnchor.constraint(equalTo: registerContainerView.bottomAnchor),
    ])
  }
  
  private func setupUserInfoConstraints() {
    NSLayoutConstraint.activate([
      // User info container
      userInfoContainerView.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
      userInfoContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
      userInfoContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
      userInfoContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
      
      // User info views
      userInfoTitleLabel.topAnchor.constraint(equalTo: userInfoContainerView.topAnchor, constant: 40),
      userInfoTitleLabel.leadingAnchor.constraint(equalTo: userInfoContainerView.leadingAnchor),
      userInfoTitleLabel.trailingAnchor.constraint(equalTo: userInfoContainerView.trailingAnchor),
      
      usernameInfoLabel.topAnchor.constraint(equalTo: userInfoTitleLabel.bottomAnchor, constant: 40),
      usernameInfoLabel.leadingAnchor.constraint(equalTo: userInfoContainerView.leadingAnchor),
      usernameInfoLabel.trailingAnchor.constraint(equalTo: userInfoContainerView.trailingAnchor),
      
      emailInfoLabel.topAnchor.constraint(equalTo: usernameInfoLabel.bottomAnchor, constant: 16),
      emailInfoLabel.leadingAnchor.constraint(equalTo: userInfoContainerView.leadingAnchor),
      emailInfoLabel.trailingAnchor.constraint(equalTo: userInfoContainerView.trailingAnchor),
      emailInfoLabel.bottomAnchor.constraint(lessThanOrEqualTo: userInfoContainerView.bottomAnchor),
    ])
  }
  
  // MARK: - ViewModel Binding
  
  private func bindViewModel() {
    // Bind text fields
    usernameTextField.addTarget(self, action: #selector(usernameChanged), for: .editingChanged)
    passwordTextField.addTarget(self, action: #selector(passwordChanged), for: .editingChanged)
    registerUsernameTextField.addTarget(self, action: #selector(registerUsernameChanged), for: .editingChanged)
    registerEmailTextField.addTarget(self, action: #selector(registerEmailChanged), for: .editingChanged)
    registerPasswordTextField.addTarget(self, action: #selector(registerPasswordChanged), for: .editingChanged)
    
    // Observe ViewModel changes
    userProfileViewModel.$currentUser
      .receive(on: DispatchQueue.main)
      .sink { [weak self] user in
        self?.updateUI(for: user)
      }
      .store(in: &subscriptions)
    
    userProfileViewModel.$showRegisterView
      .receive(on: DispatchQueue.main)
      .sink { [weak self] showRegister in
        self?.updateViewVisibility(showRegister: showRegister)
      }
      .store(in: &subscriptions)
    
    userProfileViewModel.$isLoading
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isLoading in
        if isLoading {
          self?.loadingIndicator.startAnimating()
        } else {
          self?.loadingIndicator.stopAnimating()
        }
        self?.setButtonsEnabled(!isLoading)
      }
      .store(in: &subscriptions)
    
    userProfileViewModel.$errorMessage
      .receive(on: DispatchQueue.main)
      .sink { [weak self] errorMessage in
        self?.updateErrorDisplay(errorMessage)
      }
      .store(in: &subscriptions)
  }
  
  // MARK: - UI Updates
  
  private func updateUI(for user: User?) {
    if let user = user {
      // Show user info
      usernameInfoLabel.text = "用户名: \(user.username)"
      emailInfoLabel.text = "邮箱: \(user.email ?? "未设置")"
      
      loginContainerView.isHidden = true
      registerContainerView.isHidden = true
      userInfoContainerView.isHidden = false
    } else {
      // Show login form
      userInfoContainerView.isHidden = true
      updateViewVisibility(showRegister: userProfileViewModel.showRegisterView)
    }
  }
  
  private func updateViewVisibility(showRegister: Bool) {
    if userProfileViewModel.currentUser == nil {
      loginContainerView.isHidden = showRegister
      registerContainerView.isHidden = !showRegister
    }
  }
  
  private func updateErrorDisplay(_ errorMessage: String?) {
    if let errorMessage = errorMessage {
      errorLabel.text = errorMessage
      errorLabel.isHidden = false
    } else {
      errorLabel.isHidden = true
    }
  }
  
  private func setButtonsEnabled(_ enabled: Bool) {
    loginButton.isEnabled = enabled
    confirmRegisterButton.isEnabled = enabled
    registerButton.isEnabled = enabled
    backToLoginButton.isEnabled = enabled
  }
  
  // MARK: - Actions
  
  @objc private func loginButtonTapped() {
    Task {
      await userProfileViewModel.login()
    }
  }
  
  @objc private func registerButtonTapped() {
    userProfileViewModel.showRegister()
  }
  
  @objc private func confirmRegisterButtonTapped() {
    Task {
      await userProfileViewModel.register()
    }
  }
  
  @objc private func backToLoginButtonTapped() {
    userProfileViewModel.showLogin()
  }
  
  // MARK: - Text Field Actions
  
  @objc private func usernameChanged() {
    userProfileViewModel.loginUsername = usernameTextField.text ?? ""
  }
  
  @objc private func passwordChanged() {
    userProfileViewModel.loginPassword = passwordTextField.text ?? ""
  }
  
  @objc private func registerUsernameChanged() {
    userProfileViewModel.registerUsername = registerUsernameTextField.text ?? ""
  }
  
  @objc private func registerEmailChanged() {
    userProfileViewModel.registerEmail = registerEmailTextField.text ?? ""
  }
  
  @objc private func registerPasswordChanged() {
    userProfileViewModel.registerPassword = registerPasswordTextField.text ?? ""
  }
}