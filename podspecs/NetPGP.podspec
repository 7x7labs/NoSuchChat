Pod::Spec.new do |s|
  s.dependency 'OpenSSL'

  s.name = 'NetPGP'
  s.version = '20101107'
  s.summary = 'NetPGP implementation of OpenPGP.'
  s.authors = 'Nominet UK (www.nic.uk)'
  s.homepage = 'http://www.netpgp.com'
  s.license	= 'Two-clause BSD'
  s.source = { http: 'http://www.netpgp.com/src/netpgp.tar.gz'}
  s.platform = :ios

  s.requires_arc = false
  s.preserve_paths = ['include', 'src']
  s.public_header_files = 'include/netpgp.h'
  s.source_files = ['src/lib/*.{h,c}', 'src/libmj/*.{h,c}']

  s.pre_install do |pod, target_definition|
    config = <<-CONFIG_H
#define HAVE_BZLIB_H 1
#define HAVE_COMMONCRYPTO_COMMONDIGEST_H 1
#define HAVE_DLFCN_H 1
#define HAVE_ERRNO_H 1
#define HAVE_FCNTL_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_LIMITS_H 1
#define HAVE_LONG_LONG_INT 1
#define HAVE_MEMORY_H 1
#define HAVE_OPENSSL_AES_H 1
#define HAVE_OPENSSL_BN_H 1
#define HAVE_OPENSSL_CAMELLIA_H 1
#define HAVE_OPENSSL_CAST_H 1
#define HAVE_OPENSSL_DES_H 1
#define HAVE_OPENSSL_DSA_H 1
#define HAVE_OPENSSL_ERR_H 1
#define HAVE_OPENSSL_IDEA_H 1
#define HAVE_OPENSSL_MD5_H 1
#define HAVE_OPENSSL_RAND_H 1
#define HAVE_OPENSSL_RSA_H 1
#define HAVE_OPENSSL_SHA_H 1
#define HAVE_SHA256_CTX 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_CDEFS_H 1
#define HAVE_SYS_FILE_H 1
#define HAVE_SYS_MMAN_H 1
#define HAVE_SYS_PARAM_H 1
#define HAVE_SYS_RESOURCE_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_UIO_H 1
#define HAVE_UNISTD_H 1
#define HAVE_ZLIB_H 1
#define PACKAGE "netpgp"
#define PACKAGE_BUGREPORT "Alistair Crooks <agc@netbsd.org> c0596823"
#define PACKAGE_NAME "netpgp"
#define PACKAGE_STRING "netpgp 20101107"
#define PACKAGE_TARNAME "netpgp"
#define PACKAGE_VERSION "20101107"
#define STDC_HEADERS 1
#define VERSION "20101107"
CONFIG_H

    File.open("#{pod.root}/src/lib/config.h", 'w') do |file|
      file.puts config
    end
  end
end
