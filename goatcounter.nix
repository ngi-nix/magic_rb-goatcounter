{ lib
, fetchFromGitHub, buildGoModule
}:
with lib;
let
  pname = "goatcounter";
  version = "2.2.3";
in
buildGoModule {
  inherit pname version;

  vendorSha256 = "sha256-fzOLsnEEF6m2bf9E0V76wfokyiH3SfUxENbSRgTLhZM=";

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
    sha256 = "sha256-M/GMfc/3mhl5DpgDIi7AdOnWmm/1/HyYioqxYP0Yqnc=";
  };
}
