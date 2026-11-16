# 凯度蒸烤箱 × Home Assistant —— tuya-local 配置包

把**凯度（Casdon）蒸烤箱**本地接入 Home Assistant 的**设备配置文件**：不需要刷机、不依赖厂商云端，通过已有的 Tuya Local 集成走局域网协议直连。

## 这是什么 / 不是什么

| | |
| --- | --- |
| ✅ 是 | [tuya-local](https://github.com/make-all/tuya-local) 的 `devices/*.yaml` 设备配置（DP 映射） |
| ✅ 是 | 可选的模板实体（预热判断、秒级倒计时、门状态） |
| ❌ 不是 | HACS / Marketplace 里能"安装"的集成 |
| ❌ 不是 | 独立的 Python 插件，本仓库不含任何集成代码 |
| 依赖 | 你必须先装好 **tuya-local** 集成（Marketplace 里搜 "Tuya Local"） |

所以正确的使用方式是「把 YAML 复制进 tuya-local 的 devices 目录」，而不是在 Marketplace 里添加本仓库。详见下文。

```
devices/casdon_gq_pro.yaml      tuya_local 设备配置（核心）
templates/gq_pro_templates.yaml 可选：预热判断 / 秒级倒计时 / 门状态
docs/dp-map.md                  DP 对照表（含未知项）
docs/modes.md                   模式枚举（105）采集进度
scripts/install.sh              把上面两个文件装进 HA 配置目录
```

---

## 一、原理

凯度生活家 App 是**涂鸦（Tuya）贴牌应用**——它的界面资源来自 `images.tuyacn.com`，设备走涂鸦 MQTT。

所以设备可以直接绑到「涂鸦智能」App，再用 [tuya-local](https://github.com/make-all/tuya-local) 以 localKey 本地接入 HA：

```
蒸烤箱 ──局域网(6668)──> tuya-local ──> Home Assistant
         ▲
         └── localKey / deviceId / IP（从涂鸦云拿一次即可）
```

好处是控制链路不出局域网，响应快、断网也能用；代价是要拿到设备的 localKey。

---

## 二、适用性

| 项目 | 值 |
| --- | --- |
| 验证型号 | 凯度 GQ Pro 蒸烤箱（56L，双热风） |
| productKey | `asgqmfnxo0lsiaa4` |
| 验证环境 | HA 2026.11 + tuya-local（Marketplace 版） |

凯度 TD Pro 2 / TD Pro 3 等**同族机型大概率兼容**（tuya-local 上游已有 `casdon_td_pro_2/3` 配置），但 DP 点可能不同，接入后按 `docs/dp-map.md` 对照调整。

---

## 三、准备工作

1. **Home Assistant**：任意版本，能装 HACS / Marketplace 插件
2. **烤箱已配网**：能通过凯度生活家 App 正常控制
3. **涂鸦智能 App**（手机应用商店搜「涂鸦智能」）
4. **涂鸦 IoT 开发者账号**（免费）：拿 localKey 用，[iot.tuya.com](https://iot.tuya.com)

---

## 四、接入步骤

### 1. 安装 Tuya Local

HA 2026.11 起 Marketplace 已内置（原 HACS）：

**设置 → Marketplace → 搜索 `Tuya Local` → 安装**

（旧版本 HA：装 HACS → 添加自定义仓库 `https://github.com/make-all/tuya-local` → 安装 → 重启）

### 2. 把设备绑到涂鸦智能

先重置烤箱 Wi-Fi：

> 开机状态下**长按「炉灯」键 3 秒**，听到提示音松手，屏幕 Wi-Fi 灯闪烁即重置成功。

然后在**涂鸦智能** App 里添加设备（不在凯度生活家里加）。添加成功后，界面和凯度生活家里一模一样——这本身就验证了它是涂鸦设备。

### 3. 获取 localKey

两种方式，任选：

**A. 用 tuya-local 的云端模式（推荐，最省事）**

先创建涂鸦云项目：

1. 登录 [iot.tuya.com](https://iot.tuya.com) → Cloud → 创建项目（数据中心选**中国**）
2. 项目里 → Devices → Link App Account → 用涂鸦智能 App 扫码授权
3. 记下项目的 **Access ID** 和 **Access Secret**

然后在 HA 添加集成时选「Cloud」模式，填入 Access ID / Secret，tuya-local 会自动列出账号下的设备并填好 deviceId、localKey、IP。

**B. 手动 tinytuya（不想给 HA 存云凭据）**

```bash
pip install tinytuya
python -m tinytuya wizard    # 按提示填 Access ID/Secret，会导出 devices.json
```

从 `devices.json` 里取三样东西：

```
id       → deviceId
key      → localKey
ip       → 烤箱的局域网 IP
```

### 4. 放置设备配置

把 `devices/casdon_gq_pro.yaml` 复制到：

```
/config/custom_components/tuya_local/devices/casdon_gq_pro.yaml
```

> 路径说明：`/config` 就是 HA 的配置目录。装了 Samba 或 File Editor 可以直接拖进去；也可以用 `scripts/install.sh`（见下）。

**如果找不到 devices 目录**，说明 tuya-local 还没装成功，回第 1 步。

### 5. 添加集成

**设置 → 设备与服务 → 添加集成 → Tuya Local**

- 选 Cloud 模式（或手动填 IP / deviceId / localKey）
- 协议版本一般默认 `3.4` 即可
- 设备类型列表里选 **`Casdon GQ Pro (oven)`**
- 起个名字，完成

如果类型列表里没有它，检查第 4 步的文件名和 YAML 缩进（tuya-local 会静默跳过解析失败的配置）。

### 6. （可选）模板实体

`templates/gq_pro_templates.yaml` 提供三个衍生实体：

| 实体 | 作用 |
| --- | --- |
| `GQ Pro 预热中` | 状态=cooking 且未到温时为 on |
| `GQ Pro 剩余时间` | 秒级倒计时（设备只给分钟） |
| `GQ Pro 门` | 独立的门开关状态（见下文「门位」） |

启用方式：把文件放到 `/config/gq_pro_templates.yaml`，然后在 `configuration.yaml` 末尾加一行：

```yaml
template: !include gq_pro_templates.yaml
```

> ⚠️ 如果 `configuration.yaml` 里**已经有** `template:` 键，不要重复加，改成把内容合并进现有列表。

放好后**重启一次 HA**（`template:` 是顶层键，新增需要重启；之后再改内容用「开发者工具 → 服务 → `template.reload`」即可）。

> ⚠️ 模板里引用的原始状态实体是 `sensor.chu_fang_zheng_kao_xiang_gq_pro_status_raw`——前缀「chu_fang」来自设备所在区域。你的实体 ID 可能不同，启用前先到「开发者工具 → 状态」里搜 `status_raw` 核对并替换。

### 7. 验证

接入后应该看到：

| 实体 | 说明 |
| --- | --- |
| `switch.*电源*` | 电源开关 |
| `switch.*启动*` | 启动 / 暂停（开=启动或继续，关=暂停） |
| `button.*暂停*` | 暂停（写 DP2=false） |
| `button.*继续*` | 继续（写 DP2=true） |
| `script.gq_pro_cancel` | 取消烹饪（先暂停再关电源） |
| `number.*设定温度*` | 设定温度（℃） |
| `sensor.*当前温度*` | 腔体当前温度（℃） |
| `light.*炉灯*` | 炉灯 |
| `time.*烹饪时长*` | 烹饪时长（分钟） |
| `time.*预约结束时间*` | 预约结束时刻（**不是**开始时刻） |
| `sensor.*剩余时间*` | 分钟（设备原值） |
| `sensor.*烹饪状态*` | wait / cooking / done / pause |
| `select.*烹饪模式*` | 模式选择（22 项中文，含「无」） |
| `sensor.*烹饪模式（名称）*` | 模式中文名（只读，与 select 同源） |
| `sensor.*烹饪模式（原始值）*` | 模式原始数字（诊断） |
| `binary_sensor.*问题*` | 故障（**已排除门位**） |
| `binary_sensor.*门*` | 门开/关（模板实体） |

---

## 五、已知限制（重要）

**1. 预热阶段状态也是 `cooking`**

设备不区分「预热」和「烹饪」，DP102 只有 wait/reservation/cooking/done/pause。温度到设定值后**剩余时间才开始倒计时**，所以「1 分钟」的设定实际要跑「预热 3~7 分钟 + 烹饪 1 分钟」。模板实体用温度对比来推断预热中。

**2. 温度、时长只在开机时上报**

空闲状态设备只上报 `1/13/102/103/105`，所以 `当前温度` 等实体在关机时是 unknown，这是正常的。

**3. 门状态是 DP13 的 bit8**

`DP13` 是位域，`256` 表示门开，不是故障：

| bit | 十进制 | 含义 |
| --- | --- | --- |
| 0–7 | 1–128 | 故障位（超温、传感器开路、水箱缺水等） |
| **8** | **256** | **门开（状态位）** |

本仓库的配置已经把门位从「问题」里排除，并单独做了门实体。如果你自己改映射，注意别把 256 当成故障——我们踩过这个坑。

**4. 模式（DP105）已完整标定**

21 个模式全部对上（详见 `docs/modes.md`），可以用 `select.*烹饪模式*` 直接切换。

**设备不会因为选模式而自动套用默认温度/时长**——通过本地协议只改 105，所以启动前要依次设好：

```
select     → 烹饪模式
number     → 设定温度
time       → 烹饪时长
switch 启动 → 开始
```

另外「杀菌 / 烘干 / 除垢」不支持预约，只能直接启动。

**5. 关机时除电源外的写入会被忽略**

关机状态下改模式、温度、时长、炉灯都不会生效——这是设备行为，不是 HA 的问题。**必须先开电源再设置。**

**6. 通过本地协议切换模式，设备不会套用默认温度/时长**

面板上换模式时，固件会在本机把温度/时长改成该模式的默认值；但通过本地协议只写 DP105 时，
**DP7/DP10 保持原值（通常是 0）**。这就是为什么仓库提供 `automations/gq_pro_mode_defaults.yaml`，
由 HA 补上默认值（见「附加自动化」一节）。

**7. 取消烹饪为什么是一个脚本**

单写电源开关（DP1=false）能让设备停止加热，但 **DP2 会残留为 true**，导致「启动」实体显示为开、
下次启动可能失效。所以取消做成两步：先 `switch.turn_off 启动`（DP2=false，暂停），再关电源，
这样两个字段都是干净的。



设备自带该行为：写入 DP105 后，DP7（温度）和 DP10（时长）会同步变成该模式的默认值，不需要额外的自动化。前提是设备处于开机状态（见上一条）。

---

## 五、附加自动化（可选，但强烈建议）

设备通过本地协议切换模式时不会带出默认温度/时长（见「已知限制」第 6 条），
`automations/gq_pro_mode_defaults.yaml` 用实测值补上：

| 模式 | 温度 | 时长 |
| --- | --- | --- |
| 纯蒸 / 高温蒸 | 100 / 110℃ | 20 分钟 |
| 上下烤 / 3D热风 / 风扇烤 / 大面积烤 / 下烤 / 低湿 / 中湿 / 高湿嫩烤 | 180℃ | 20 分钟 |
| 顶部热风 | 140℃ | 20 分钟 |
| 底部热风 | 220℃ | 20 分钟 |
| 空气炸 | 190℃ | 20 分钟 |
| 养生炖 | 110℃ | 40 分钟 |
| 解冻 / 保温 | 50 / 60℃ | 20 分钟 |
| 速热 | 140℃ | 15 分钟 |
| 发酵 | 30℃ | 20 分钟 |
| 杀菌 | 100℃ | 30 分钟 |
| 烘干 / 除垢 | 180 / 100℃ | 仅温度 |

安装：把内容合并进 `/config/automations.yaml`，然后「开发者工具 → 服务 → `automation.reload`」。

> ⚠️ 自动化里的实体 ID 带区域前缀（`chu_fang_`），换区域/重建实体后需同步修改。

## 六、排错

| 现象 | 原因 / 解决 |
| --- | --- |
| 添加设备时提示连接失败 | 烤箱 Wi-Fi 断开 / IP 变了；路由器里给它**绑定固定 IP** |
| 实体偶尔变 unavailable | 本地协议**同时只允许一个连接**：凯度生活家、涂鸦 App、tinytuya 脚本都会抢占。用 HA 时把手机 App 关掉，脚本用完断开 |
| 重新配网后 localKey 失效 | 每次配网 localKey 都会变，需要重新取一次并更新集成 |
| 设备类型列表里没有 Casdon GQ Pro | YAML 缩进错误 / 文件名不是 `.yaml` / 没放对目录；看 HA 日志里 `tuya_local` 的报错 |
| 开门报故障 | 你的映射把 DP13 的 256 当成故障了，改用本仓库的映射 |
| 卡片显示旧图/旧状态 | HA 对 `/local` 静态资源有 31 天缓存，换文件名或加 `?v=2` |

日志位置：**设置 → 系统 → 日志**，或 `docker logs homeassistant`。

---

## 七、贡献

欢迎补充，特别是：

- **模式枚举**（`docs/modes.md`）：把面板上每个模式点一遍，把对应的 `105` 数字记下来
- **故障位**：触发已知故障（拔水箱、超温等）记录 DP13 的数值
- **同族机型适配**：TD Pro 2/3、GR Pro 等，如果你的 DP 不同，欢迎提 PR 加新配置

贡献前请先读 [tuya-local 设备配置文档](https://github.com/make-all/tuya-local/blob/main/custom_components/tuya_local/devices/README.md)。

---

## 免责

- 本项目是社区配置，**不是官方支持**，按「现状」提供
- 远程控制家电存在风险（尤其是烤箱这类加热设备），请勿在无人看管时远程启动
- 修改配置前建议备份 `/config` 与 HA 快照

## 许可

MIT
