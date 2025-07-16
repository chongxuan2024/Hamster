//
//  KnowledgeBaseManagerView.swift
//
//
//  Created by AI on 2024/1/1.
//

import Combine
import HamsterKit
import HamsterUIKit
import UIKit

/**
 知识库管理视图
 */
class KnowledgeBaseManagerView: NibLessView {
  private let appearance: KeyboardAppearance
  private let actionHandler: KeyboardActionHandler
  private let keyboardContext: KeyboardContext
  private var style: CandidateBarStyle
  private var subscriptions = Set<AnyCancellable>()
  
  // 知识库数据
  private var knowledgeItems: [KnowledgeItem] = [
    KnowledgeItem(category: "技术", title: "Swift 语法", content: "Swift 是一种强类型、编译型编程语言"),
    KnowledgeItem(category: "技术", title: "iOS 开发", content: "iOS 应用开发使用 Xcode 和 Swift"),
    KnowledgeItem(category: "工作", title: "会议纪要", content: "今日会议要点：1. 项目进度 2. 资源分配"),
    KnowledgeItem(category: "工作", title: "邮件模板", content: "尊敬的XX，感谢您的来信..."),
    KnowledgeItem(category: "学习", title: "英语单词", content: "keyboard - 键盘\ninput - 输入\noutput - 输出"),
    KnowledgeItem(category: "生活", title: "购物清单", content: "牛奶、面包、鸡蛋、水果"),
  ]
  
  private var filteredItems: [KnowledgeItem] = []
  private var selectedCategory: String? = nil

  /// 标题标签
  lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "知识库"
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

  /// 搜索框
  lazy var searchTextField: UITextField = {
    let textField = UITextField()
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.placeholder = "搜索知识库..."
    textField.borderStyle = .roundedRect
    textField.font = .systemFont(ofSize: 14)
    textField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
    return textField
  }()

