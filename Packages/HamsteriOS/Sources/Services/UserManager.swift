//
//  UserManager.swift
//  Hamster
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import OSLog

/// 用户管理器，负责用户登录状态和数据的管理
/// 采用单例模式，确保全局只有一个用户管理实例
/// 使用 ObservableObject 协议支持 SwiftUI 响应式更新
public class UserManager: ObservableObject {
  /// 用户管理器单例实例
  public static let shared = UserManager()
  
  /// UserDefaults 存储键值
  private let userDefaultsKey = "hamster_current_user"
  
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
    Logger.statistics.debug("UserManager: 初始化用户管理器")
    loadUser()
  }
  
  /// 保存用户信息到本地存储
  /// - Parameter user: 要保存的用户信息
  /// 该方法会同时更新内存中的 currentUser 和 UserDefaults 中的持久化数据
  public func saveUser(_ user: User) {
    Logger.statistics.debug("UserManager: 开始保存用户信息 - 用户名: \(user.username)")
    
    // 更新内存中的用户信息，触发 @Published 属性的观察者
    currentUser = user
    
    do {
      // 将用户信息编码为 JSON 数据
      let userData = try JSONEncoder().encode(user)
      // 保存到 UserDefaults
      UserDefaults.standard.set(userData, forKey: userDefaultsKey)
      Logger.statistics.info("UserManager: 用户信息已成功保存到本地存储 - 用户名: \(user.username)")
    } catch {
      Logger.statistics.error("UserManager: 保存用户信息失败 - 错误: \(error.localizedDescription)")
    }
  }
  
  /// 从本地存储加载用户信息
  /// 该方法在初始化时自动调用，用于恢复上次登录的用户状态
  private func loadUser() {
    Logger.statistics.debug("UserManager: 开始从本地存储加载用户信息")
    
    // 从 UserDefaults 获取用户数据
    guard let userData = UserDefaults.standard.data(forKey: userDefaultsKey) else {
      Logger.statistics.debug("UserManager: 本地存储中没有用户信息，用户未登录")
      return
    }
    
    do {
      // 解码用户数据
      let decodedUser = try JSONDecoder().decode(User.self, from: userData)
      self.currentUser = decodedUser
      
      Logger.statistics.info("UserManager: 成功从本地存储加载用户信息 - 用户名: \(self.currentUser?.username ?? "unknown")")
    } catch {
      Logger.statistics.error("UserManager: 加载用户信息失败 - 错误: \(error.localizedDescription)")
      // 如果解析失败，清除损坏的数据，避免后续问题
      UserDefaults.standard.removeObject(forKey: userDefaultsKey)
      Logger.statistics.warning("UserManager: 已清除损坏的用户数据")
    }
  }
  
  /// 用户登出操作
  /// 清除内存和本地存储中的用户信息
  public func logout() {
    Logger.statistics.debug("UserManager: 开始执行用户登出操作")
    
    let logoutUsername = currentUser?.username ?? "unknown"
    
    // 清除内存中的用户信息
    currentUser = nil
    // 清除本地存储中的用户信息
    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    
    Logger.statistics.info("UserManager: 用户已成功登出 - 原用户名: \(logoutUsername)")
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