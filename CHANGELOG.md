# Changelog

## 0.7.0-alpha.10 — 2026-11-09

- Add capability-gated W820NB Plus preset EQ in the unified DeviceDeck app. The D8 profile selects the known preset layout, D5 reads the current preset, and C4 writes a selected preset followed by a separate readback. Unsupported profile layouts are not exposed. Hardware validation remains pending.

- 在统一的 DeviceDeck 应用中加入 W820NB Plus 均衡器预设。D8 能力配置决定可用预设，D5 查询当前值，C4 写入后再单独读取确认。不支持的配置不显示；仍需实机验证。

## 0.7.0-alpha.9 — 2026-11-09

- Add model-specific gesture action maps for realme Buds Air 7 and Air 7 Pro in the unified macOS app. Exposed actions are limited to those in the reviewed vendor catalog; command behavior and readback still require physical-device validation.

- В едином приложении DeviceDeck для macOS добавлены модельные карты жестов realme Buds Air 7 и Air 7 Pro. Доступны только действия, указанные в изученном каталоге производителя; команды и их подтверждение нужно проверить на реальных наушниках.

## 0.7.0-alpha.8 — 2026-11-09

- Enable the existing realme find-device command for Air7 and Air7 Pro in the unified macOS app, based on both models reporting `findDevice` in the vendor catalog. DeviceDeck hardware validation is still required.

## 0.7.0-alpha.7 — 2026-11-09

- Add DeviceDeck-specific realme Buds Air7/Air7 Pro control profiles in the unified macOS app: battery/status via the existing realme session, ANC levels, preset EQ, game mode, spatial toggle, wear detection, and Air7 multipoint controls. Profile mapping comes from the reviewed Android device catalogue; physical-device command/readback verification is still outstanding. Air7 Pro spatial audio is marked as an inherited known issue and needs macOS verification.

## 0.7.0-alpha.6 — 2026-11-09

- Add Baseus Blade 2 power telemetry, display theme/saver/text and reminder/shutdown controls to the same macOS DeviceDeck device panel. Numeric settings use readback; display text cannot be confirmed by the observed protocol. Physical-device validation is still required.
- 在 macOS DeviceDeck 统一设备页中加入 Baseus Blade 2 电源数据、屏幕主题/保护/文字及提醒/自动关机设置。数值设置会回读确认；当前协议无法确认屏幕文字。仍需实机验证。
- Add Baseus Bowie 30 to the unified macOS app over its cataloged BLE profile. Read battery/noise state and set Off, Commute, Indoor, Outdoor and Transparency with ACK plus state readback. Hardware validation remains outstanding.
- 在统一的 macOS 应用中接入 Baseus Bowie 30 BLE：读取电量/降噪状态，可切换关闭、通勤/室内/户外降噪和通透，并进行确认及状态回读。实机验证仍待完成。
- Add initial Baseus Bass EP10 Pro SPP support on macOS: query left/right battery and noise mode; set Off, ANC, and Transparency with ACK plus state readback. Protocol source is the user-supplied Baseus Intelligent 2.18.0 APK; physical-device validation is still required.
- 在 macOS 新增 Baseus Bass EP10 Pro 的初步 SPP 支持：读取左右耳电量和降噪模式；切换关闭、降噪、通透，并检查确认及状态回读。协议依据为用户提供的 Baseus Intelligent 2.18.0 APK；仍需实机验证。

## Unreleased

## 0.7.0-alpha.5 — 2026-11-08

- Add Baseus Bowie MF1 left/right battery reading over RFCOMM/SPP in the unified DeviceDeck app. No undocumented noise-mode controls are shown. Physical-device verification remains pending.
- Add the Baseus Bowie 30 ANC environments and preserve its BLE controls in the same app; add catalog aliases for EP10 Pro and Bowie MF1.
- macOS tests, source audit, app/DMG verification, and public source packaging run in CI. New Baseus device paths remain unverified on physical hardware.
- В едином приложении DeviceDeck добавлено чтение заряда левого и правого наушников Baseus Bowie MF1 через RFCOMM/SPP. Неподтверждённые команды управления режимами не показываются; требуется проверка на устройстве.
- Добавлены режимы ANC Baseus Bowie 30, а также варианты названий EP10 Pro и Bowie MF1 в каталоге. Управление Bowie 30 использует тот же BLE-профиль DeviceDeck.
- CI проверяет тесты, исходники, приложение и DMG; новые функции Baseus пока не проверены на реальных устройствах.

## 0.7.0-alpha.4 — 2026-11-08

- Add Edifier W820NB Plus low-latency game-mode control, gated by the device's D8 capability response and confirmed by a separate state query after writes. Hardware behavior remains unverified.
- 新增 Edifier W820NB Plus 游戏模式控制：仅当设备 D8 能力响应声明支持时显示，写入后另行查询状态确认。仍未通过实机验证。

