sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='.*'/hostname='IPQ6000'/g" package/base-files/files/bin/config_generate
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by Haiibo/g" package/lean/default-settings/files/zzz-default-settings

# ---------------------------------------------------------
# 2. 硬件底层优化 (NSS 内存预留, CPU 电压)
# ---------------------------------------------------------

# 调节 IPQ60XX 的 1.5GHz 频率电压 (从 0.9375V 提高到 0.95V)
# 注意：如果补丁文件路径或内容随内核版本变化，可能需要微调
if [ -f "target/linux/qualcommax/patches-6.12/0038-v6.16-arm64-dts-qcom-ipq6018-add-1.5GHz-CPU-Frequency.patch" ]; then
    sed -i 's/opp-microvolt = <937500>;/opp-microvolt = <950000>;/' target/linux/qualcommax/patches-6.12/0038-v6.16-arm64-dts-qcom-ipq6018-add-1.5GHz-CPU-Frequency.patch
fi

# NSS 驱动 q6_region 内存区域预留大小调整 (已注释，按需开启)
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x01000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x02000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x04000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x06000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi

# ---------------------------------------------------------
# 3. 移除要替换的包 (清理旧源)
# ---------------------------------------------------------

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

# 新增：清理可能冲突的 iStore/DDNSTO 旧目录
rm -rf package/luci-app-store
rm -rf package/luci-app-quickstart
rm -rf package/luci-app-ddnsto
rm -rf package/nas-packages-luci
rm -rf package/luci-app-tasks
rm -rf package/luci-app-netspeedtest
rm -rf package/netspeedtest

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
# 5. 下载第三方插件源码
# ---------------------------------------------------------

echo ">>> 开始下载自定义插件源码..."

# --- 原有插件 (Ariang, Go, FRP, Argon, Lucky, WechatPush 等) ---
git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
git_sparse_clone master https://github.com/laipeng668/packages lang/golang
mv -f package/golang feeds/packages/lang/golang
git_sparse_clone frp-binary https://github.com/laipeng668/packages net/frp
mv -f package/frp feeds/packages/net/frp
git_sparse_clone frp https://github.com/laipeng668/luci applications/luci-app-frpc applications/luci-app-frps
mv -f package/luci-app-frpc feeds/luci/applications/luci-app-frpc
mv -f package/luci-app-frps feeds/luci/applications/luci-app-frps

git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon feeds/luci/themes/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config feeds/luci/applications/luci-app-argon-config

# git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora feeds/luci/themes/luci-theme-aurora
# git clone --depth=1 https://github.com/eamonxg/luci-app-aurora-config feeds/luci/applications/luci-app-aurora-config

git clone --depth=1 https://github.com/gdy666/luci-app-lucky package/luci-app-lucky
git clone --depth=1 https://github.com/tty228/luci-app-wechatpush package/luci-app-wechatpush
git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter
git clone --depth=1 https://github.com/laipeng668/luci-app-gecoosac package/luci-app-gecoosac
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led

# --- 【新增】iStore 商店 & QuickStart ---
echo ">>> 下载 iStore 和 QuickStart..."
git clone --depth=1 https://github.com/linkease/nas-packages-luci.git package/nas-packages-luci
# 移动 store
mv -f package/nas-packages-luci/luci/luci-app-store package/luci-app-store
# 移动 quickstart (如果存在)
if [ -d "package/nas-packages-luci/luci/luci-app-quickstart" ]; then
    mv -f package/nas-packages-luci/luci/luci-app-quickstart package/luci-app-quickstart
    echo ">>> QuickStart 插件已提取"
else
    echo ">>> 未找到独立的 QuickStart 插件，它将作为 iStore 内的应用存在"
fi
# 清理临时目录
rm -rf package/nas-packages-luci

# --- 【新增】DDNSTO ---
echo ">>> 下载 DDNSTO..."
git clone --depth=1 https://github.com/kubeduck/luci-app-ddnsto.git package/luci-app-ddnsto

# --- 【新增】定时任务插件 (Tasks) ---
echo ">>> 下载定时任务插件 (luci-app-tasks)..."

# 使用 Hyy2001X 维护的版本，兼容性较好
git clone --depth=1 https://github.com/Hyy2001X/AutoBuild-Packages.git package/tmp-hyy
mv -f package/tmp-hyy/luci-app-tasks package/luci-app-tasks
rm -rf package/tmp-hyy

git clone --depth=1 https://github.com/sirpdboy/netspeedtest.git package/netspeedtest

# 如果仓库直接包含 luci-app-netspeedtest 目录
if [ -d "package/netspeedtest/luci-app-netspeedtest" ]; then
    mv -f package/netspeedtest/luci-app-netspeedtest package/luci-app-netspeedtest
    rm -rf package/netspeedtest
    echo ">>> sirpdboy netspeedtest 插件提取成功"
# 如果仓库本身就是插件目录 (有些仓库根目录即是插件)
elif [ -f "package/netspeedtest/Makefile" ] && grep -q "luci-app-netspeedtest" package/netspeedtest/Makefile; then
    mv -f package/netspeedtest package/luci-app-netspeedtest
    echo ">>> sirpdboy netspeedtest 插件重命名成功"
else
    # 备用处理：如果结构不同，直接保留原目录尝试编译，或报错提示
    echo ">>> 警告：请检查 package/netspeedtest 目录结构是否符合编译要求"
fi

# ---------------------------------------------------------
# 6. PassWall & OpenClash 核心替换
# ---------------------------------------------------------

echo ">>> 替换 PassWall 和 OpenClash 核心..."

# 移除 OpenWrt Feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}

# 下载新版 PassWall 包
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

# 移除过时 LuCI 并下载新版
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-openclash

git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall package/luci-app-passwall
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall2 package/luci-app-passwall2
git clone --depth=1 https://github.com/vernesong/OpenClash package/luci-app-openclash

# 清理 PassWall 的 chnlist 规则文件 (加速更新)
echo "baidu.com" > package/luci-app-passwall/luci-app-passwall/root/usr/share/passwall/rules/chnlist

# ---------------------------------------------------------
# 7. 更新 Feeds 并安装
# ---------------------------------------------------------

./scripts/feeds update -a
./scripts/feeds install -a

# ---------------------------------------------------------
# 8. 配置默认 Argon 主题颜色 (UCI Defaults)
# ---------------------------------------------------------

cat >> package/base-files/files/etc/uci-defaults/99-argon-config << 'EOF'
#!/bin/sh

# 设置 Argon 主题全局参数
uci set argon.@global[0].primary='#31A1A1'
uci set argon.@global[0].dark_primary='#31A1A1'
uci set argon.@global[0].transparency='0.3'
uci set argon.@global[0].transparency_dark='0.3'
uci set argon.@global[0].blur='10'
uci set argon.@global[0].blur_dark='10'

# 提交更改
uci commit argon

exit 0
EOF

chmod +x package/base-files/files/etc/uci-defaults/99-argon-config

echo ">>> Roc-script.sh 执行完毕！"
