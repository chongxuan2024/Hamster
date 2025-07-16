# 键盘功能工具栏实现说明

本次更新在仓输入法键盘中新增了一个功能工具栏，位于候选词条和键盘输入区域之间，提供了便捷的功能访问入口。

## 🚀 新增功能

### 1. 功能工具栏 (KeyboardFunctionToolbarView)
- **位置**: 候选词条下方，键盘输入区域上方
- **高度**: 52pt
- **功能**: 包含4个主要功能按钮，居中水平排列

### 2. 功能按钮
- **剪贴板** (`doc.on.clipboard`): 显示剪贴板历史管理界面
- **常用词汇** (`text.book.closed`): 显示常用词汇管理界面
- **知识库** (`brain.head.profile`): 显示知识库管理界面
- **设置** (`gearshape`): 打开设置选项

## 📱 功能详细说明

### 剪贴板管理 (ClipboardManagerView)
- 网格布局显示剪贴板历史
- 支持点击快速输入
- 提供清空和关闭功能
- 模拟数据包含各类常用文本

### 常用词汇管理 (CommonWordsManagerView)
- 分类管理常用词汇
- 包含：问候语、日常用语、表情符号、常用短语
- 表格形式展示，支持分类浏览
- 点击直接输入到文本框

### 知识库管理 (KnowledgeBaseManagerView)
- 多分类知识管理系统
- 搜索功能：支持标题和内容搜索
- 分类筛选：技术、工作、学习、生活等
- 详细信息展示：分类标签、标题、内容预览

## 🛠 技术实现

### 1. 架构设计
```
KeyboardRootView
├── KeyboardToolbarView (候选词条)
├── KeyboardFunctionToolbarView (新增功能工具栏)
├── PrimaryKeyboardView (键盘输入区域)
├── ClipboardManagerView (剪贴板管理)
├── CommonWordsManagerView (常用词汇管理)
└── KnowledgeBaseManagerView (知识库管理)
```

### 2. 布局约束
- 功能工具栏固定在候选词条下方
- 管理视图覆盖键盘输入区域
- 通过隐藏/显示来切换界面

### 3. 自定义动作处理
- 扩展 `StandardKeyboardActionHandler` 创建 `HamsterKeyboardActionHandler`
- 支持自定义动作：`showClipboard`、`hideClipboard`、`showCommonWords` 等
- 动画效果：0.25秒淡入淡出切换

## 📂 新增文件

```
Packages/HamsterKeyboardKit/Sources/
├── View/
│   ├── KeyboardFunctionToolbarView.swift      # 功能工具栏
│   ├── ClipboardManagerView.swift             # 剪贴板管理
│   ├── CommonWordsManagerView.swift           # 常用词汇管理
│   └── KnowledgeBaseManagerView.swift         # 知识库管理
└── Controller/
    └── HamsterKeyboardActionHandler.swift     # 自定义动作处理器
```

## 🔧 修改文件

### KeyboardRootView.swift
- 添加功能工具栏和管理视图
- 更新布局约束系统
- 确保视图层级正确

### KeyboardInputViewController.swift
- 使用自定义动作处理器
- 设置视图引用关系

## 🎨 UI/UX 特性

### 视觉设计
- 遵循现有键盘主题样式
- 按钮圆角设计 (4pt)
- 一致的颜色方案和字体
- 36pt 标准按钮尺寸

### 交互体验
- 按钮按下视觉反馈
- 平滑动画过渡
- 直观的图标设计
- 便捷的关闭操作

### 响应式布局
- 适配不同屏幕方向
- 支持动态字体缩放
- 深色/浅色主题自动适配

## 🚦 使用方式

1. **显示功能**: 点击工具栏中的对应图标按钮
2. **输入文本**: 在管理界面中点击项目快速输入
3. **关闭界面**: 点击右上角关闭按钮或选择文本后自动关闭
4. **切换功能**: 不同功能间自动切换，无需手动关闭

## 🔮 扩展性

### 数据源
- 剪贴板: 可集成真实剪贴板API
- 常用词汇: 可连接用户自定义词库
- 知识库: 可支持云同步和导入导出

### 功能扩展
- 添加更多快捷功能按钮
- 支持用户自定义工具栏
- 集成更多第三方服务

## 📋 注意事项

1. **内存管理**: 使用弱引用避免循环引用
2. **性能优化**: 懒加载和视图复用
3. **数据持久化**: 当前使用模拟数据，可扩展为真实存储
4. **键盘扩展限制**: 某些系统API在键盘扩展中受限

## 🎯 总结

本次更新成功实现了在候选词条和键盘输入框之间添加功能工具栏的需求，提供了剪贴板、常用词汇、知识库等实用功能，大大提升了输入法的实用性和用户体验。整个实现保持了良好的代码架构和可扩展性，为后续功能开发奠定了坚实基础。