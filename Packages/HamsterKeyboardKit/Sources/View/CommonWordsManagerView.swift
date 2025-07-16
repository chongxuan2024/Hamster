//
//  CommonWordsManagerView.swift
//
//
//  Created by AI on 2024/1/1.
//

import Combine
import HamsterKit
import HamsterUIKit
import UIKit

/**
 常用词汇管理视图
 */
class CommonWordsManagerView: NibLessView {
  private let appearance: KeyboardAppearance
  private let actionHandler: KeyboardActionHandler
  private let keyboardContext: KeyboardContext
  private var style: CandidateBarStyle
  private var subscriptions = Set<AnyCancellable>()
  
  // 常用词汇数据
  private var commonWords: [CommonWordCategory] = [
    CommonWordCategory(title: "问候语", words: ["你好", "早上好", "晚上好", "谢谢", "不客气", "对不起"]),
    CommonWordCategory(title: "日常用语", words: ["没问题", "好的", "知道了", "稍等", "马上来", "辛苦了"]),
    CommonWordCategory(title: "表情符号", words: ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇"]),
    CommonWordCategory(title: "常用短语", words: ["收到", "了解", "明白", "好的，谢谢", "没关系", "加油"])
  ]

  /// 标题标签
  lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "常用词汇"
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

  /// 添加按钮
  lazy var addButton: UIButton = {
    let button = UIButton(type: .custom)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(systemName: "plus.circle"), for: .normal)
    button.setPreferredSymbolConfiguration(.init(font: .systemFont(ofSize: 18), scale: .default), forImageIn: .normal)
    button.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
    return button
  }()

  /// 顶部容器
  lazy var headerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  /// 表格视图
  lazy var tableView: UITableView = {
    let tv = UITableView(frame: .zero, style: .grouped)
    tv.translatesAutoresizingMaskIntoConstraints = false
    tv.delegate = self
    tv.dataSource = self
    tv.register(CommonWordCell.self, forCellReuseIdentifier: "CommonWordCell")
    tv.showsVerticalScrollIndicator = true
    tv.separatorStyle = .none
    return tv
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
    addSubview(tableView)
    
    headerView.addSubview(titleLabel)
    headerView.addSubview(closeButton)
    headerView.addSubview(addButton)
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
      
      // 添加按钮约束
      addButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
      addButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
      addButton.widthAnchor.constraint(equalToConstant: 28),
      addButton.heightAnchor.constraint(equalToConstant: 28),
      
      // 表格视图约束
      tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
      tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  override func setupAppearance() {
    backgroundColor = style.backgroundColor
    
    titleLabel.textColor = style.textColor
    closeButton.tintColor = style.toolbarButtonFrontColor
    addButton.tintColor = style.toolbarButtonFrontColor
    tableView.backgroundColor = style.backgroundColor
  }

  @objc private func closeButtonTapped() {
    actionHandler.handle(.release, on: .custom(named: "hideCommonWords"))
  }

  @objc private func addButtonTapped() {
    // 这里可以添加新词汇的功能
    print("添加新词汇")
  }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension CommonWordsManagerView: UITableViewDataSource, UITableViewDelegate {
  func numberOfSections(in tableView: UITableView) -> Int {
    return commonWords.count
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return commonWords[section].words.count
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return commonWords[section].title
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CommonWordCell", for: indexPath) as! CommonWordCell
    let word = commonWords[indexPath.section].words[indexPath.row]
    cell.configure(with: word, style: style)
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let word = commonWords[indexPath.section].words[indexPath.row]
    actionHandler.handle(.release, on: .character(word))
    actionHandler.handle(.release, on: .custom(named: "hideCommonWords"))
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 44
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 32
  }
  
  func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    if let headerView = view as? UITableViewHeaderFooterView {
      headerView.textLabel?.textColor = style.textColor
      headerView.textLabel?.font = .systemFont(ofSize: 14, weight: .medium)
      headerView.backgroundView?.backgroundColor = style.backgroundColor
    }
  }
}

// MARK: - CommonWordCategory

struct CommonWordCategory {
  let title: String
  let words: [String]
}

// MARK: - CommonWordCell

class CommonWordCell: UITableViewCell {
  lazy var wordLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 16)
    return label
  }()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupCell()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupCell() {
    contentView.addSubview(wordLabel)
    
    NSLayoutConstraint.activate([
      wordLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      wordLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      wordLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
    ])
  }

  func configure(with word: String, style: CandidateBarStyle) {
    wordLabel.text = word
    wordLabel.textColor = style.textColor
    backgroundColor = style.backgroundColor
    
    // 添加选中效果
    let selectedBackgroundView = UIView()
    selectedBackgroundView.backgroundColor = style.toolbarButtonBackgroundColor
    self.selectedBackgroundView = selectedBackgroundView
  }
}