## 0.7.0-alpha.3 — 2026-11-07

- Match Edifier D8 informational capability labels to the exact scalar values parsed by Edifier Connect; reserved/non-Boolean values no longer appear as supported controls.
- Исправлено отображение возможностей Edifier D8: поля теперь трактуются точно по парсеру EDIFIER Connect, зарезервированные и не-логические значения не показываются как поддерживаемые функции.
- No commands were added. W820NB Plus hardware behavior remains unverified.

## 0.7.0-alpha.2 — 2026-11-07

- Show the documented capabilities reported by Edifier W820NB Plus D8 responses on the device-info page. This is informational and does not imply that every reported control is implemented.
- 保留 Edifier W820NB Plus 设备返回的 D8 能力数据，并在设备信息页展示已知能力。此信息不代表应用已实现所有对应控制。
- Edifier protocol/UI tests, source audit, app bundle audit and DMG packaging pass in GitHub Actions. Physical W820NB Plus behavior remains unverified.

## 0.7.0-alpha.1 — 2026-11-07

- Rebrand the macOS app as DeviceDeck with its own bundle ID, icon, project URL and release destination; migrate preferences from prior HeyBuds/EncoBar installations.
- Remove the inherited Sparkle feed and installer. The update button now opens DeviceDeck Releases, keeping updates under project control and reducing the app bundle.
- Add an initial BLE profile and D8 capability capture for Edifier W820NB Plus, with battery and ANC/transparency controls. Physical-device validation is still required.
- Publish macOS artifacts from `macos-v*` tags through GitHub Actions.

- Give DeviceDeck its own macOS name, bundle ID, icon, project/release links and preference migration from HeyBuds and EncoBar.
- Remove the upstream Sparkle feed and installer. The update action now opens DeviceDeck Releases and the app bundle is smaller.
- Add an initial Edifier W820NB Plus BLE profile and D8 capability capture, plus battery and ANC/transparency controls. Hardware validation remains outstanding.
- Add GitHub Actions publication for `macos-v*` tags.

## 0.6.1-beta.2 — 2026-11-02

- 新增 Apple Silicon Mac 上的 macOS 15 支持，降噪、导航和操作按钮使用兼容样式，保留原有布局与功能。
- macOS 26+ 继续使用原有 Liquid Glass 界面；减少透明度和减少动态效果设置继续生效。
- 本版本为测试版，macOS 15 真机体验仍待验证与反馈，应用内更新继续使用正式版通道。

- Add macOS 15 support on Apple Silicon, with compatible noise-control, navigation and action-button styles and the existing layout and features.
- Retain the existing Liquid Glass interface on macOS 26+ and respect Reduce Transparency and Reduce Motion.
- This is a prerelease. Verification and feedback on physical Macs running macOS 15 are still pending; in-app updates remain on the stable channel.

## 0.6.0 — 2026-11-02

新增 16 款 Xiaomi / Redmi 的初步支持：10 款按型号开放降噪、EQ、手势等控制，6 款仅基础信息及电量；功能与连接限制见[小米支持范围](docs/XIAOMI_SUPPORT.md)。HeyBuds/macOS 实机兼容性待验证。

Initial support for 16 explicit Xiaomi / Redmi models: 10 model-specific control profiles and 6 read-only information/battery profiles. Hardware acceptance remains pending.

新增 39 款耳机的初步支持：Soundcore、MOMENTUM、JBL、HONOR，以及更多 Sony、Galaxy Buds、Bose QC35 和 Nothing/CMF 型号。按型号提供电量、降噪及有明确依据的音效/设备功能，详见[功能与限制](docs/DESKTOP_EXPANSION.md)。新增型号均待 HeyBuds/macOS 实机验证。

Initial support for 39 additional models across Soundcore, Sennheiser, JBL, HONOR, Sony, Samsung, Bose and Nothing/CMF. Features vary by model and firmware; hardware compatibility remains unverified.

- Soundcore 接入预设与自定义 EQ、部分型号双连；MOMENTUM 接入 EQ、佩戴检测与设备列表。
- M5 写入限定固件 6.21.5；WF-C700N 降噪写入限定 2.0.7。QC35 不显示通透，Ear (stick) 不显示降噪。
- JBL Wave Buds 2 接入电量；TUNE230NC/770NC 仅接入降噪控制，JBL EQ 尚未开放。

### 致谢 / Thanks

