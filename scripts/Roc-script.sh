#!/bin/bash

set -e # 遇到错误立即停止，防止错误累积

# ---------------------------------------------------------
# 1. 基础信息修改 (IP, 主机名, 版本, 时间)
# ---------------------------------------------------------
echo ">>> 修改基础系统信息..."
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='.*'/hostname='IPQ6000'/g' package/base-files/files/bin/config_generate
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm
uci set ttyd.@ttyd[0].command='/bin/login -f root'
uci set ttyd.@ttyd[0].interface='0.0.0.0'

date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by Haiibo/g" package/lean/default-settings/files/zzz-default-settings

# ---------------------------------------------------------
# 2. 硬件底层优化 (NSS 内存预留, CPU 电压)
# ---------------------------------------------------------
echo ">>> 应用 IPQ60xx 硬件优化..."
if [ -f "target/linux/qualcommax/patches-6.12/0038-v6.16-arm64-dts-qcom-ipq6018-add-1.5GHz-CPU-Frequency.patch" ]; then
    sed -i 's/opp-microvolt = <937500>;/opp-microvolt = <950000>;/' target/linux/qualcommax/patches-6.12/0038-v6.16-arm64-dts-qcom-ipq6018-add-1.5GHz-CPU-Frequency.patch
    echo ">>> CPU 电压调整完成 (0.9375V -> 0.95V)"
else
    echo ">>> 未找到 CPU 频率补丁文件，跳过电压调整。"
fi

# ---------------------------------------------------------
# 3. 移除要替换的包 (彻底清理旧源)
# ---------------------------------------------------------
echo ">>> 清理旧插件目录..."
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-wechatpush
rm -rf feeds/luci/applications/luci-app-appfilter
rm -rf feeds/luci/applications/luci-app-frpc
rm -rf feeds/luci/applications/luci-app-frps
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/packages/net/open-app-filter
rm -rf feeds/packages/net/ariang
rm -rf feeds/packages/net/frp
rm -rf feeds/packages/lang/golang

# 【重要】清理所有可能冲突的自定义插件目录
rm -rf package/luci-app-store
rm -rf package/luci-app-quickstart
rm -rf package/quickstart
rm -rf package/homebox
rm -rf package/ookla-speedtest
rm -rf package/wrtbwmon
rm -rf package/luci-app-ddnsto
rm -rf package/nas-packages
rm -rf package/nas-packages-luci
rm -rf package/luci-app-tasks
rm -rf package/luci-app-netspeedtest
rm -rf package/netspeedtest
rm -rf package/tmp-hyy
rm -rf package/tmp-sirp-pkg
rm -rf package/luci-app-lucky
rm -rf package/OpenAppFilter
rm -rf package/luci-app-gecoosac
rm -rf package/luci-app-athena-led
rm -rf package/passwall-packages
rm -rf package/luci-app-passwall
rm -rf package/luci-app-passwall2
rm -rf package/luci-app-openclash

# ---------------------------------------------------------
# 4. Git 稀疏克隆函数定义
# ---------------------------------------------------------
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# ---------------------------------------------------------
# 5. 下载第三方插件源码 (含依赖修复)
# ---------------------------------------------------------
echo ">>> 开始下载自定义插件源码及依赖..."

# --- A. 基础依赖库 (Ariang, Go, FRP) ---
git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
git_sparse_clone master https://github.com/laipeng668/packages lang/golang
mv -f package/golang feeds/packages/lang/golang
git_sparse_clone frp-binary https://github.com/laipeng668/packages net/frp
mv -f package/frp feeds/packages/net/frp
git_sparse_clone frp https://github.com/laipeng668/luci applications/luci-app-frpc applications/luci-app-frps
mv -f package/luci-app-frpc feeds/luci/applications/luci-app-frpc
mv -f package/luci-app-frps feeds/luci/applications/luci-app-frps

# --- B. 主题与基础应用 ---
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon feeds/luci/themes/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config feeds/luci/applications/luci-app-argon-config

git clone --depth=1 https://github.com/gdy666/luci-app-lucky package/luci-app-lucky
git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter
git clone --depth=1 https://github.com/laipeng668/luci-app-gecoosac package/luci-app-gecoosac
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led 2>/dev/null || true

# --- C. 【核心修复】Linkease (iStore & QuickStart) ---
echo ">>> 正在处理 Linkease (iStore/QuickStart) 依赖..."
rm -rf package/nas-packages package/nas-packages-luci

git clone --depth=1 https://github.com/linkease/nas-packages.git package/nas-packages
git clone --depth=1 https://github.com/linkease/nas-packages-luci.git package/nas-packages-luci

# 1. 移动二进制包 (quickstart, homebox)
if [ -d "package/nas-packages/network/quickstart" ]; then
    mv -f package/nas-packages/network/quickstart package/quickstart
    echo "✅ quickstart (binary) 已提取"
else
    echo "⚠️ 警告：未找到 quickstart 二进制包"
fi

