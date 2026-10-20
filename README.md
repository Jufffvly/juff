# 函数绘图（SwiftUI）

一个使用 SwiftUI 和 Canvas 实现的函数曲线绘图示例，适用于 iOS 16 及以上版本。

## 功能

- 绘制正弦、余弦、二次、一次、绝对值和指数函数
- 独立控制每条曲线的显示与隐藏
- 双指捏合缩放坐标系，曲线与网格同步缩放
- 拖动平移绘图区
- 一键重置视图
- 自定义函数表达式（支持 x、加减乘除、幂运算，以及 sin、cos、tan、abs、sqrt、exp、ln）

## 运行

1. 在 Xcode 中新建一个 iOS App 项目，界面选择 SwiftUI，最低系统版本设为 iOS 16。
2. 将仓库中的 `ContentView.swift` 内容替换项目里的同名文件。
3. 运行到 iPhone 或 iOS 模拟器。

> 当前仓库提供应用核心视图源码；它不是包含 Xcode 项目配置的完整 .xcodeproj 工程。
