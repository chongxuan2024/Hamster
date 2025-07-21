//
//  UserManager.swift
//  Hamster
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import HamsterKit
import OSLog

/// 用户管理器，负责用户登录状态和数据的管理
/// 采用单例模式，确保全局只有一个用户管理实例
/// 使用 ObservableObject 协议支持 SwiftUI 响应式更新
/// 
/// 该类负责：
/// 1. 管理用户登录状态和用户信息
/// 2. 将用户信息同步保存到标准 UserDefaults 和 AppGroup 共享存储
/// 3. 确保键盘扩展能够通过 AppGroup 访问用户登录状态
public class UserManager: ObservableObject {
  /// 用户管理器单例实例
  public static let shared = UserManager()
  
  /// 标准 UserDefaults 存储键值（主应用使用）
  private let userDefaultsKey = "hamster_current_user"
  
  /// AppGroup 共享存储键值（键盘扩展使用）
  private let sharedUserDefaultsKey = "hamster_shared_current_user"
  
  /// AppGroup 共享的 UserDefaults，使用 HamsterConstants 中定义的 appGroupName
  /// 当前 AppGroup: group.dev2.fuxiao.app.Hamster2
  private let sharedDefaults: UserDefaults
  
  /// 当前登录用户
  /// 使用 @Published 属性包装器，当用户状态改变时自动通知 UI 更新
  @Published public private(set) var currentUser: User?
  
  /// 是否已登录
  /// 通过检查 currentUser 是否为 nil 来判断登录状态
  public var isLoggedIn: Bool {
    return currentUser != nil
  }
  
  /// 私有初始化方法，确保单例模式
  /// 在初始化时自动加载本地存储的用户信息
  private init() {
    // 初始化 AppGroup 共享存储，使用 HamsterConstants 中定义的 appGroupName
    guard let sharedUserDefaults = UserDefaults(suiteName: HamsterConstants.appGroupName) else {
      fatalError("UserManager: 无法初始化 AppGroup 共享存储，AppGroup 名称: \(HamsterConstants.appGroupName)")
    }
    self.sharedDefaults = sharedUserDefaults
    
    Logger.statistics.info("UserManager: 初始化用户管理器，AppGroup: \(HamsterConstants.appGroupName)")
    loadUser()
  }
  
  /// 保存用户信息到本地存储和 AppGroup 共享存储
  /// - Parameter user: 要保存的用户信息
  /// 
  /// 该方法会同时更新：
  /// 1. 内存中的 currentUser（触发 UI 更新）
  /// 2. 标准 UserDefaults（主应用使用）
  /// 3. AppGroup 共享存储（键盘扩展使用）
  public func saveUser(_ user: User) {
    Logger.statistics.info("UserManager: 开始保存用户信息 - 用户名: \(user.username), Token长度: \(user.token.count)")
    
    // 更新内存中的用户信息，触发 @Published 属性的观察者
    currentUser = user
    
    do {
      // 将用户信息编码为 JSON 数据
      let userData = try JSONEncoder().encode(user)
      
      // 保存到标准 UserDefaults（主应用使用）
      UserDefaults.standard.set(userData, forKey: userDefaultsKey)
      Logger.statistics.debug("UserManager: 用户信息已保存到标准 UserDefaults")
      
      // 同步保存到 AppGroup 共享存储（键盘扩展使用）
      sharedDefaults.set(userData, forKey: sharedUserDefaultsKey)
      Logger.statistics.debug("UserManager: 用户信息已保存到 AppGroup 共享存储: \(HamsterConstants.appGroupName)")
      
      // 确保数据立即同步到磁盘
      UserDefaults.standard.synchronize()
      sharedDefaults.synchronize()
      
      Logger.statistics.info("UserManager: 用户信息已成功保存到本地存储和AppGroup共享存储 - 用户名: \(user.username)")
    } catch {
      Logger.statistics.error("UserManager: 保存用户信息失败 - 错误: \(error.localizedDescription)")
    }
  }
  