if [ -d "package/nas-packages/utils/homebox" ]; then
    mv -f package/nas-packages/utils/homebox package/homebox
    echo "✅ homebox (binary) 已提取"
fi

# 2. 移动界面包 (luci-app-store, luci-app-quickstart)
if [ -f "package/nas-packages-luci/luci/luci-app-store/Makefile" ]; then
    mv -f package/nas-packages-luci/luci/luci-app-store package/luci-app-store
    echo "✅ luci-app-store 已提取"
else
    echo "❌ 错误：luci-app-store 的 Makefile 不存在！检查目录结构。"
    ls -R package/nas-packages-luci
    exit 1
fi

if [ -d "package/nas-packages-luci/luci/luci-app-quickstart" ]; then
    mv -f package/nas-packages-luci/luci/luci-app-quickstart package/luci-app-quickstart
    echo "✅ luci-app-quickstart 已提取"
fi

# 清理临时大仓库
rm -rf package/nas-packages
rm -rf package/nas-packages-luci

# --- D. 其他关键依赖 (Wrtbwmon, Ookla) ---
echo ">>> 下载其他关键依赖..."

# 1. Wrtbwmon (WechatPush 依赖)
git clone --depth=1 https://github.com/brv2001/wrtbwmon.git package/wrtbwmon
echo "✅ wrtbwmon 已下载"

# 2. Ookla-Speedtest (NetSpeedTest 依赖)
git clone --depth=1 https://github.com/sirpdboy/sirpdboy-package.git package/tmp-sirp-pkg
if [ -d "package/tmp-sirp-pkg/ookla-speedtest" ]; then
    mv -f package/tmp-sirp-pkg/ookla-speedtest package/ookla-speedtest
    echo "✅ ookla-speedtest 已下载"
else
    echo "⚠️ 警告：未找到 ookla-speedtest，NetSpeedTest 可能仅能使用 LibreSpeed 引擎"
fi
rm -rf package/tmp-sirp-pkg

# --- E. 下载主插件 (此时依赖已就绪) ---
echo ">>> 下载主插件..."

# 1. WechatPush
git clone --depth=1 https://github.com/tty228/luci-app-wechatpush package/luci-app-wechatpush

# 2. DDNSTO
git clone --depth=1 https://github.com/kubeduck/luci-app-ddnsto.git package/luci-app-ddnsto

# 3. 定时任务 (Tasks)
git clone --depth=1 https://github.com/Hyy2001X/AutoBuild-Packages.git package/tmp-hyy
if [ -d "package/tmp-hyy/luci-app-tasks" ]; then
    mv -f package/tmp-hyy/luci-app-tasks package/luci-app-tasks
    echo "✅ luci-app-tasks 已提取"
fi
rm -rf package/tmp-hyy

# 4. NetSpeedTest (Sirpdboy)
git clone --depth=1 https://github.com/sirpdboy/luci-app-netspeedtest.git package/tmp-netspeed
if [ -d "package/tmp-netspeed/luci-app-netspeedtest" ]; then
    mv -f package/tmp-netspeed/luci-app-netspeedtest package/luci-app-netspeedtest
    echo "✅ luci-app-netspeedtest 已提取"
elif [ -f "package/tmp-netspeed/Makefile" ]; then
    mv -f package/tmp-netspeed package/luci-app-netspeedtest
    echo "✅ luci-app-netspeedtest (根目录) 已重命名"
else
    echo "⚠️ 警告：netspeedtest 结构异常"
fi
rm -rf package/tmp-netspeed

# ---------------------------------------------------------
# 6. PassWall & OpenClash 核心替换
# ---------------------------------------------------------
echo ">>> 替换 PassWall 和 OpenClash 核心..."

rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}

git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-openclash

git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall package/luci-app-passwall
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall2 package/luci-app-passwall2
git clone --depth=1 https://github.com/vernesong/OpenClash package/luci-app-openclash

echo "baidu.com" > package/luci-app-passwall/luci-app-passwall/root/usr/share/passwall/rules/chnlist

# ---------------------------------------------------------
# 7. 更新 Feeds 并安装
# ---------------------------------------------------------
echo ">>> 更新 Feeds 索引..."
./scripts/feeds update -a
./scripts/feeds install -a

# ---------------------------------------------------------
# 8. 配置默认 Argon 主题颜色
# ---------------------------------------------------------
cat >> package/base-files/files/etc/uci-defaults/99-argon-config << 'EOF'
#!/bin/sh
uci set argon.@global[0].primary='#31A1A1'
uci set argon.@global[0].dark_primary='#31A1A1'
uci set argon.@global[0].transparency='0.3'
uci set argon.@global[0].transparency_dark='0.3'
uci set argon.@global[0].blur='10'
uci set argon.@global[0].blur_dark='10'
uci commit argon
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-argon-config

echo ">>> ✅ Roc-script.sh 执行完毕！所有依赖已补全。"
echo ">>> ⚠️ 请确保在 General.sh 中启用了 CONFIG_PACKAGE_luci-app-store=y 和 CONFIG_PACKAGE_quickstart=y"
