{
  lib,
  stdenv,
  src,
  version,
  revision ? "unknown",
  withGui ? false,
  autoconf,
  automake,
  bison,
  boost,
  cmake,
  curl,
  flex,
  gettext,
  gfortran,
  git,
  gnumake,
  jdk17_headless,
  libffi,
  libiconv,
  libtool,
  libuuid,
  makeWrapper,
  ninja,
  openblas,
  perl,
  pkg-config,
  python3,
}:

stdenv.mkDerivation {
  pname = "openmodelica";
  inherit src version;

  strictDeps = true;

  nativeBuildInputs = [
    autoconf
    automake
    bison
    cmake
    flex
    gfortran
    git
    jdk17_headless
    libtool
    makeWrapper
    ninja
    perl
    pkg-config
    python3
  ]
  ++ lib.optionals withGui [
    # Add GUI-specific build tools here when the Qt 6 clients are packaged.
  ];

  buildInputs = [
    boost
    curl
    gettext
    libffi
    libiconv
    libuuid
    openblas
  ]
  ++ lib.optionals withGui [
    # Add Qt 6, OpenSceneGraph, and the remaining GUI dependencies here.
  ];

  postPatch = ''
    # Nix sources do not contain .git. Give CMake a stable revision instead of
    # letting its Git probe return an empty value.
    echo "${revision}" > OMVERSION.txt
  '';

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeBool "OM_ENABLE_GUI_CLIENTS" withGui)
    (lib.cmakeBool "OM_USE_CCACHE" false)
    (lib.cmakeBool "OM_USE_SYSTEM_LIBFFI" true)
    (lib.cmakeFeature "BLA_VENDOR" "OpenBLAS")
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
  ];

  postFixup = ''
    wrapProgram "$out/bin/omc" \
      --prefix PATH : ${
        lib.makeBinPath [
          gnumake
          stdenv.cc
          gfortran
        ]
      } \
      --prefix LIBRARY_PATH : ${
        lib.makeLibraryPath [
          gfortran.cc.lib
          openblas
        ]
      }
  '';

  postInstall = ''
    install -Dm644 ${src}/OSMC-License.txt "$out/share/doc/openmodelica/OSMC-License.txt"
    install -Dm644 ${src}/OSMC-Runtime-License.txt "$out/share/doc/openmodelica/OSMC-Runtime-License.txt"
    install -Dm644 ${src}/OSMC-USAGE-MODE.txt "$out/share/doc/openmodelica/OSMC-USAGE-MODE.txt"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/omc" --version
    "$out/bin/omc" --help >/dev/null

    cp "$out/share/doc/omc/testmodels/HelloWorld.mo" .
    printf '%s\n' \
      'loadFile("HelloWorld.mo");' \
      'simulate(HelloWorld, stopTime=0.1);' \
      'getErrorString();' > smoke-test.mos
    "$out/bin/omc" smoke-test.mos
    test -x HelloWorld
    ./HelloWorld
    runHook postInstallCheck
  '';

  meta = {
    description = "Open-source Modelica-based modeling and simulation environment";
    homepage = "https://openmodelica.org/";
    # This distribution selects the AGPL mode declared in OSMC-USAGE-MODE.txt.
    license = lib.licenses.agpl3Only;
    mainProgram = "omc";
    platforms = lib.platforms.linux;
  };
}
