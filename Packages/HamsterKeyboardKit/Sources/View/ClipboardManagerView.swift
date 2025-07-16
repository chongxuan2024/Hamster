//
//  ClipboardManagerView.swift
//
//
//  Created by AI on 2024/1/1.
//

import Combine
import HamsterKit
import HamsterUIKit
import UIKit

/**
 剪贴板管理视图
 */
class ClipboardManagerView: NibLessView {
  private let appearance: KeyboardAppearance
  private let actionHandler: KeyboardActionHandler
  private let keyboardContext: KeyboardContext
  private var style: CandidateBarStyle
  private var subscriptions = Set<AnyCancellable>()
  
  // 模拟剪贴板数据
  private var clipboardItems: [String] = [
    "Hello World",
    "Swift 编程语言",
    "iOS 开发",
    "仓输入法",
    "https://github.com/imfuxiao/Hamster",
    "这是一个很长的文本内容，用来测试剪贴板管理功能的显示效果。"
  ]

  /// 标题标签
  lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "剪贴板"
    label.font = .systemFont(ofSize: 16, weight: .medium)
    label.textAlignment = .center
    return label
  }()

  /// 关闭按钮
  lazy var closeButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 20), scale: .default), forImageIn: .normal)
    button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
    return button
  }()

  /// 清空按钮
  lazy var clearButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "trash"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 18), scale: .default), forImageIn: .normal)
    button.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
    return button
  }()

  /// 顶部容器
  lazy var headerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  /// 集合视图
  lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    layout.minimumLineSpacing = 8
    layout.minimumInteritemSpacing = 8
    layout.sectionInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    
    let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
    cv.translatesAutoresizingMaskIntoConstraints = false
    cv.delegate = self
    cv.dataSource = self
    cv.register(ClipboardItemCell.self, forCellWithReuseIdentifier: "ClipboardItemCell")
    cv.showsVerticalScrollIndicator = true
    return cv
  }()

  init(appearance: KeyboardAppearance, actionHandler: KeyboardActionHandler, keyboardContext: KeyboardContext) {
    self.appearance = appearance
    self.actionHandler = actionHandler
    self.keyboardContext = keyboardContext
    self.style = appearance.candidateBarStyle

    super.init(frame: .zero)

    setupSubview()
  }

  func setupSubview() {
    constructViewHierarchy()
    activateViewConstraints()
    setupAppearance()
  }

  override func constructViewHierarchy() {
    addSubview(headerView)
    addSubview(collectionView)
    
    headerView.addSubview(titleLabel)
    headerView.addSubview(closeButton)
    headerView.addSubview(clearButton)
  }

  override func activateViewConstraints() {
    NSLayoutConstraint.activate([
      // 头部视图约束
      headerView.topAnchor.constraint(equalTo: topAnchor),
      headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
      headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
      headerView.heightAnchor.constraint(equalToConstant: 44),
      
      // 标题标签约束
      titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
      titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
      
      // 关闭按钮约束
      closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
      closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
      closeButton.widthAnchor.constraint(equalToConstant: 28),
      closeButton.heightAnchor.constraint(equalToConstant: 28),
      
      // 清空按钮约束
      clearButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
      clearButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
      clearButton.widthAnchor.constraint(equalToConstant: 28),
      clearButton.heightAnchor.constraint(equalToConstant: 28),
      
      // 集合视图约束
      collectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
      collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  override func setupAppearance() {
    backgroundColor = style.backgroundColor
    
    titleLabel.textColor = style.textColor
    closeButton.tintColor = style.toolbarButtonFrontColor
    clearButton.tintColor = style.toolbarButtonFrontColor
    collectionView.backgroundColor = style.backgroundColor
  }

  @objc private func closeButtonTapped() {
    actionHandler.handle(.release, on: .custom(named: "hideClipboard"))
  }

  @objc private func clearButtonTapped() {
    clipboardItems.removeAll()
    collectionView.reloadData()
  }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegate

extension ClipboardManagerView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return clipboardItems.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ClipboardItemCell", for: indexPath) as! ClipboardItemCell
    cell.configure(with: clipboardItems[indexPath.item], style: style)
    return cell
  }

  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let padding: CGFloat = 24 // 左右各12的padding
    let availableWidth = collectionView.frame.width - padding
    let cellWidth = (availableWidth - 8) / 2 // 8是间距
    return CGSize(width: cellWidth, height: 60)
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let text = clipboardItems[indexPath.item]
    actionHandler.handle(.release, on: .character(text))
    actionHandler.handle(.release, on: .custom(named: "hideClipboard"))
  }
}

// MARK: - ClipboardItemCell

class ClipboardItemCell: UICollectionViewCell {
  lazy var textLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 14)
    label.numberOfLines = 2
    label.textAlignment = .left
    return label
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupCell()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupCell() {
    contentView.addSubview(textLabel)
    contentView.layer.cornerRadius = 8
    contentView.layer.borderWidth = 1

    NSLayoutConstraint.activate([
      textLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
      textLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
      textLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
      textLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
    ])
  }

  func configure(with text: String, style: CandidateBarStyle) {
    textLabel.text = text
    textLabel.textColor = style.textColor
    contentView.backgroundColor = style.toolbarButtonBackgroundColor
    contentView.layer.borderColor = style.toolbarButtonFrontColor.withAlphaComponent(0.3).cgColor
  }
}