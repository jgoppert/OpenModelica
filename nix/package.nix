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
  openblasCompat,
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
    openblasCompat
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
      --unset NIX_CFLAGS_COMPILE \
      --unset NIX_LDFLAGS \
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
          openblasCompat
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

    cat > LinearSystemSmoke.mo <<'EOF'
    model LinearSystemSmoke
      Real a;
      Real b;
      Real c;
      Real d;
    equation
      time*a + sin(time)*b + (1 + time)*c + cos(sin(time))*d = time^2 + time + 1;
      cosh(time)*a + exp(time)*b + tanh(1 + time)*c + cos(7*time + 5)*d = (time + 5)^2 + time + 1;
      exp(time)*a + (1 + time)*(time - 1)*b + sinh(1 + time)*c + cos(time + 3)*d = (time + 8)^2 + time + 1;
      cos(time)*a + sin(time)^2*b + (1 + time)^2*c + cos(10*time)^3*d = time^5 + time + 1;
    end LinearSystemSmoke;
    EOF
    printf '%s\n' \
      'loadFile("LinearSystemSmoke.mo");' \
      'simulate(LinearSystemSmoke, stopTime=0.1, numberOfIntervals=10, outputFormat="csv");' \
      'getErrorString();' > linear-system-smoke.mos
    "$out/bin/omc" linear-system-smoke.mos
    test -s LinearSystemSmoke_res.csv
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
