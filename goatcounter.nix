{ lib
, fetchFromGitHub, buildGoModule
}:
with lib;
let
  pname = "goatcounter";
  version = "2.0.4";
in
buildGoModule {
  inherit pname version;

  vendorSha256 = "sha256-z9SoAASihdTo2Q23hwo78SU76jVD4jvA0UVhredidOQ=";

  subPackages = [
    "cmd/goatcounter"
  ];

  # the tests are broken when building the 2.0.4 tag, but are fixed, by skipping them, on master,
  # when a new stable release is eventually release re-enable tests
  doCheck = true;

  src = fetchFromGitHub {
    owner = "zgoat";
    repo = pname;
    rev = "v" + version;
    sha256 = "sha256-Le0ZQ9iYrCEcYko1i6ETyi+SFOUMuWOoEJDd6nNxiuQ=";
  };
}
