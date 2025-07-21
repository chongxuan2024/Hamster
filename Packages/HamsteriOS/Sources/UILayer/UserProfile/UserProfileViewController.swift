//
//  UserProfileViewController.swift
//  Hamster
//
//  Created by AI Assistant on 2024/12/19.
//

import Combine
import HamsterUIKit
import UIKit

/// 用户资料页面控制器
public class UserProfileViewController: NibLessViewController {
  private let userProfileViewModel: UserProfileViewModel
  private var subscriptions = Set<AnyCancellable>()
  
  public init(userProfileViewModel: UserProfileViewModel) {
    self.userProfileViewModel = userProfileViewModel
    super.init()
  }
  
  public override func loadView() {
    title = "个人信息"
    view = UserProfileRootView(userProfileViewModel: userProfileViewModel)
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    setupNavigationBar()
  }
  
  private func setupNavigationBar() {
    // 如果用户已登录，显示登出按钮
    userProfileViewModel.$currentUser
      .receive(on: DispatchQueue.main)
      .sink { [weak self] user in
        if user != nil {
          self?.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "登出",
            style: .plain,
            target: self,
            action: #selector(self?.logoutTapped)
          )
        } else {
          self?.navigationItem.rightBarButtonItem = nil
        }
      }
      .store(in: &subscriptions)
  }
  
  @objc private func logoutTapped() {
    let alert = UIAlertController(
      title: "确认登出",
      message: "确定要登出当前账号吗？",
      preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "取消", style: .cancel))
    alert.addAction(UIAlertAction(title: "登出", style: .destructive) { [weak self] _ in
      self?.userProfileViewModel.logout()
    })
    
    present(alert, animated: true)
  }
}