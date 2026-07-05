# LandlineBlocker Xcode 配置说明

这是一个 iOS 16+ SwiftUI App 源码包，包含主 App、Call Directory Extension、Shared Foundation 代码和 XCTest。当前目录没有生成 `.xcodeproj`，请按下面步骤在 macOS + Xcode 中创建工程并导入这些文件。

## 0. 源码文件树

```text
LandlineBlocker/
  LandlineBlockerApp.swift
  ContentView.swift
  BlacklistViewModel.swift
  OCRService.swift
  CallDirectoryReloader.swift
  ShareExport.swift
  LandlineBlocker.entitlements

LandlineBlockerCallDirectoryExtension/
  CallDirectoryHandler.swift
  Info.plist
  LandlineBlockerCallDirectoryExtension.entitlements

Shared/
  SharedConfig.swift
  BlockedNumberRecord.swift
  NumberParser.swift
  BlacklistStorage.swift

LandlineBlockerTests/
  NumberParserTests.swift

README_Xcode_Setup.md
```

## 1. 创建 Xcode 工程

1. 打开 Xcode，选择 `File > New > Project...`。
2. 选择 `iOS > App`。
3. Product Name 填 `LandlineBlocker`。
4. Interface 选择 `SwiftUI`，Language 选择 `Swift`，最低系统设为 `iOS 16.0`。
5. Bundle Identifier 设置为 `com.vibecoding.LandlineBlocker`。
6. 创建后，把本源码包中的 `LandlineBlocker/` 和 `Shared/` 文件拖入工程。

## 2. 添加 Call Directory Extension target

1. 选择 `File > New > Target...`。
2. 选择 `iOS > Call Directory Extension`。
3. Product Name 建议填 `LandlineBlockerCallDirectoryExtension`。
4. Extension Bundle ID 设置为 `com.vibecoding.LandlineBlocker.CallDirectoryExtension`。
5. Xcode 提示是否 Activate scheme 时可以选择 Activate。
6. 删除 Xcode 自动生成的示例 handler 内容，用本源码包的 `LandlineBlockerCallDirectoryExtension/CallDirectoryHandler.swift` 和 `Info.plist` 替换。

主 App target 必须嵌入 `LandlineBlockerCallDirectoryExtension.appex`。如果使用 Xcode 新建 Call Directory Extension target，通常会自动加入主 App 的 `Build Phases > Embed App Extensions`。请手动确认该阶段包含 `LandlineBlockerCallDirectoryExtension.appex`。

## 3. 添加 Unit Test target

1. 选择 `File > New > Target...`。
2. 选择 `iOS > Unit Testing Bundle`。
3. Product Name 填 `LandlineBlockerTests`。
4. 把 `LandlineBlockerTests/NumberParserTests.swift` 加入 test target。
5. 测试文件使用 `@testable import LandlineBlocker`，因此 `Shared/*.swift` 必须属于主 App target。

## 4. Target Membership

按下面规则设置每个文件的 Target Membership：

| 路径 | Target Membership |
| --- | --- |
| `LandlineBlocker/LandlineBlockerApp.swift` | 只加入主 App target `LandlineBlocker` |
| `LandlineBlocker/ContentView.swift` | 只加入主 App target `LandlineBlocker` |
| `LandlineBlocker/BlacklistViewModel.swift` | 只加入主 App target `LandlineBlocker` |
| `LandlineBlocker/OCRService.swift` | 只加入主 App target `LandlineBlocker`，不要加入 Extension |
| `LandlineBlocker/CallDirectoryReloader.swift` | 只加入主 App target `LandlineBlocker` |
| `LandlineBlocker/ShareExport.swift` | 只加入主 App target `LandlineBlocker` |
| `Shared/SharedConfig.swift` | 同时加入主 App target 和 Extension target |
| `Shared/BlockedNumberRecord.swift` | 同时加入主 App target 和 Extension target |
| `Shared/NumberParser.swift` | 同时加入主 App target 和 Extension target |
| `Shared/BlacklistStorage.swift` | 同时加入主 App target 和 Extension target |
| `LandlineBlockerCallDirectoryExtension/CallDirectoryHandler.swift` | 只加入 Extension target，不要加入主 App target |
| `LandlineBlockerTests/NumberParserTests.swift` | 只加入 `LandlineBlockerTests` |

`Shared/` 目录中的文件只 import Foundation；不要把 SwiftUI、PhotosUI、Vision 或 UIKit 分享给 Extension。

## 5. Bundle ID、App Group 和 entitlements

主 App Bundle ID：

```text
com.vibecoding.LandlineBlocker
```

Extension Bundle ID：

```text
com.vibecoding.LandlineBlocker.CallDirectoryExtension
```

App Group：

```text
group.com.vibecoding.LandlineBlocker
```

主 App target 的 `Signing & Capabilities`：

