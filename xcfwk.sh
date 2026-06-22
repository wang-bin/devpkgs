THIS_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})";pwd -P)"
cd $THIS_DIR
cd build
rm -rf *.xcframework

for m in curl openssl; do
  mkdir -p include/$m
  cp -af iOS/install/include/$m include/$m/
done

#strip iOS/install/lib/libcurl.a iOSSimulator/install/lib/libcurl.a
xcodebuild -create-xcframework -library iOS/install/lib/libcurl.a  -headers include/curl -library iOSSimulator/install/lib/libcurl.a -headers include/curl  -output curl.xcframework

for d in iOSSimulator; do
  for a in arm64 x86_64; do
    mkdir -p /tmp/$d/$a
    lipo $d/install/lib/libcrypto.a -thin $a -output /tmp/$d/$a/libcrypto.a
    lipo $d/install/lib/libssl.a -thin $a -output /tmp/$d/$a/libssl.a
    ../mergea.sh /tmp/$d/$a/libOpenSSL.a /tmp/$d/$a/lib{crypto,ssl}.a
    #strip /tmp/$d/$a/libOpenSSL.a
  done
  lipo /tmp/$d/{arm64,x86_64}/libOpenSSL.a -create -output $d/install/lib/libOpenSSL.a
done

../mergea.sh iOS/install/lib/libOpenSSL.a iOS/install/lib/lib{crypto,ssl}.a
#strip iOS/install/lib/libOpenSSL.a

xcodebuild -create-xcframework -library iOS/install/lib/libOpenSSL.a  -headers include/openssl -library iOSSimulator/install/lib/libOpenSSL.a -headers include/openssl  -output openssl.xcframework
