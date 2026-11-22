# 家有余 · HomeReserve

离线家庭收入、储蓄与资产记录工具，支持 Android、Windows、macOS。

- 按成员记录月度收入、净存入、账户分配与备注。
- 管理银行卡、支付账户、存款和理财，保存余额核对历史。
- 查看趋势、成员汇总、资产分布、同比环比和记录完整度。
- 跨设备导入导出数据包，预览来源、时间、数量及冲突，写入前自动备份。
- 支持 Excel、CSV、Word、PDF 导出，以及标准月度表格导入。
- 自适应布局，支持浅色、深色及跟随系统主题。

## 下载

前往 [最新发布](https://github.com/Smileher/HomeReserve/releases/latest)。

| 系统 | 文件与使用方式 |
| --- | --- |
| Android 12+ | 下载并安装 APK |
| Windows 10/11 x64 | 完整解压 ZIP，运行 home_reserve.exe |
| macOS 13+ Apple Silicon | 下载 DMG，拖入 Applications |

Windows 首版无付费代码签名；macOS 使用本地签名、未做 Apple 公证，首次打开可能需要在系统中确认来源。

## 数据说明

数据仅保存在本机，请定期通过“设置 → 导出完整数据包”备份。手机与电脑互导优先使用 JSON；Excel/CSV 只迁移月度记录。合并导入不删除额外记录，完整恢复需再次确认。本机自动恢复备份保留最近 10 份。

净存入允许负数，不自动增加账户实际余额。累计净存入不等于当前资产，资产变化不代表投资收益；共同账户仅汇总一次。

## 开发

Flutter 3.50.1 stable、Riverpod、Drift/SQLite。安装 Python 的 pillow、fonttools 后，运行 `python tool/bootstrap.py`、`flutter pub get`、`flutter analyze`、`flutter test`。

GitHub Actions 构建三端，发布版本标签后生成安装包及 SHA-256 校验文件。Android 正式签名通过仓库 Secrets 配置，禁止提交密钥。

MIT 许可证；随包中文字体使用 SIL Open Font License。
