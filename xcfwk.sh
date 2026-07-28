THIS_DIR="$(cd "$(dirname ${BASH_SOURCE[0]})";pwd -P)"
cd $THIS_DIR
cd build
rm -rf *.xcframework

for m in curl openssl ngtcp2; do
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

    # merge libngtcp2.a libngtcp2_crypto_boringssl.a into libNGTCP2.a, lipo thin first
    lipo $d/install/lib/libngtcp2.a -thin $a -output /tmp/$d/$a/libngtcp2.a
    lipo $d/install/lib/libngtcp2_crypto_boringssl.a -thin $a -output /tmp/$d/$a/libngtcp2_crypto_boringssl.a
    ../mergea.sh /tmp/$d/$a/libngtcp2bssl.a /tmp/$d/$a/libngtcp2{,_crypto_boringssl}.a
  done
  lipo /tmp/$d/{arm64,x86_64}/libOpenSSL.a -create -output $d/install/lib/libOpenSSL.a
  lipo /tmp/$d/{arm64,x86_64}/libngtcp2bssl.a -create -output $d/install/lib/libngtcp2bssl.a
done

../mergea.sh iOS/install/lib/libOpenSSL.a iOS/install/lib/lib{crypto,ssl}.a
../mergea.sh iOS/install/lib/libngtcp2bssl.a iOS/install/lib/lib{ngtcp2,ngtcp2_crypto_boringssl}.a
#strip iOS/install/lib/libOpenSSL.a

xcodebuild -create-xcframework -library iOS/install/lib/libOpenSSL.a  -headers include/openssl -library iOSSimulator/install/lib/libOpenSSL.a -headers include/openssl  -output openssl.xcframework
xcodebuild -create-xcframework -library iOS/install/lib/libngtcp2bssl.a  -headers include/ngtcp2 -library iOSSimulator/install/lib/libngtcp2bssl.a -headers include/ngtcp2 -output ngtcp2.xcframework
