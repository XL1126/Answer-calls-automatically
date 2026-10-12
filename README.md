# Answer calls automatically

**App 名称：** 自动接电话  
**App 版本：** 1.0.0  
**项目类型：** Flutter 功能 Demo  
**平台：** Android  

---

## 1. 项目简介

「自动接电话」是一个 Android 端 **来电自动接听 + 通话录音** 的功能演示应用（Demo）。

它解决的核心问题很简单：

> 来电响起时，手机不在手边（开车、做饭、运动、手上有事），希望能**自动接通**；接通后还能**把这通电话录下来**，方便事后在 App 里回听。

本仓库展示完整可运行实现：Flutter 界面 + Android 原生服务（无障碍 / 电话状态 / 录音）。

> **定位说明：** 这是功能 Demo，用于演示自动接听与通话录音的实现思路。国内各厂商 ROM 对通话录音限制不同，实际效果以真机为准。

---

## 2. 基本功能

| 功能 | 说明 |
|------|------|
| 自动接听 | 来电振铃时，按规则自动接通电话 |
| 延迟接听 | 可设置 0–30 秒延迟后再接听，避免误接 |
| 免提接听 | 接通后自动打开扬声器 |
| 号码过滤 | 全部接听 / 仅白名单 / 黑名单自动拒接 |
| 定时接听 | 仅在设定时间段内自动接听（支持跨天） |
| 通话自动录音 | 通话接通后自动录音，挂断自动保存 |
| 录音管理 | 应用内查看录音列表、播放、拖动进度、删除 |
| 通话记录 | 记录最近的接听 / 拒接 / 录音事件 |
| 系统状态检查 | 检查无障碍服务是否开启，并引导授权 |

---

## 3. 功能详情

### 3.1 自动接听

来电处理流程：

1. **检测来电**  
   优先通过系统电话状态监听（`PhoneStateListener`）检测振铃；未授权时用无障碍事件扫描来电界面兜底。
2. **规则判断**  
   按「启用开关 → 定时时段 → 号码过滤」决定：接听 / 拒接 / 忽略。
3. **执行接听**（按优先级自动回退）  
   - 系统 API：`TelecomManager.acceptRingingCall()`  
   - 无障碍：查找「接听 / answer」按钮并点击  
   - 无障碍手势：模拟上滑接听
4. **通话建立后**  
   按开关打开免提；若开启录音则开始录音。

**延迟接听：** 从振铃起等待设定秒数再接。适合想先听一下铃声、或等界面弹出后再接的场景。

### 3.2 号码过滤

| 模式 | 行为 |
|------|------|
| 全部接听 | 所有来电都自动接 |
| 仅白名单 | 只有白名单内的号码才自动接，其它忽略（仍可手动接） |
| 黑名单自动拒接 | 黑名单内的号码自动挂断，其它自动接 |

号码匹配规则：

- 先去掉非数字字符再比较
- 完全相等，或一方为另一方后缀（长度 ≥ 7）时视为匹配  
  （兼容 +86 / 0086 / 区号差异）

### 3.3 定时接听时段

- 关闭：全天都按规则自动接听  
- 开启：**仅在设定时段内**自动接听，时段外一律不自动处理  
- 支持跨天，例如 `22:00 – 07:00`

### 3.4 通话录音

- **触发时机：** 通话进入接通状态后约 0.8 秒开始录音；挂断自动停止并保存  
- **存储位置：** 应用私有目录 `Android/data/com.example.auto_answer/files/call_recordings/`  
- **文件命名：** `yyyyMMdd_HHmmss_号码.m4a`  
- **格式：** M4A / AAC，96 kbps，44.1 kHz  
- **容量：** 仅受手机存储限制；卸载应用会一并删除

**音源策略（自动回退）：**

1. `VOICE_CALL` — 理论音质最好，但 Android 10+ 多数机型对第三方应用屏蔽  
2. `VOICE_COMMUNICATION` — 通话通路采集，部分机型可用  
3. `MIC` — 麦克风采集（需配合免提，才能录到对方声音）

> 因此：若希望录到双方声音，建议开启「接听后开启免提」。

### 3.5 录音播放

进入 **通话录音** 页面可：

- 按时间倒序查看全部录音（号码、时间、大小）
- 点击播放 / 再点暂停
- 拖动进度条快进快退
- 停止播放
- 删除单条录音（会二次确认）

### 3.6 通话记录

首页 → 通话记录，查看最近事件：

- `接听` — 已自动接通  
- `拒接` — 已自动挂断  
- `录音` — 通话结束并生成录音文件  

最多保留 200 条。

---

## 4. 权限说明