  /// 分类过滤按钮
  lazy var categoryFilterView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  /// 分类按钮容器
  lazy var categoryStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    stackView.spacing = 8
    return stackView
  }()

  /// 顶部容器
  lazy var headerView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  /// 表格视图
  lazy var tableView: UITableView = {
    let tv = UITableView(frame: .zero, style: .plain)
    tv.translatesAutoresizingMaskIntoConstraints = false
    tv.delegate = self
    tv.dataSource = self
    tv.register(KnowledgeItemCell.self, forCellReuseIdentifier: "KnowledgeItemCell")
    tv.showsVerticalScrollIndicator = true
    tv.separatorStyle = .singleLine
    return tv
  }()

  init(appearance: KeyboardAppearance, actionHandler: KeyboardActionHandler, keyboardContext: KeyboardContext) {
    self.appearance = appearance
    self.actionHandler = actionHandler
    self.keyboardContext = keyboardContext
    self.style = appearance.candidateBarStyle

    super.init(frame: .zero)

    setupSubview()
    setupCategoryButtons()
    updateFilteredItems()
  }

  func setupSubview() {
    constructViewHierarchy()
    activateViewConstraints()
    setupAppearance()
  }

  override func constructViewHierarchy() {
    addSubview(headerView)
    addSubview(searchTextField)
    addSubview(categoryFilterView)
    addSubview(tableView)
    
    headerView.addSubview(titleLabel)
    headerView.addSubview(closeButton)
    headerView.addSubview(addButton)
    
    categoryFilterView.addSubview(categoryStackView)
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
      
      // 搜索框约束
      searchTextField.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
      searchTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      searchTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      searchTextField.heightAnchor.constraint(equalToConstant: 36),
      
      // 分类过滤视图约束
      categoryFilterView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 8),
      categoryFilterView.leadingAnchor.constraint(equalTo: leadingAnchor),
      categoryFilterView.trailingAnchor.constraint(equalTo: trailingAnchor),
      categoryFilterView.heightAnchor.constraint(equalToConstant: 36),
      
      // 分类按钮容器约束
      categoryStackView.topAnchor.constraint(equalTo: categoryFilterView.topAnchor),
      categoryStackView.leadingAnchor.constraint(equalTo: categoryFilterView.leadingAnchor, constant: 12),
      categoryStackView.trailingAnchor.constraint(equalTo: categoryFilterView.trailingAnchor, constant: -12),
      categoryStackView.bottomAnchor.constraint(equalTo: categoryFilterView.bottomAnchor),
      
      // 表格视图约束
      tableView.topAnchor.constraint(equalTo: categoryFilterView.bottomAnchor, constant: 8),
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
    searchTextField.backgroundColor = style.toolbarButtonBackgroundColor
    searchTextField.textColor = style.textColor
    tableView.backgroundColor = style.backgroundColor
  }

  private func setupCategoryButtons() {
    let categories = Array(Set(knowledgeItems.map { $0.category })).sorted()
    
    // 全部按钮
    let allButton = createCategoryButton(title: "全部", category: nil)
    categoryStackView.addArrangedSubview(allButton)
    
    // 各分类按钮
    for category in categories {
      let button = createCategoryButton(title: category, category: category)
      categoryStackView.addArrangedSubview(button)
    }
  }

  private func createCategoryButton(title: String, category: String?) -> UIButton {
    let button = UIButton(type: .custom)
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 12)
    button.layer.cornerRadius = 16
    button.layer.borderWidth = 1
    button.addTarget(self, action: #selector(categoryButtonTapped(_:)), for: .touchUpInside)
    
    // 存储分类信息
    button.tag = category?.hashValue ?? 0
    button.accessibilityIdentifier = category
    
    updateCategoryButtonAppearance(button, isSelected: category == selectedCategory)
    
    return button
  }

  private func updateCategoryButtonAppearance(_ button: UIButton, isSelected: Bool) {
    if isSelected {
      button.backgroundColor = style.toolbarButtonFrontColor
      button.setTitleColor(style.backgroundColor, for: .normal)
      button.layer.borderColor = style.toolbarButtonFrontColor.cgColor
    } else {
      button.backgroundColor = style.toolbarButtonBackgroundColor
      button.setTitleColor(style.textColor, for: .normal)
      button.layer.borderColor = style.toolbarButtonFrontColor.withAlphaComponent(0.3).cgColor
    }
  }

  private func updateFilteredItems() {
    var items = knowledgeItems
    
    // 分类过滤
    if let selectedCategory = selectedCategory {
      items = items.filter { $0.category == selectedCategory }
    }
    
    // 搜索过滤
    if let searchText = searchTextField.text, !searchText.isEmpty {
      items = items.filter { 
        $0.title.localizedCaseInsensitiveContains(searchText) || 
        $0.content.localizedCaseInsensitiveContains(searchText)
      }
    }
    
    filteredItems = items
    tableView.reloadData()
  }

  @objc private func closeButtonTapped() {
    actionHandler.handle(.release, on: .custom(named: "hideKnowledgeBase"))
  }

  @objc private func addButtonTapped() {
    // 这里可以添加新知识的功能
    print("添加新知识")
  }

  @objc private func searchTextChanged() {
    updateFilteredItems()
  }

  @objc private func categoryButtonTapped(_ button: UIButton) {
    selectedCategory = button.accessibilityIdentifier
    
    // 更新所有按钮状态
    for case let categoryButton as UIButton in categoryStackView.arrangedSubviews {
      let isSelected = categoryButton.accessibilityIdentifier == selectedCategory
      updateCategoryButtonAppearance(categoryButton, isSelected: isSelected)
    }
    
    updateFilteredItems()
  }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension KnowledgeBaseManagerView: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return filteredItems.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "KnowledgeItemCell", for: indexPath) as! KnowledgeItemCell
    let item = filteredItems[indexPath.row]
    cell.configure(with: item, style: style)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let item = filteredItems[indexPath.row]
    actionHandler.handle(.release, on: .character(item.content))
    actionHandler.handle(.release, on: .custom(named: "hideKnowledgeBase"))
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 66
  }
}

// MARK: - KnowledgeItem

struct KnowledgeItem {
  let category: String
  let title: String
  let content: String
}

// MARK: - KnowledgeItemCell

class KnowledgeItemCell: UITableViewCell {
  lazy var categoryLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 12)
    label.layer.cornerRadius = 8
    label.layer.masksToBounds = true
    label.textAlignment = .center
    return label
  }()

  lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 16, weight: .medium)
    label.numberOfLines = 1
    return label
  }()

  lazy var contentLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 14)
    label.numberOfLines = 2
    label.textColor = .systemGray
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
    contentView.addSubview(categoryLabel)
    contentView.addSubview(titleLabel)
    contentView.addSubview(contentLabel)
    
    NSLayoutConstraint.activate([
      categoryLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
      categoryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      categoryLabel.widthAnchor.constraint(equalToConstant: 40),
      categoryLabel.heightAnchor.constraint(equalToConstant: 20),
      
      titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
      titleLabel.leadingAnchor.constraint(equalTo: categoryLabel.trailingAnchor, constant: 12),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      
      contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
      contentLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      contentLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
      contentLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
    ])
  }

  func configure(with item: KnowledgeItem, style: CandidateBarStyle) {
    categoryLabel.text = item.category
    titleLabel.text = item.title
    contentLabel.text = item.content
    
    categoryLabel.backgroundColor = style.toolbarButtonBackgroundColor
    categoryLabel.textColor = style.toolbarButtonFrontColor
    titleLabel.textColor = style.textColor
    contentLabel.textColor = style.textColor.withAlphaComponent(0.7)
    backgroundColor = style.backgroundColor
    
    // 添加选中效果
    let selectedBackgroundView = UIView()
    selectedBackgroundView.backgroundColor = style.toolbarButtonBackgroundColor
    self.selectedBackgroundView = selectedBackgroundView
  }
}