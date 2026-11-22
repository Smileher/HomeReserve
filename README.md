# 家有余 · HomeReserve

给 min 制作，和 he 一起，把日子过好，把幸福慢慢攒下。

一款完全离线的家庭收入、储蓄与账户资产工具，支持 Android、Windows、macOS。

## 下载与安装

前往 [最新发布](https://github.com/Smileher/HomeReserve/releases/latest) 下载：

| 系统 | 文件 | 安装方法 |
| --- | --- | --- |
| Android 8.0+ | HomeReserve-android.apk | 下载后打开，按系统提示允许该来源安装 |
| Windows 10/11 x64 | HomeReserve-windows-x64.zip | 完整解压到可写目录，运行 home_reserve.exe；不要只复制 EXE |
| macOS 13+ Apple Silicon | HomeReserve-macos-arm64.dmg | 打开后将 HomeReserve 拖到 Applications |
| macOS 13+ Intel | HomeReserve-macos-x64.dmg | 同上 |

首版 Windows 没有付费代码签名，macOS 使用本地签名，未做 Apple 公证。系统可能要求确认来源。macOS 可在尝试打开后，按系统“隐私与安全性”中的提示允许打开此应用；不需要关闭系统整体安全保护。

## 开始记录

1. 设置里可以维护家庭成员，默认 he、min。
2. 月度页面填写每个人当月收入与**净存入**。留空表示未填写，0 表示已经确认，净存入可为负。
3. 资产页面添加银行卡、支付宝、理财等账户，填写核对日期和**实际余额**。
4. 月度净存入可以分配到各账户，但不会再次增加账户余额，避免重复计算。
5. 分析页面按年度查看趋势、完整度和成员汇总，导出 Excel、CSV、Word、PDF。

**重要口径**：累计净存入不等于当前资产；账户间转账不算新增储蓄；资产变化不等于投资收益。首页汇总各账户最近一次已核对余额，账户日期可能不同，不应理解为银行实时总额。共同账户仅汇总一次。

## 手机与电脑互导

在“设置 → 导出完整数据包”导出 JSON；Android 通过系统分享菜单保存到文件或传送到电脑。在另一台设备选择“导入数据或表格”。

- 先展示来源、导出时间与时区、月份范围、记录数量及字段差异。
- 相同数据跳过；冲突默认保留本机，逐条选择是否使用导入内容。
- 同名但标识不同的成员、账户，需要明确选择对应关系。
- 普通合并不会删除本机额外记录，也不会按修改时间偷偷覆盖。
- “完整恢复”会整体替换业务数据，需要再次确认。
- 写入前自动保存本机恢复备份，最近 10 份；失败时事务回滚。
- 设备名称不随导入改变；主题默认不覆盖；来源显示在详情，不改写备注。

XLSX/CSV 导入只支持本软件导出的“月度记录”列：月份、成员、收入（元）、净存入（元）、备注。完整迁移请使用 JSON；表格不包含账户分配和完整历史。

数据包没有密码或加密，请自行保管。财务数据不会上传 GitHub，应用没有账户和云端服务。版本链接只通过外部浏览器打开。

## 本地数据与备份

业务数据位于系统应用支持目录内的 `home_reserve.sqlite`。自动备份位于同目录 `backups` 中。卸载、清理应用数据前务必导出完整数据包。Android 不启用系统自动云备份。

## 开发与构建

固定 Flutter **3.50.1 stable**，Dart 随 Flutter 安装。源码采用 Riverpod、Drift/SQLite、fl_chart；金额以整数分保存。

原生 runner 由固定版本 Flutter 模板生成，`tool/bootstrap.py` 只应用项目标识、图标、权限、Android 签名和开源报表字体。GitHub Actions 负责生成、检查及构建；本机无需安装所有平台 SDK。

```sh
python -m pip install pillow fonttools
python tool/bootstrap.py
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test
```

Android release 需要 `ANDROID_KEYSTORE_PATH`、`ANDROID_STORE_PASSWORD`、`ANDROID_KEY_PASSWORD`、`ANDROID_KEY_ALIAS`。仓库 Secrets 保存 `ANDROID_KEYSTORE_BASE64` 及两个密码；签名文件绝不能提交源码。

发布 `v*` 标签触发全矩阵构建，仅在 Android、Windows、两种 macOS 包全部成功后发布 Release，附 SHA-256 校验文件。CI 使用普通公开仓库 runner。

## 许可

项目使用 MIT。报表字体 Noto Sans SC 使用 SIL Open Font License，构建时随字体包含 OFL.txt。其余依赖遵循各自许可证。
