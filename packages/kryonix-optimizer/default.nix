{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

python3Packages.buildPythonApplication rec {
  pname = "kryonix-optimizer";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  nativeBuildInputs = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    psutil
    httpx
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
    pytest-asyncio
  ];

  pythonImportsCheck = [ "kryonix_optimizer" ];

  meta = with lib; {
    description = "Kryonix RAM Optimizer AI Daemon";
    homepage = "https://github.com/kryonix/kryonix";
    license = licenses.mit;
    maintainers = [ maintainers.rocha ];
    mainProgram = "kryonix-optimizer";
  };
}
