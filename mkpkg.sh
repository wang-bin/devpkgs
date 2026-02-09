rm -rf dep dep-av
mkdir -p dep/include
mkdir -p dep-av/{vision,i,tv}OS dep-av/{android,linux,ohos}
# TODO: xcframework

#TODO: fribidi include, zlib for av
mkdir -p dep/bin/windows/{x86,x64}/LTL
mkdir -p dep/bin/{WinRT,windows}/{arm64,x64,x86}
mkdir -p dep/lib/windows/{arm64,x64,x86}/{MD,MDd,MT}
mkdir -p dep/lib/windows/{arm64,x64,x86}/pkgconfig
mkdir -p dep/lib/WinRT/{arm64,x64,x86}
sed_bak=
uname |grep -iq darwin && sed_bak=".bak"

7z x -y devpkgs-windows-desktop-Release-vs2026.7z
rsync -avm --include='*/' --include='**va**' --include='*lz4*' --include='**/z*' --include='**/mfx/**' --include='*mfx.*' --include='**/vpl/**' --include='*vpl.*' --include='*shaderc*' --include='**/shaderc/**' --include='*freetype*' --include='*fribidi*' --include='*harfbuzz*' --include='*ass.*' --include='**/ass/**' --include='**/freetype2/**' --include='**/fribidi/**' --include='**/harfbuzz/**' --exclude='*' install/* dep-av/windows
find dep-av/windows -name "*.pc" -exec sed -i $sed_bak '/-lm/d' {} \;   # harfbuzz.pc -lm
cp -avf install/include/va dep/include/
cp -avf install/x64/include/{ass,dav1d,GLFW,mfx,vpl,*.h} dep/include
for A in arm64 x64 x86; do
    mv install/$A/bin/{libass,*dav1d,z*}.dll dep/bin/windows/$A/
    mv install/$A/share/pkgconfig/zlib.pc dep/lib/windows/$A/pkgconfig            # TODO: edit zlib.pc
    cp install/$A/lib/zs.lib dep/lib/windows/$A/MD/libz.lib
    cp install/$A/lib/zs.lib dep-av/windows/$A/lib/zlib.lib
    cp -avf install/include/va dep-av/windows/$A/include
    cp -avf install/lib/pkgconfig/libva* dep-av/windows/$A/lib/pkgconfig
    mv install/$A/lib/{dav1d,glfw3,snappy,lz4,va*,z*}.lib dep/lib/windows/$A/MD/
    if [ -f install/$A/lib/vpl.lib ]; then
        mv install/$A/lib/{mfx,vpl}.lib dep/lib/windows/$A/MD/
        mv install/$A/lib/pkgconfig/{libmfx,vpl}.pc dep/lib/windows/$A/pkgconfig/     # TODO: edit libmfx.pc
    fi
done
rm -rf install

7z x -y devpkgs-windows-desktop-Debug-vs2026.7z
for A in arm64 x64 x86; do
    mv install/$A/lib/{glfw3,snappy,lz4}.lib dep/lib/windows/$A/MDd/
    [ -f install/$A/lib/vpld.lib ] && mv install/$A/lib/vpld.lib dep/lib/windows/$A/MDd/vpl.lib
done
rm -rf install

7z x -y devpkgs-windows-desktop-Release-vs2026-ltl.7z
rsync -avm --include='*/' --include='*lz4*' --include='**/z*' --include='**/mfx/**' --include='*mfx.*' --include='**/vpl/**' --include='*vpl.*' --include='*shaderc*' --include='**/shaderc/**' --include='*freetype*' --include='*fribidi*' --include='*harfbuzz*' --include='*ass.*' --include='**/ass/**' --include='**/freetype2/**' --include='**/fribidi/**' --include='**/harfbuzz/**' --exclude='*' install/* dep-av/windows-ltl
find dep-av/windows-ltl -name "*.pc" -exec sed -i $sed_bak '/-lm/d' {} \;   # harfbuzz.pc -lm
for A in x64 x86; do
    mv install/$A/bin/{libass,*dav1d,z*}.dll dep/bin/windows/$A/LTL
    cp install/$A/lib/zs.lib dep/lib/windows/$A/MT/libz.lib
    cp install/$A/lib/zs.lib dep-av/windows/$A/lib/zlib.lib
    mv install/$A/lib/{dav1d,glfw3,mfx,snappy,lz4,vpl,z*}.lib dep/lib/windows/$A/MT/
done
rm -rf install

7z x -y devpkgs-uwp-Release-vs2026.7z
rsync -avm --include='*/' --include='*lz4*' --include='**/z*' --include='*shaderc*' --include='**/shaderc/**' --include='*freetype*' --include='*fribidi*' --include='*harfbuzz*' --include='*ass.*' --include='**/ass/**' --include='**/freetype2/**' --include='**/fribidi/**' --include='**/harfbuzz/**' --exclude='*' install/* dep-av/uwp
find dep-av/uwp -name "*.pc" -exec sed -i $sed_bak '/-lm/d' {} \;   # harfbuzz.pc -lm
for A in x64 x86 arm64; do
    mv install/$A/bin/{libass,*dav1d,z*}.dll dep/bin/WinRT/$A
    cp install/$A/lib/zs.lib dep/lib/WinRT/$A/libz.lib
    cp install/$A/lib/zs.lib dep-av/WinRT/$A/lib/zlib.lib
    mv install/$A/lib/{dav1d,snappy,lz4,z*}.lib dep/lib/WinRT/$A
done
rm -rf install

mkdir -p dep/lib/Linux/{amd64,arm64,armhf}
7z x -y devpkgs-linux-MinSizeRel.7z
rsync -avm --include='*/' --include='*lz4*' --include='**/mfx/**' --include='*/libmfx.*' --include='**/vpl/**' --include='*/libvpl.*' --include='*/libcppcompat.a' --include='*shaderc*' --include='**/shaderc/**' --include='*wolfssl*' --include='**/wolfssl/**' --exclude='*' install/* dep-av/linux
for A in amd64 arm64 armhf; do
    mv install/$A/lib/* dep/lib/Linux/$A/
    rm dep/lib/Linux/$A/lib{harfbuzz,freetype}*
done
find dep/lib/Linux -name "*wolfssl*" -exec rm -rf {} \;
rm -rf install

mkdir -p dep/lib/LinuxGnuStl/amd64
7z x -y devpkgs-linux-MinSizeRel-gnustl.7z
for A in amd64; do
    mv install/$A/lib/* dep/lib/LinuxGnuStl/$A/
    rm dep/lib/LinuxGnuStl/$A/lib{harfbuzz,freetype}*
done
find dep/lib/LinuxGnuStl -name "*wolfssl*" -exec rm -rf {} \;
rm -rf install

mkdir -p dep/lib/android/{arm64-v8a,armeabi-v7a}
7z x -y devpkgs-android-MinSizeRel.7z
rsync -avm --include='*/' --include='*lz4*' --include='*shaderc*' --include='**/shaderc/**' --include='*wolfssl*' --include='**/wolfssl/**' --exclude='*' install/* dep-av/android
rsync -avm --include='*/' --include='*freetype*' --include='*fribidi*' --include='*harfbuzz*' --include='*ass.*' --include='**/ass/**' --include='**/freetype2/**' --include='**/fribidi/**' --include='**/harfbuzz/**' --exclude='*' install/* dep-av/android
for A in arm64-v8a armeabi-v7a; do
    mv install/$A/lib/*.so dep/lib/android/$A/
    cp -avf install/$A/lib/liblz4.a dep/lib/android/$A/
done
find dep/lib/android -name "*wolfssl*" -exec rm -rf {} \;
rm -rf install

mkdir -p dep/lib/ohos/arm64-v8a
7z x -y devpkgs-ohos-MinSizeRel.7z
rsync -avm --include='*/' --include='*lz4*' --include='*shaderc*' --include='**/shaderc/**' --include='*wolfssl*' --include='**/wolfssl/**' --exclude='*' install/* dep-av/ohos
rsync -avm --include='*/' --include='*freetype*' --include='*fribidi*' --include='*harfbuzz*' --include='*ass.*' --include='**/ass/**' --include='**/freetype2/**' --include='**/fribidi/**' --include='**/harfbuzz/**' --exclude='*' install/* dep-av/ohos
for A in arm64-v8a; do
    mv install/$A/lib/*.so dep/lib/ohos/$A/
    cp -avf install/$A/lib/liblz4.a dep/lib/ohos/$A/
done
find dep/lib/ohos -name "*wolfssl*" -exec rm -rf {} \;
rm -rf install

mkdir -p dep/lib/macOS
tar xvf devpkgs-macOS-MinSizeRel.tar.xz
rsync -avm --include='*/' --include='*lz4*' --include='*shaderc*' --include='**/shaderc/**' --include='*freetype*' --include='*fribidi*' --include='*harfbuzz*' --include='*ass.*' --include='**/ass/**' --include='**/freetype2/**' --include='**/fribidi/**' --include='**/harfbuzz/**' --exclude='*' install/* dep-av/macOS
mv dep-av/macOS/arm64/include dep-av/macOS/
mv dep-av/macOS/arm64/lib/pkgconfig dep-av/macOS/lib
rm -rf dep-av/macOS/{arm,x86_}64
mv install/lib/*.dylib dep/lib/macOS/
mv install/lib/{libglfw,libsnappy,liblz4}* dep/lib/macOS/
rm -rf install

mkdir -p dep/lib/iOS
tar xvf devpkgs-iOS-MinSizeRel.tar.xz
rsync -avm --include='*/' --include='*lz4*' --include='*wolfssl*' --include='**/wolfssl/**' --exclude='*' install/arm64/* dep-av/iOS
rsync -avm --include='*/' --include='*freetype*' --include='*fribidi*' --include='*harfbuzz*' --include='*ass.*' --include='**/ass/**' --include='**/freetype2/**' --include='**/fribidi/**' --include='**/harfbuzz/**' --exclude='*' install/arm64/* dep-av/iOS
mv install/arm64/lib/*.framework dep/lib/iOS/
cp install/arm64/lib/liblz4.a dep/lib/iOS/
rm -rf install

mkdir -p dep/lib/tvOS
tar xvf devpkgs-tvOS-MinSizeRel.tar.xz
rsync -avm --include='*/' --include='*lz4*' --include='*wolfssl*' --include='**/wolfssl/**' --exclude='*' install/arm64/* dep-av/tvOS
rsync -avm --include='*/' --include='*freetype*' --include='*fribidi*' --include='*harfbuzz*' --include='*ass.*' --include='**/ass/**' --include='**/freetype2/**' --include='**/fribidi/**' --include='**/harfbuzz/**' --exclude='*' install/arm64/* dep-av/tvOS
mv install/arm64/lib/*.framework dep/lib/tvOS/
cp install/arm64/lib/liblz4.a dep/lib/tvOS/
rm -rf install

mkdir -p dep/lib/visionOS
tar xvf devpkgs-visionOS-MinSizeRel.tar.xz
rsync -avm --include='*/' --include='*lz4*' --include='*wolfssl*' --include='**/wolfssl/**' --exclude='*' install/arm64/* dep-av/visionOS
rsync -avm --include='*/' --include='*freetype*' --include='*fribidi*' --include='*harfbuzz*' --include='*ass.*' --include='**/ass/**' --include='**/freetype2/**' --include='**/fribidi/**' --include='**/harfbuzz/**' --exclude='*' install/arm64/* dep-av/visionOS
mv install/arm64/lib/*.framework dep/lib/visionOS/
cp install/arm64/lib/liblz4.a dep/lib/visionOS/
rm -rf install

find dep-av -name share -type d -exec rm -rf {} \;

find dep-av -name "*.pc" -exec sed -i $sed_bak 's,^prefix=.*,prefix=\${pcfiledir}\/..\/..\/,' {} \;

if [ -d /opt/homebrew/include/shaderc ]; then
    cp -avfL /opt/homebrew/include/shaderc dep/include/
fi

7z a -ssc -m0=lzma2 -mx=9 -ms=on -mf=off dep.7z dep
7z a -ssc -m0=lzma2 -mx=9 -ms=on -mf=off dep-av.7z dep-av
