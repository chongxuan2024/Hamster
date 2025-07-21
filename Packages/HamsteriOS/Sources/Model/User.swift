//
//  User.swift
//  Hamster
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation

/// 用户数据模型
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

/// 登录请求数据
public struct LoginRequest: Codable {
  public let username: String
  public let password: String
  
  public init(username: String, password: String) {
    self.username = username
    self.password = password
  }
}

/// 注册请求数据
public struct RegisterRequest: Codable {
  public let username: String
  public let email: String
  public let password: String
  
  public init(username: String, email: String, password: String) {
    self.username = username
    self.email = email
    self.password = password
  }
}

/// API响应数据
public struct APIResponse<T: Codable>: Codable {
  public let success: Bool
  public let data: T?
  public let error: String?
  
  public init(success: Bool, data: T? = nil, error: String? = nil) {
    self.success = success
    self.data = data
    self.error = error
  }
}