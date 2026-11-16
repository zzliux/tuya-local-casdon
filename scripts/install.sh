#!/usr/bin/env sh
# 把配置包安装到 Home Assistant 的配置目录。
#
# 用法：
#   ./scripts/install.sh /path/to/ha/config
#   HA_CONFIG=/path/to/ha/config ./scripts/install.sh
#
# 典型路径：
#   HAOS / Supervised : /usr/share/hassio/homeassistant  或  /config
#   Docker            : 挂载到容器的目录，比如 /opt/ha/config
#   Core（venv）       : ~/.homeassistant

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HA_CONFIG=${1:-${HA_CONFIG:-}}

if [ -z "$HA_CONFIG" ]; then
  echo "用法: $0 <HA 配置目录>" >&2
  echo "  或者设置环境变量 HA_CONFIG" >&2
  exit 1
fi

DEVICES_DIR="$HA_CONFIG/custom_components/tuya_local/devices"

if [ ! -d "$DEVICES_DIR" ]; then
  echo "错误: 找不到 $DEVICES_DIR" >&2
  echo "请先在 HA 里安装 Tuya Local（设置 → Marketplace → 搜索 Tuya Local）。" >&2
  exit 1
fi

echo "==> 安装设备配置"
cp "$ROOT/devices/casdon_gq_pro.yaml" "$DEVICES_DIR/casdon_gq_pro.yaml"
echo "    $DEVICES_DIR/casdon_gq_pro.yaml"

echo "==> 安装模板实体"
cp "$ROOT/templates/gq_pro_templates.yaml" "$HA_CONFIG/gq_pro_templates.yaml"
echo "    $HA_CONFIG/gq_pro_templates.yaml"

if grep -qE '^template:' "$HA_CONFIG/configuration.yaml" 2>/dev/null; then
  echo
  echo "注意: configuration.yaml 里已经有 template: 键。"
  echo "      请手动把 gq_pro_templates.yaml 的内容合并进现有 template 列表，"
  echo "      不要重复添加 template: 键。"
else
  echo
  echo "==> 在 configuration.yaml 里引入模板"
  printf '\n# 凯度 GQ Pro 模板实体\ntemplate: !include gq_pro_templates.yaml\n' >> "$HA_CONFIG/configuration.yaml"
  echo "    已追加 template: !include gq_pro_templates.yaml"
fi

cat <<'TIP'

完成。接下来：

  1. 重启 Home Assistant（新增 template: 顶层键需要重启一次）
  2. 设置 → 设备与服务 → 添加集成 → Tuya Local
  3. 设备类型选择 "Casdon GQ Pro (oven)"
  4. 检查模板实体引用的实体 ID 是否匹配（见 README「模板实体」一节）

详细步骤见 README.md
TIP
