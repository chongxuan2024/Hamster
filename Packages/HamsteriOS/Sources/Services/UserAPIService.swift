//
//  UserAPIService.swift
//  Hamster
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import OSLog

/// 用户API服务，负责用户登录和注册的网络请求
public class UserAPIService {
  public static let shared = UserAPIService()
  
  private let baseURL = "https://www.idlab.top/userapi/user"
  private let session: URLSession
  
  private init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 60
    self.session = URLSession(configuration: config)
  }
  
  /// 用户登录
  public func login(username: String, password: String) async throws -> User {
    let loginRequest = LoginRequest(username: username, password: password)
    let url = URL(string: "\(baseURL)/login")!
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
      let jsonData = try JSONEncoder().encode(loginRequest)
      request.httpBody = jsonData
      
      Logger.statistics.debug("UserAPIService: 开始登录请求 - 用户名: \(username)")
      
      let (data, response) = try await session.data(for: request)
      
      guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
      }
      
      Logger.statistics.debug("UserAPIService: 登录响应状态码: \(httpResponse.statusCode)")
      
      if httpResponse.statusCode == 200 {
        // 成功响应
        let user = try JSONDecoder().decode(User.self, from: data)
        Logger.statistics.info("UserAPIService: 登录成功 - 用户: \(user.username)")
        return user
      } else {
        // 错误响应
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
          Logger.statistics.error("UserAPIService: 登录失败 - \(errorResponse.error)")
          throw APIError.serverError(errorResponse.error)
        } else {
          throw APIError.unknownError
        }
      }
    } catch let error as APIError {
      throw error
    } catch {
      Logger.statistics.error("UserAPIService: 登录网络错误 - \(error.localizedDescription)")
      throw APIError.networkError(error.localizedDescription)
    }
  }
  
  /// 用户注册
  public func register(username: String, email: String, password: String) async throws {
    let registerRequest = RegisterRequest(username: username, email: email, password: password)
    let url = URL(string: "\(baseURL)/register")!
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
      let jsonData = try JSONEncoder().encode(registerRequest)
      request.httpBody = jsonData
      
      Logger.statistics.debug("UserAPIService: 开始注册请求 - 用户名: \(username)")
      
      let (data, response) = try await session.data(for: request)
      
      guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
      }
      
      Logger.statistics.debug("UserAPIService: 注册响应状态码: \(httpResponse.statusCode)")
      
      if httpResponse.statusCode == 200 {
        Logger.statistics.info("UserAPIService: 注册成功 - 用户: \(username)")
      } else {
        // 错误响应
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
          Logger.statistics.error("UserAPIService: 注册失败 - \(errorResponse.error)")
          throw APIError.serverError(errorResponse.error)
        } else {
          throw APIError.unknownError
        }
      }
    } catch let error as APIError {
      throw error
    } catch {
      Logger.statistics.error("UserAPIService: 注册网络错误 - \(error.localizedDescription)")
      throw APIError.networkError(error.localizedDescription)
    }
  }
}

/// API错误类型
public enum APIError: Error, LocalizedError {
  case networkError(String)
  case invalidResponse
  case serverError(String)
  case unknownError
  
  public var errorDescription: String? {
    switch self {
    case .networkError(let message):
      return "网络错误: \(message)"
    case .invalidResponse:
      return "无效的响应"
    case .serverError(let message):
      return message
    case .unknownError:
      return "未知错误"
    }
  }
}

/// 错误响应模型
private struct ErrorResponse: Codable {
  let error: String
}