- **Xiaomi / Redmi**：[BudsLink](https://github.com/maniacx/BudsLink)、[MiBudsClient](https://github.com/CesurPolat/MiBudsClient)、[buds-ctl](https://github.com/LeoLee0812/buds-ctl)、[redmi-buds-bar](https://github.com/robin-liquidium/redmi-buds-bar)、[MiPods](https://github.com/JackWPP/MiPods)。
- **Soundcore**：[OpenSCQ30](https://github.com/Oppzippy/OpenSCQ30)。
- **Sennheiser**：[momentum4-control](https://github.com/Ariazonaa/momentum4-control)。
- **JBL**：[Omaphones](https://github.com/ncr/omarchy-headphones)、[JBL Control](https://github.com/AhmadRun/jbl-control)、[770NC Windows Controller](https://github.com/Xeo23/JBL-Tune-770NC-Windows-Controller)。
- **HONOR**：[OpenFreebuds](https://github.com/melianmiko/OpenFreebuds)。
- **Sony / Bose**：[SonyHeadphonesClient](https://github.com/mos9527/SonyHeadphonesClient)、[Sound Connect](https://github.com/aecca/sound-connect)、Omaphones。
- **Samsung**：[GalaxyBudsClient](https://github.com/timschneeb/GalaxyBudsClient)。
- **Nothing / CMF**：[ear-web](https://github.com/radiance-project/ear-web) 与 Omaphones（协议事实参考；未采用许可声明冲突的实现代码）。

## 0.5.0 — 2026-10-26

新增 16 款耳机的初步支持，保留原有型号与功能。所有新增型号的 HeyBuds/macOS 实机兼容性仍待验证；具体功能取决于型号、固件和设备响应。

Initial support for 16 additional models, retaining existing models and features. HeyBuds/macOS hardware compatibility for all new models remains unverified; available controls depend on the model, firmware and device responses.

- **Samsung Galaxy Buds2 / Buds2 Pro / Buds4 Pro**：电量、降噪和预设 EQ；Buds2/2 Pro 触控锁，Buds4 Pro 降噪强度。 Battery, noise control and preset EQ; touch lock on Buds2/2 Pro and ANC strength on Buds4 Pro.
- **Google Pixel Buds Pro / Pro 2**：电量、降噪和五组 EQ 预设。 Battery, noise control and five EQ presets.
- **Bose QuietComfort 45 / QuietComfort Ultra Headphones (2nd Gen) / QuietComfort Ultra Earbuds (2nd Gen)**：电量、Quiet / Aware 模式及设备可确认的降噪级别。 Battery, Quiet / Aware modes and device-confirmed cancellation levels.
- **Nothing Ear (a) / Headphone (1) / CMF Buds 2 / Buds Pro 2**：电量、降噪与通透；预设 EQ 按型号及设备响应开放。 Battery and noise control; preset EQ where supported by the model and device responses.
- **Sony WH-1000XM3 / WH-1000XM4 / WH-XB910N / ULT WEAR**：电量、降噪、通透和语音聚焦；ULT WEAR 暂无通透强度调节。 Battery, noise control and Focus on Voice; ambient-level adjustment is unavailable on ULT WEAR.

### 致谢 / Thanks

感谢以下项目分享对应型号的协议资料与实现参考。 Thanks to these projects for model-specific protocol documentation and implementation references:

- **Samsung**：[Budsy](https://github.com/vedatkilic/budsy)、[GalaxyBudsClient](https://github.com/timschneeb/GalaxyBudsClient)。
- **Google**：[PixelBudsMacOS](https://github.com/KashaMalaga/PixelBudsMacOS)、[pbpctrl](https://github.com/qzed/pbpctrl)。
- **Bose**：[bosectl](https://github.com/aaronsb/bosectl)、[bozo](https://github.com/NerdySouth/bozo)、[bosectl-android](https://github.com/depau/bosectl-android)。
- **Nothing / CMF**：[swift-nothing-ear](https://github.com/bestK1ngArthur/swift-nothing-ear)、[nothing-x-macos](https://github.com/nikiomori/nothing-x-macos)、[openNothing](https://github.com/Evergaster/openNothing)（协议事实参考 / protocol facts）。
- **Sony**：[SonyHeadphonesClient](https://github.com/mos9527/SonyHeadphonesClient)、[sonyctl](https://github.com/DaanHessen/sonyctl)（协议事实参考 / protocol facts）、[sony-ult-ctl](https://github.com/Leonard013/sony-ult-ctl)。


## 0.4.7 — 2026-10-25

- Add initial Sony WF-1000XM5, WH-1000XM5 and WH-CH720N support for battery, noise cancellation and ambient sound.
- Add ambient sound levels 1–20 and Focus on Voice for these Sony models. Real-device verification remains pending.
- Thanks to [SonyHeadphonesClient](https://github.com/mos9527/SonyHeadphonesClient), [SonyBridge](https://github.com/AmitRajput-Dev/SonyBridge), [HeadBridge](https://github.com/herenickname/HeadBridge) and [Sony Device Center](https://github.com/marconvcm/sony-device-center) for Sony protocol and model references.

## 0.4.6 — 2026-10-25

- Fix noise, equalizer and sound settings being reported as successful without a valid response from the earbuds.
- Prevent connection conflicts during consecutive controls and improve cancellation and reconnection reliability.
- Fix busy indicators after switching earbuds and close outdated EQ editors when the device disconnects or changes.
- Restrict manual model selection to compatible devices to prevent incorrect connections.
- Fix missing low-battery notifications when switching between different earbuds.

## 0.4.5 — 2026-10-22

- Make the connection pop-up more compact with less top spacing and balanced battery columns.
- Align the dismiss button with the header, add a subtle circular background and move battery-loading status into the connection line.

## 0.4.4 — 2026-10-22

- Fix the menu-bar panel covering native update windows when checking for updates.
- Place Reconnect automatically above Background mode in General settings.

## 0.4.3 — 2026-10-22

- Fix switches briefly turning dark or bright when opening Settings by removing the whole-panel page transition.

## 0.4.2 — 2026-10-22

- Use the native popover material for connection cards, synchronize their appearance and smooth the dark-mode edges.
- Use consistent system text sizing and regular weight for settings labels and selected values.
- Replace nested picker menus with native popup controls containing only choices and selection marks; remove duplicate headings.

## 0.4.1 — 2026-10-22

- Combine the Settings footer into one row: app name and compact license, GitHub, diagnostics and Quit at the far right.
- Show Alipay QR codes for ¥5 / ¥10 / ¥20 / ¥50 and any amount, selected directly in the coffee support popover.

## 0.4.0 — 2026-10-22

- Provide a DMG installer that opens directly and supports dragging HeyBuds to Applications.
- Download and install updates in a native macOS window, with progress, cancellation and restart.
- Make Settings more compact, merge the version into the update action and move diagnostics to the bottom right.
- Use a small GitHub footer icon and a separate coffee support entry with Alipay amounts of ¥5 / ¥10 / ¥20 / ¥50, direct links and sharing to a phone.

## 0.3.4 — 2026-10-22

- Use circular glass back buttons across secondary pages.
- Move setting explanations into clickable information buttons beside their labels, with hover help and accessible descriptions. Keep help available when the model selector is disabled.

## 0.3.3 — 2026-10-22

- Add manual update checking, the GitHub project link and a text-only donation link to Diagnostics.
- Compare stable release versions numerically, show update-check failures clearly and open downloads only at the user's request.

## 0.3.2 — 2026-10-22

- Add OPPO Enco X4 (`06EC10`) and its Enco Bohr alias from EncoDeck, with the model's noise modes, EQ presets, ten-band custom EQ and existing sound/device controls.
- Recognize X4 parent/child noise reports and require a Hi-Res-off readback before enabling spatial audio. X4 adaptive noise uses the parent button; individual adaptive levels are not exposed.
- Remove Apple / Beats catalogs and passive advertisement support; macOS provides their native integration.
- Set the minimum deployment target to macOS 26 and update both READMEs, placing disconnected and connection pop-up previews first.
- Keep local agent instructions out of Git tracking and source releases. Preserve the X4 source excerpt and GPL notice.

### Thanks

Thanks to [EncoDeck](https://github.com/TIANLI0/EncoDeck) and its contributors for publishing the OPPO Enco X4 model configuration and protocol tests used for this adaptation.

## 0.3.1 — 2026-10-22

- Show the menu bar entry before background catalog loading; create the panel on first use.
- Index model names and aliases once and reuse the catalog during discovery.
- Reduce background discovery wakeups and omit the idle loading indicator.
- Strip release symbols, losslessly compress the icon, compact runtime catalogs, exclude reference-only data and keep developer preview/check code in debug builds.
- Simplify bilingual READMEs, consolidate compatibility/release notes and verify exact app/ZIP contents in CI.

## 0.3.0 — 2026-10-17

- Rename EncoBar to **HeyBuds**, including the app, Swift package and modules, resources, diagnostics and `heybuds-probe`.
- Use `local.heybuds.app` and migrate recognized legacy preferences once, without replacing existing HeyBuds settings.
- Preserve the native interface and the six brand backends from 0.2.0.
- Prepare a public source archive, bilingual documentation, contribution and release guides, issue templates and GitHub Actions.

## 0.2.0 — 2026-10-17

- Add vivo / iQOO, Huawei, Xiaomi / Redmi, Edifier and read-only Apple / Beats backends alongside OPPO / OnePlus / realme.
- Import 226 catalog records, including model IDs and family rules. Keep hardware-validation claims separate from catalog and simulated-protocol coverage.
- Validate 61 automated tests before the rename.