  /// 从本地存储加载用户信息
  /// 该方法在初始化时自动调用，用于恢复上次登录的用户状态
  /// 
  /// 加载优先级：
  /// 1. 优先从标准 UserDefaults 加载
  /// 2. 如果标准存储为空，尝试从 AppGroup 共享存储加载
  /// 3. 加载成功后，确保两个存储都有数据
  private func loadUser() {
    Logger.statistics.debug("UserManager: 开始从本地存储加载用户信息")
    
    var userData: Data?
    var loadSource = ""
    
    // 优先从标准 UserDefaults 获取用户数据
    if let standardUserData = UserDefaults.standard.data(forKey: userDefaultsKey) {
      userData = standardUserData
      loadSource = "标准 UserDefaults"
      Logger.statistics.debug("UserManager: 从标准 UserDefaults 获取到用户数据")
    } else if let sharedUserData = sharedDefaults.data(forKey: sharedUserDefaultsKey) {
      userData = sharedUserData
      loadSource = "AppGroup 共享存储"
      Logger.statistics.debug("UserManager: 从 AppGroup 共享存储获取到用户数据")
    }
    
    guard let userData = userData else {
      Logger.statistics.info("UserManager: 本地存储和 AppGroup 共享存储中都没有用户信息，用户未登录")
      return
    }
    
    do {
      // 解码用户数据
      let decodedUser = try JSONDecoder().decode(User.self, from: userData)
      self.currentUser = decodedUser
      
      // 确保 AppGroup 共享存储中也有用户信息
      syncUserToSharedStorage(decodedUser)
      
      Logger.statistics.info("UserManager: 成功从\(loadSource)加载用户信息 - 用户名: \(decodedUser.username), Token长度: \(decodedUser.token.count)")
    } catch {
      Logger.statistics.error("UserManager: 加载用户信息失败 - 错误: \(error.localizedDescription)")
      // 如果解析失败，清除损坏的数据，避免后续问题
      UserDefaults.standard.removeObject(forKey: userDefaultsKey)
      sharedDefaults.removeObject(forKey: sharedUserDefaultsKey)
      Logger.statistics.warning("UserManager: 已清除损坏的用户数据")
    }
  }
  
  /// 同步用户信息到AppGroup共享存储
  /// - Parameter user: 要同步的用户信息
  /// 
  /// 该方法确保键盘扩展能够访问到最新的用户信息
  private func syncUserToSharedStorage(_ user: User) {
    do {
      let userData = try JSONEncoder().encode(user)
      sharedDefaults.set(userData, forKey: sharedUserDefaultsKey)
      sharedDefaults.synchronize()
      Logger.statistics.debug("UserManager: 用户信息已同步到 AppGroup 共享存储: \(HamsterConstants.appGroupName)")
    } catch {
      Logger.statistics.error("UserManager: 同步用户信息到 AppGroup 共享存储失败 - 错误: \(error.localizedDescription)")
    }
  }
  
  /// 用户登出操作
  /// 清除内存和本地存储中的用户信息
  /// 
  /// 该方法会清除：
  /// 1. 内存中的用户信息
  /// 2. 标准 UserDefaults 中的用户信息
  /// 3. AppGroup 共享存储中的用户信息
  public func logout() {
    Logger.statistics.debug("UserManager: 开始执行用户登出操作")
    
    let logoutUsername = currentUser?.username ?? "unknown"
    
    // 清除内存中的用户信息
    currentUser = nil
    
    // 清除标准 UserDefaults 中的用户信息
    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    UserDefaults.standard.synchronize()
    
    // 清除 AppGroup 共享存储中的用户信息
    sharedDefaults.removeObject(forKey: sharedUserDefaultsKey)
    sharedDefaults.synchronize()
    
    Logger.statistics.info("UserManager: 用户已成功登出，已清除本地存储和 AppGroup 共享存储 - 原用户名: \(logoutUsername)")
  }
  
  /// 更新用户信息
  /// - Parameter user: 新的用户信息
  /// 该方法实际上调用 saveUser 方法来更新用户信息
  public func updateUser(_ user: User) {
    Logger.statistics.debug("UserManager: 开始更新用户信息 - 用户名: \(user.username)")
    saveUser(user)
    Logger.statistics.info("UserManager: 用户信息更新完成 - 用户名: \(user.username)")
  }
}