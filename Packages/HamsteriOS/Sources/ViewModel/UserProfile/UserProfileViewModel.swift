//
//  UserProfileViewModel.swift
//  Hamster
//
//  Created by AI Assistant on 2024/12/19.
//

import Combine
import Foundation
import OSLog

/// 用户资料页面ViewModel
public class UserProfileViewModel: ObservableObject {
  /// 当前用户
  @Published public var currentUser: User?
  
  /// 是否显示登录页面
  @Published public var showLoginView: Bool = false
  
  /// 登录用户名
  @Published public var loginUsername: String = ""
  
  /// 登录密码
  @Published public var loginPassword: String = ""
  
  /// 注册用户名
  @Published public var registerUsername: String = ""
  
  /// 注册邮箱
  @Published public var registerEmail: String = ""
  
  /// 注册密码
  @Published public var registerPassword: String = ""
  
  /// 是否正在加载
  @Published public var isLoading: Bool = false
  
  /// 错误信息
  @Published public var errorMessage: String?
  
  /// 是否显示注册页面
  @Published public var showRegisterView: Bool = false
  
  private let userManager = UserManager.shared
  private let apiService = UserAPIService.shared
  private var cancellables = Set<AnyCancellable>()
  
  public init() {
    // 监听用户状态变化
    userManager.$currentUser
      .assign(to: \.currentUser, on: self)
      .store(in: &cancellables)
    
    // 初始化时检查登录状态
    updateLoginViewVisibility()
  }
  
  /// 更新登录页面显示状态
  private func updateLoginViewVisibility() {
    showLoginView = !userManager.isLoggedIn
  }
  
  /// 用户登录
  @MainActor
  public func login() async {
    guard !loginUsername.isEmpty && !loginPassword.isEmpty else {
      errorMessage = "用户名和密码不能为空"
      return
    }
    
    isLoading = true
    errorMessage = nil
    
    do {
      let user = try await apiService.login(username: loginUsername, password: loginPassword)
      userManager.saveUser(user)
      
      // 清空输入
      loginUsername = ""
      loginPassword = ""
      
      // 更新界面状态
      updateLoginViewVisibility()
      
      Logger.statistics.info("UserProfileViewModel: 用户登录成功")
    } catch {
      errorMessage = error.localizedDescription
      Logger.statistics.error("UserProfileViewModel: 用户登录失败 - \(error.localizedDescription)")
    }
    
    isLoading = false
  }
  
  /// 用户注册
  @MainActor
  public func register() async {
    guard !registerUsername.isEmpty && !registerEmail.isEmpty && !registerPassword.isEmpty else {
      errorMessage = "所有字段都不能为空"
      return
    }
    
    // 简单的邮箱格式验证
    if !isValidEmail(registerEmail) {
      errorMessage = "请输入有效的邮箱地址"
      return
    }
    
    isLoading = true
    errorMessage = nil
    
    do {
      try await apiService.register(username: registerUsername, email: registerEmail, password: registerPassword)
      
      // 注册成功后自动登录
      let user = try await apiService.login(username: registerUsername, password: registerPassword)
      userManager.saveUser(user)
      
      // 清空输入
      registerUsername = ""
      registerEmail = ""
      registerPassword = ""
      
      // 更新界面状态
      showRegisterView = false
      updateLoginViewVisibility()
      
      Logger.statistics.info("UserProfileViewModel: 用户注册并登录成功")
    } catch {
      errorMessage = error.localizedDescription
      Logger.statistics.error("UserProfileViewModel: 用户注册失败 - \(error.localizedDescription)")
    }
    
    isLoading = false
  }
  
  /// 用户登出
  public func logout() {
    userManager.logout()
    updateLoginViewVisibility()
    Logger.statistics.info("UserProfileViewModel: 用户已登出")
  }
  
  /// 显示注册页面
  public func showRegister() {
    showRegisterView = true
    errorMessage = nil
  }
  
  /// 显示登录页面
  public func showLogin() {
    showRegisterView = false
    errorMessage = nil
  }
  
  /// 清除错误信息
  public func clearError() {
    errorMessage = nil
  }
  
  /// 验证邮箱格式
  private func isValidEmail(_ email: String) -> Bool {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
    return emailPred.evaluate(with: email)
  }
}