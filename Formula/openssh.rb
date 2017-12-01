class Openssh < Formula
  desc "OpenBSD freely-licensed SSH connectivity tools"
  homepage "https://www.openssh.com/"
  url "https://www.mirrorservice.org/pub/OpenBSD/OpenSSH/portable/openssh-7.5p1.tar.gz"
  mirror "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-7.5p1.tar.gz"
  version "7.5p1"
  sha256 "9846e3c5fab9f0547400b4d2c017992f914222b3fd1f8eee6c7dc6bc5e59f9f0"
  revision 1

  #bottle do
    #sha256 "a7998e2c51b48845f74bfc925cb00b54778a0ccaa9d02ae40dbc98e4ba1f7963" => :high_sierra
  #end

  option "with-gssapi-support", "Add GSSAPI key exchange support"
  depends_on "openssl"

  if build.with? "gssapi-support"
    patch do
      url "https://raw.githubusercontent.com/rdp/homebrew-openssh-gssapi/master/gssapi.patch" # "original" here: https://sources.debian.net/data/main/o/openssh/1:7.5p1-5/debian/patches/gssapi.patch but server slightly unstable :\
      sha256 'b7c0695cc5e45e14003e41a1b2a3cb92f70c574fe46d29a339e962335770da85'
    end
  end

  if build.with? "hpn"
    # Patch enabling High Performance SSH (hpn-ssh) helps large file transfer apparently...
    patch do
      url 'https://downloads.sourceforge.net/project/hpnssh/HPN-SSH%2014v13%207.5p1/openssh-7_5_P1-hpn-KitchenSink-14.13.diff'
      sha256 "c88b480a1110879d75cdfe06cc704086a8bf7ddf63bc66be6a899f9a9814e4f2"
    end 
  end

  # Both these patches are applied by Apple. (and probably others ~/.ssh/config enableKeyChain or what not?)
  patch do
    url "https://raw.githubusercontent.com/Homebrew/patches/1860b0a74/openssh/patch-sandbox-darwin.c-apple-sandbox-named-external.diff"
    sha256 "d886b98f99fd27e3157b02b5b57f3fb49f43fd33806195970d4567f12be66e71"
  end

  patch do
    url "https://raw.githubusercontent.com/Homebrew/patches/d8b2d8c2/openssh/patch-sshd.c-apple-sandbox-named-external.diff"
    sha256 "3505c58bf1e584c8af92d916fe5f3f1899a6b15cc64a00ddece1dc0874b2f78f"
  end

  resource "com.openssh.sshd.sb" do
    url "https://opensource.apple.com/source/OpenSSH/OpenSSH-209.50.1/com.openssh.sshd.sb"
    sha256 "a273f86360ea5da3910cfa4c118be931d10904267605cdd4b2055ced3a829774"
  end

  def install
    ENV.append "CPPFLAGS", "-D__APPLE_SANDBOX_NAMED_EXTERNAL__"

    # Ensure sandbox profile prefix is correct.
    # We introduce this issue with patching, it's not an upstream bug.
    inreplace "sandbox-darwin.c", "@PREFIX@/share/openssh", etc/"ssh"

    system "./configure", "--with-libedit",
                          "--with-kerberos5",
                          "--prefix=#{prefix}",
                          "--sysconfdir=#{etc}/ssh",
                          "--with-pam",
                          "--with-ssl-dir=#{Formula["openssl"].opt_prefix}"
    system "make"
    system "make", "install"

    # This was removed by upstream with very little announcement and has
    # potential to break scripts, so recreate it for now.
    # Debian have done the same thing.
    bin.install_symlink bin/"ssh" => "slogin"

    buildpath.install resource("com.openssh.sshd.sb")
    (etc/"ssh").install "com.openssh.sshd.sb" => "org.openssh.sshd.sb"
  end

  test do
    assert_match "OpenSSH_", shell_output("#{bin}/ssh -V 2>&1")

    begin
      pid = fork { exec sbin/"sshd", "-D", "-p", "8022" }
      sleep 2
      assert_match "sshd", shell_output("lsof -i :8022")
    ensure
      Process.kill(9, pid)
      Process.wait(pid)
    end
  end
end
