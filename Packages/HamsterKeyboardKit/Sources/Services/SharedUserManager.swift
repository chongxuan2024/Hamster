//
//  SharedUserManager.swift
//  HamsterKeyboardKit
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import HamsterKit
import OSLog

/// 跨 target 共享用户管理器
/// 用于在主应用和键盘扩展之间共享用户登录状态和数据
/// 使用 AppGroup 共享存储来实现跨 target 数据共享
/// 
/// 该类的主要职责：
/// 1. 从 AppGroup 共享存储中读取主应用保存的用户信息
/// 2. 提供键盘扩展所需的用户登录状态检查
/// 3. 确保键盘扩展能够获取到用户的认证 token
/// 
/// 注意：该类只负责读取用户信息，不负责写入。
/// 用户信息的写入由主应用的 UserManager 负责。
public class SharedUserManager {
  /// 单例实例
  public static let shared = SharedUserManager()
  
  /// AppGroup 共享的 UserDefaults
  /// 使用 HamsterConstants.appGroupName（当前值：group.dev2.fuxiao.app.Hamster2）
  private let sharedDefaults = UserDefaults.hamster
  
  /// UserDefaults 存储键值（与 UserManager 保持一致）
  private let userDefaultsKey = "hamster_shared_current_user"
  
  /// 私有初始化方法，确保单例模式
  private init() {
    Logger.statistics.info("SharedUserManager: 初始化跨target用户管理器，AppGroup: \(HamsterConstants.appGroupName)")
  }
  
  /// 获取当前登录用户
  /// 从 AppGroup 共享存储中读取主应用保存的用户信息
  /// - Returns: 当前登录的用户信息，如果未登录则返回 nil
  public var currentUser: User? {
    Logger.statistics.debug("SharedUserManager: 开始从 AppGroup 共享存储获取当前登录用户")
    
    guard let userData = sharedDefaults.data(forKey: userDefaultsKey) else {
      Logger.statistics.debug("SharedUserManager: AppGroup 共享存储中没有用户信息，用户未登录")
      return nil
    }
    
    do {
      let decodedUser = try JSONDecoder().decode(User.self, from: userData)
      Logger.statistics.info("SharedUserManager: 成功从 AppGroup 共享存储加载用户信息 - 用户名: \(decodedUser.username), Token长度: \(decodedUser.token.count)")
      return decodedUser
    } catch {
      Logger.statistics.error("SharedUserManager: 解析 AppGroup 共享存储中的用户信息失败 - 错误: \(error.localizedDescription)")
      // 如果解析失败，清除损坏的数据
      sharedDefaults.removeObject(forKey: userDefaultsKey)
      Logger.statistics.warning("SharedUserManager: 已清除 AppGroup 共享存储中的损坏用户数据")
      return nil
    }
  }
  
  /// 是否已登录
  /// 通过检查 currentUser 是否为 nil 来判断登录状态
  /// - Returns: true 表示已登录，false 表示未登录
  public var isLoggedIn: Bool {
    let loggedIn = currentUser != nil
    Logger.statistics.debug("SharedUserManager: 检查登录状态 - \(loggedIn ? "已登录" : "未登录")")
    return loggedIn
  }
  
  /// 保存用户信息到AppGroup共享存储
  /// - Parameter user: 要保存的用户信息
  /// 
  /// 注意：该方法主要用于测试和特殊情况，正常情况下用户信息由主应用的 UserManager 保存
  public func saveUser(_ user: User) {
    Logger.statistics.info("SharedUserManager: 开始保存用户信息到 AppGroup 共享存储 - 用户名: \(user.username), Token长度: \(user.token.count)")
    
    do {
      let userData = try JSONEncoder().encode(user)
      sharedDefaults.set(userData, forKey: userDefaultsKey)
      sharedDefaults.synchronize() // 确保立即同步到磁盘
      Logger.statistics.info("SharedUserManager: 用户信息已成功保存到 AppGroup 共享存储 - 用户名: \(user.username)")
    } catch {
      Logger.statistics.error("SharedUserManager: 保存用户信息到 AppGroup 共享存储失败 - 错误: \(error.localizedDescription)")
    }
  }
  
  /// 用户登出操作
  /// 清除AppGroup共享存储中的用户信息
  /// 
  /// 注意：该方法主要用于测试和特殊情况，正常情况下登出操作由主应用的 UserManager 处理
  public func logout() {
    Logger.statistics.debug("SharedUserManager: 开始执行用户登出操作")
    
    let logoutUsername = currentUser?.username ?? "unknown"
    sharedDefaults.removeObject(forKey: userDefaultsKey)
    sharedDefaults.synchronize() // 确保立即同步到磁盘
    
    Logger.statistics.info("SharedUserManager: 用户已成功从 AppGroup 共享存储登出 - 原用户名: \(logoutUsername)")
  }
  
  /// 更新用户信息
  /// - Parameter user: 新的用户信息
  /// 
  /// 注意：该方法主要用于测试和特殊情况，正常情况下用户信息更新由主应用的 UserManager 处理
  public func updateUser(_ user: User) {
    Logger.statistics.debug("SharedUserManager: 开始更新 AppGroup 共享用户信息 - 用户名: \(user.username)")
    saveUser(user)
    Logger.statistics.info("SharedUserManager: AppGroup 共享用户信息更新完成 - 用户名: \(user.username)")
  }
}

/// 用户数据模型（键盘扩展版本）
public struct User: Codable {
  /// 用户名
  public let username: String
  
  /// 邮箱
  public let email: String?
  
  /// 认证令牌
  public let token: String
  
  public init(username: String, email: String? = nil, token: String) {
    self.username = username
    self.email = email
    self.token = token
  }
}