1. 选择 `LandlineBlocker` target。
2. 设置 Team。
3. 添加 `App Groups` capability。
4. 勾选 `group.com.vibecoding.LandlineBlocker`。
5. entitlements 应包含：

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.vibecoding.LandlineBlocker</string>
</array>
```

Extension target 的 `Signing & Capabilities`：

1. 选择 `LandlineBlockerCallDirectoryExtension` target。
2. 设置同一个 Team。
3. 添加 `App Groups` capability。
4. 勾选同一个 `group.com.vibecoding.LandlineBlocker`。
5. entitlements 同样包含上面的 App Group。

源码包中提供了示例：

- `LandlineBlocker/LandlineBlocker.entitlements`
- `LandlineBlockerCallDirectoryExtension/LandlineBlockerCallDirectoryExtension.entitlements`

如果 Xcode 自动生成了 entitlements 文件，可以直接使用 Xcode 生成的文件，但内容必须一致。

## 6. Extension Info.plist

`LandlineBlockerCallDirectoryExtension/Info.plist` 必须包含：

```text
NSExtensionPointIdentifier = com.apple.callkit.call-directory
NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).CallDirectoryHandler
```

`CallDirectoryHandler.swift` 中类名必须是：

```swift
final class CallDirectoryHandler: CXCallDirectoryProvider
```

不要使用 `@objc(CallDirectoryHandler)`。不要把 `NSExtensionPrincipalClass` 写成主 App module，也不要同时使用 `@objc` 自定义类名和 `$(PRODUCT_MODULE_NAME).CallDirectoryHandler`。

## 7. Call Directory 逻辑限制

本 App 第一版只做具体号码黑名单：

1. 只拦截已导入并保存到 App Group `blacklist.json` 的具体号码。
2. iOS 不允许第三方 App 实时读取系统通话记录。
3. iOS 不允许第三方 App 实时监听来电。
4. iOS 不允许第三方 App 在每次来电时按正则或“号码显示是否带括号”动态判断拦截。
5. “括号号码拦截”的实际实现是：文本或 OCR 识别这类固话号码，转换成 `86` 开头纯数字后提交给 CallKit。
6. 导入后删除或清空黑名单，必须再次点击“刷新拦截库”，系统侧才会更新。

## 8. 真机开启方式

安装 App 后，在 iPhone 上打开：

```text
设置 > 电话 > 来电阻止与身份识别
```

手动开启本 App 的来电拦截扩展。开启后回到 App，点击“刷新拦截库”。App 内状态应显示“已启用”，刷新成功后显示“拦截库刷新成功”。

## 9. 真机排错

App 能打开但系统设置里看不到扩展：

1. 检查主 App target 的 `Build Phases > Embed App Extensions` 是否包含 `LandlineBlockerCallDirectoryExtension.appex`。
2. 检查 Extension Bundle ID 是否为 `com.vibecoding.LandlineBlocker.CallDirectoryExtension`。
3. 检查主 App 和 Extension 是否使用有效签名。
4. 检查主 App 和 Extension entitlements 是否都包含同一个 App Group。
5. 检查 Extension `Info.plist` 的 `NSExtensionPointIdentifier` 和 `NSExtensionPrincipalClass`。

刷新失败：

1. 查看 App UI 中显示的 `localizedDescription` 和 error code。
2. 连接 Xcode 真机调试，查看 Xcode console。
3. 确认系统设置中扩展已经手动开启。

刷新成功但不拦截：

1. 确认号码已经规范化成国家码数字序列，例如 `862154041579`。
2. 确认系统设置中扩展已启用。
3. 确认号码已保存进 App Group 的 `blacklist.json`。
4. 确认测试来电号码与导入号码完全一致。Call Directory 只能拦截提交过的具体号码。

清空黑名单后仍被拦截：

1. 确认清空后已再次点击“刷新拦截库”。
2. 确认刷新成功。

## 10. 运行测试

选择 `LandlineBlockerTests` 或主工程 scheme，按 `Command + U` 运行测试。`NumberParserTests.swift` 覆盖：

- 固话候选提取和规范化。
- 带上下文 OCR 文本提取。
- 手机号默认跳过。
- 勾选包含手机号后转为 `86` 前缀。
- 重复号码去重。
- Extension 提交前的严格升序排序逻辑。

## 11. Archive 和导出 IPA

最终签名、真机安装、Archive 和 IPA 导出需要 macOS + Xcode + Apple Developer Team。

1. 选择真机或 `Any iOS Device`。
2. 确认主 App 和 Extension 都配置了正确 Team、Bundle ID、entitlements 和 App Group。
3. 选择 `Product > Archive`。
4. Archive 完成后打开 Organizer。
5. 选择 `Distribute App`。
6. 按目标选择 `Development`、`Ad Hoc` 或 `App Store Connect` 导出 IPA。

自签或重签时要注意：主 App 和 embedded `.appex` 都必须保留正确 Bundle ID、entitlements 和 App Group，否则系统设置可能看不到扩展，或刷新时无法读取共享 `blacklist.json`。
