rm -rf dep
mkdir -p dep/include

mkdir -p dep/bin/windows/{x86,x64}/LTL
mkdir -p dep/bin/{WinRT,windows}/{arm64,x64,x86}
mkdir -p dep/lib/windows/{arm64,x64,x86}/{MD,MDd,MT}
mkdir -p dep/lib/windows/{arm64,x64,x86}/pkgconfig
mkdir -p dep/lib/WinRT/{arm64,x64,x86}

7z x -y devpkgs-windows-desktop-Release-vs2022.7z
cp -avf install/include/va dep/include/
cp -avf install/x64/include/{ass,dav1d,GLFW,mfx,vpl,*.h} dep/include
for A in arm64 x64 x86; do
    mv install/$A/bin/{libass,*dav1d,zlib}.dll dep/bin/windows/$A/
    mv install/$A/share/pkgconfig/zlib.pc dep/lib/windows/$A/pkgconfig            # TODO: edit zlib.pc
    mv install/$A/lib/{dav1d,glfw3,snappy,va*,zlib*}.lib dep/lib/windows/$A/MD/
    if [ -f install/$A/lib/vpl.lib ]; then
        mv install/$A/lib/{mfx,vpl}.lib dep/lib/windows/$A/MD/
        mv install/$A/lib/pkgconfig/{libmfx,vpl}.pc dep/lib/windows/$A/pkgconfig/     # TODO: edit libmfx.pc
    fi
done
rm -rf install

7z x -y devpkgs-windows-desktop-Debug-vs2022.7z
for A in arm64 x64 x86; do
    mv install/$A/lib/{glfw3,snappy}.lib dep/lib/windows/$A/MDd/
    [ -f install/$A/lib/vpld.lib ] && mv install/$A/lib/vpld.lib dep/lib/windows/$A/MDd/vpl.lib
done
rm -rf install

7z x -y devpkgs-windows-desktop-Release-vs2022-ltl.7z
for A in x64 x86; do
    mv install/$A/bin/{libass,*dav1d,zlib}.dll dep/bin/windows/$A/LTL
    mv install/$A/lib/{dav1d,glfw3,mfx,snappy,vpl,zlib*}.lib dep/lib/windows/$A/MT/
done
rm -rf install

7z x -y devpkgs-uwp-Release-vs2022.7z
for A in x64 arm64; do
    mv install/$A/bin/{libass,*dav1d,zlib}.dll dep/bin/WinRT/$A
    mv install/$A/lib/{dav1d,snappy,zlib*}.lib dep/lib/WinRT/$A
done
rm -rf install

mkdir -p dep/lib/Linux/{amd64,arm64,armhf}
7z x -y devpkgs-linux-MinSizeRel.7z
for A in amd64 arm64 armhf; do
    mv install/$A/lib/* dep/lib/Linux/$A/
done
find dep/lib/Linux -name libwolfssl.a -delete
rm -rf install

mkdir -p dep/lib/LinuxGnuStl/amd64
7z x -y devpkgs-linux-MinSizeRel-gnustl.7z
for A in amd64; do
    mv install/$A/lib/* dep/lib/LinuxGnuStl/$A/
done
rm -rf install


mkdir -p dep/lib/macOS
tar xvf devpkgs-macOS-MinSizeRel.tar.xz
mv install/lib/* dep/lib/macOS/
rm -rf install

7z a -ssc -m0=lzma2 -mx=9 -ms=on -mf=off dep.7z dep
