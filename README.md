# 家有余 · HomeReserve

离线家庭收入、储蓄与资产记录工具，支持 Android、Windows、macOS。

- 按成员记录月度收入、净存入、账户分配与备注。
- 管理银行卡、支付账户、存款和理财，保存余额核对历史。
- 查看趋势、成员汇总、资产分布、同比环比和记录完整度。
- 跨设备导入导出数据包，预览来源、时间、数量及冲突，写入前自动备份。
- 支持 Excel、CSV、Word 导出，以及标准月度表格导入。
- 液态玻璃界面，手机与桌面自适应，支持浅色、深色及跟随系统主题。
- 空账本开始，自定义家庭成员，点击年月即可选择记录月份或分析年份。

## 下载

前往 [最新发布](https://github.com/Smileher/HomeReserve/releases/latest)。

| 系统 | 文件与使用方式 |
| --- | --- |
| Android 16+ ARM64 | 下载并安装 HomeReserve-android-arm64.apk |
| Windows 11 x64 | 完整解压 ZIP，运行 home_reserve.exe |
| macOS 26+ Apple Silicon | 下载 DMG，拖入 Applications |

Windows 首版无付费代码签名；macOS 使用本地签名、未做 Apple 公证，首次打开可能需要在系统中确认来源。

Windows 最小内容尺寸为 360 × 640，内容宽度小于 850 时自动切换为底部导航。

## 数据说明

数据仅保存在本机，请定期通过“设置 → 导出完整数据包”备份。手机与电脑互导优先使用 JSON；Excel/CSV 只迁移月度记录。合并导入不删除额外记录，完整恢复需再次确认。本机自动恢复备份保留最近 10 份。

净存入允许负数，不自动增加账户实际余额。累计净存入不等于当前资产，资产变化不代表投资收益；共同账户仅汇总一次。

## 开发

Flutter 3.50.1 stable、Riverpod、Drift/SQLite。Android 编译 SDK 37.2、目标 API 37、最低 API 36，发布包仅包含 ARM64。Windows 使用 Visual Studio 2026，macOS 使用 macOS 26 构建环境。安装 Python 的 pillow 后，运行 `python tool/bootstrap.py`、`flutter pub get`、`flutter analyze`、`flutter test`。

GitHub Actions 构建三端，发布版本标签后生成安装包及 SHA-256 校验文件。Android 正式签名通过仓库 Secrets 配置，禁止提交密钥。

MIT 许可证。