| 权限 | 用途 | 是否必需 |
|------|------|----------|
| `READ_PHONE_STATE` | 检测来电 / 通话状态 | 是 |
| `READ_CALL_LOG` | 读取来电号码（用于白名单/黑名单） | 是（过滤功能） |
| `ANSWER_PHONE_CALLS` | 系统 API 直接接听 | 是 |
| `RECORD_AUDIO` | 通话录音 | 是（录音功能） |
| `MODIFY_AUDIO_SETTINGS` | 切换免提 | 是 |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MICROPHONE` | 录音时保活 | 是（录音功能） |
| `POST_NOTIFICATIONS` | 录音状态通知（Android 13+） | 建议开启 |
| **无障碍服务** | 模拟点击接听/拒接、手势接听 | **是（核心）** |

安装后请在 App 首页「系统授权」中：

1. 一键申请电话 / 通话记录 / 麦克风权限  
2. 打开系统的「自动接电话服务」无障碍开关  
3. 建议在系统设置中将本应用加入**电池优化白名单**，防止后台被杀

---

## 5. 使用步骤

1. 安装 `app-release.apk`
2. 打开 **自动接电话**
3. 首页 → **系统授权** → 授予全部运行时权限
4. 首页 → **无障碍服务** → 在系统设置中启用「自动接电话服务」
5. 按需打开：
   - 启用自动接听
   - 接听后开启免提（录音更完整）
   - 通话自动录音
6. 用另一台手机拨入测试

---

## 6. 技术架构

```
┌─────────────────────────────────────────────┐
│                  Flutter UI                  │
│  首页 / 过滤 / 定时 / 历史 / 录音列表与播放    │
└───────────────────┬─────────────────────────┘
                    │ MethodChannel
                    │ auto_answer/channel
┌───────────────────▼─────────────────────────┐
│                 Android 原生                 │
│  MainActivity          设置读写 / 播放控制    │
│  AutoAnswerService     无障碍接听与录音触发   │
│  CallRecorder          MediaRecorder 录音    │
│  RecordForegroundService  录音保活           │
│  RecordingStore        录音文件管理          │
│  PlaybackController    MediaPlayer 播放      │
│  Prefs                 配置与通话记录        │
└─────────────────────────────────────────────┘
```

### 目录结构（关键）

```
AutoAnswerFlutter/
├── lib/                      Flutter 界面与桥接
│   ├── main.dart
│   ├── home_page.dart
│   ├── recordings_page.dart
│   ├── filter_page.dart
│   ├── quiet_page.dart
│   ├── history_page.dart
│   └── native.dart
├── android/app/src/main/
│   ├── AndroidManifest.xml
│   ├── kotlin/com/example/auto_answer/
│   │   ├── AutoAnswerService.kt
│   │   ├── CallRecorder.kt
│   │   ├── RecordForegroundService.kt
│   │   ├── RecordingStore.kt
│   │   ├── PlaybackController.kt
│   │   ├── MainActivity.kt
│   │   └── Prefs.kt
│   └── res/xml/accessibility_service_config.xml
└── pubspec.yaml
```

### 技术栈

| 层 | 技术 |
|----|------|
| 界面 | Flutter 3.x / Material 3 |
| 接听 | AccessibilityService + TelecomManager |
| 监听 | PhoneStateListener（兼容新旧 API） |
| 录音 | MediaRecorder（M4A/AAC） |
| 播放 | MediaPlayer |
| 存储 | SharedPreferences + 应用私有目录 |
| 构建 | Gradle 9.x / AGP 8.11 / Kotlin 2.2 / JDK 21 |

---

## 7. 已知限制（请务必阅读）

1. **通话录音限制**  
   Android 10+ 多数机型禁止第三方应用采集系统通话音源。本应用会自动降级为「免提 + 麦克风」；对方声音靠扬声器回采，音质一般，且受环境噪音影响。
2. **不是系统默认拨号器**  
   无法使用 `InCallService` 官方通道，接听依赖系统 API + 无障碍模拟点击。部分深度定制 ROM 的来电界面若无标准“接听”节点，可能接不起来。
3. **权限与后台**  
   无障碍服务被系统关闭、应用被省电策略杀死后，自动接听会失效。请加入电池白名单。
4. **合规提醒**  
   通话录音在部分地区需要双方同意或明确告知。请仅用于合法、合规场景（例如自己的来电提醒、工作留痕等），并遵守当地法律。
5. **Demo 性质**  
   本仓库是功能演示实现，未做多语言、云备份、加密存储等生产级能力。

---

## 8. 构建说明

### 环境要求

- Flutter 3.47+（或 3.24+）
- JDK 17+（推荐 21）
- Android SDK（compileSdk 35+）
- Gradle 9.x（工程已配置）

### 构建 APK

```bash
cd AutoAnswerFlutter
flutter pub get
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

### 安装到设备

```bash
flutter install
# 或
adb install -r app-release.apk
```

---

## 9. 版本信息

| 项目 | 值 |
|------|-----|
| App 名称 | 自动接电话 |
| 英文 / 仓库名 | Answer calls automatically |
| 版本 | 1.0.0 |
| applicationId | `com.example.auto_answer` |
| 最低系统 | Android 8.0（API 26）以上能力较完整 |
| 包体大小 | 约 47 MB（release） |

---

## 10. 隐私声明

- 所有设置、通话记录、录音文件 **仅保存在本机**
- 不申请网络上传能力
- 不收集、不上传通讯录 / 通话内容 / 录音
- 无障碍服务仅用于识别来电界面并模拟接听/拒接

---

## 11. 免责声明

本项目仅供学习与功能演示。使用录音功能前，请确认符合你所在地区的法律法规。因使用本软件产生的任何后果，由使用者自行承担。

---

## 12. License

本仓库代码以学习交流目的公开。若需二次分发或商用，请自行评估合规风险。
